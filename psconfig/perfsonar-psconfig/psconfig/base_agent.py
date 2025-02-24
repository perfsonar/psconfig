'''
Abstract class for building agent that downloads JSON config, applies a transform and
then does something with it
'''

import os
import socket
from urllib.parse import urlsplit
from .utilities.iso8601 import duration_to_seconds
from ipaddress import ip_address, IPv6Address, IPv4Address, IPv6Network
from .requesting_agent_connect import RequestingAgentConnect
from .archive_connect import ArchiveConnect
from .transform_connect import TransformConnect
from .client.psconfig.api_connect import ApiConnect
from .client.psconfig.config import Config
from .client.psconfig.api_filters import ApiFilters
from .client.psconfig.base_node import BaseNode
from .remote import Remote
from .utilities.cache_handler import CacheHandler
from .utilities.host import Host
from .utilities.dns import reverse_dns, resolve_address
import glob
import re
import logging
from jsonschema import validate as jsonvalidate, ValidationError

class BaseAgent(object):

    def _agent_name(self):
        '''override this'''
        #return ###### remove this return
        raise Exception('''override this''')

    def _config_client(self):
        '''override this'''
        #return ###### remove this return
        raise Exception('''override this''')

    def _init(self, agent_conf):
        return
    
    def _run_start(self, agent_conf):
        return
    
    def _run_handle_psconfig(self, agent_conf, remote):
        raise Exception('''override this''')
    
    def _run_end(self, agent_conf):
        return
    
    def __init__(self, **kwargs):
        self.config_file = kwargs.get('config_file', None)
        self.include_directory = kwargs.get('include_directory', None)
        self.archive_directory = kwargs.get('archive_directory', None)
        self.transform_directory = kwargs.get('transform_directory', None)
        self.requesting_agent_file = kwargs.get('requesting_agent_file', None)
        self.pscheduler_url = kwargs.get('pscheduler_url', None)
        self.check_interval_seconds = kwargs.get('check_interval_seconds', 3600)
        self.check_config_interval_seconds = kwargs.get('check_config_interval_seconds', 60)
        self.default_archives = kwargs.get('default_archives', [])
        self.cache_expires_seconds = kwargs.get('cache_expires_seconds', 86400)
        self.template_cache = kwargs.get('template_cache', None)
        self.default_transforms = kwargs.get('default_transforms', [])
        self.requesting_agent_addresses = kwargs.get('requesting_agent_addresses', None)
        self.debug = kwargs.get('debug', False)
        self.error = ''
        self.logger = logging.getLogger(__name__)

    def init(self, config_file):
        
        #set the config file
        self.config_file = config_file

        #set some defaults
        CONFIG_DIR = os.path.dirname(config_file)
        DEFAULT_ARCHIVES_DIR = CONFIG_DIR + '/archives.d'
        DEFAULT_INCLUDE_DIR = CONFIG_DIR + '/' + str.lower(self._agent_name()) + '.d' 
        DEFAULT_TRANSFORM_DIR = CONFIG_DIR + '/transforms.d'
        DEFAULT_RA_FILE = CONFIG_DIR + '/requesting-agent.json'

        ##
        #Load configuration file
        agent_conf = None
        try:
            agent_conf = self._load_config(config_file)
        except Exception as e:
            self.error = e
            return

        ##
        # init local logging context
        log_ctx = { "agent_conf_file" : config_file }

        ##
        # Grab properties and set defaults
        if agent_conf.include_directory(): 
            self.include_directory = agent_conf.include_directory() 
        else:
            self.logger.debug(self.logf.format("No include directory specified. Defaulting to {}".format(DEFAULT_INCLUDE_DIR), log_ctx))
            self.include_directory = DEFAULT_INCLUDE_DIR
        if agent_conf.archive_directory(): 
            self.archive_directory = agent_conf.archive_directory()
        else:
            self.logger.debug(self.logf.format("No archives directory specified. Defaulting to {}".format(DEFAULT_ARCHIVES_DIR), log_ctx))
            self.archive_directory = DEFAULT_ARCHIVES_DIR
        if agent_conf.transform_directory():
            self.transform_directory = agent_conf.transform_directory() 
        else:
            self.logger.debug(self.logf.format("No transform directory specified. Defaulting to {}".format(DEFAULT_TRANSFORM_DIR), log_ctx))
            self.transform_directory = DEFAULT_TRANSFORM_DIR
        if agent_conf.requesting_agent_file(): 
            self.requesting_agent_file = agent_conf.requesting_agent_file() 
        else:
            self.requesting_agent_file = DEFAULT_RA_FILE
        
        ##
        # Call agent implementation specific initialization
        self._init(agent_conf)

        return True

    def run(self):
        ##
        # Load configuration
        self.logf.global_context = {'agent_conf_file' : self.config_file}
        agent_conf = None
        try:
            agent_conf = self._load_config(self.config_file)
        except Exception as e:
            self.logger.error(self.logf.format("Error reading " + str(self.config_file) + ", not going to run any updates. Caused by: {}".format(e)))
            return

        ##
        # Set assist server - Host/Post to URL
        if not agent_conf.pscheduler_assist_server(): 
            default = 'localhost'
            self.logger.debug(self.logf.format( "No pscheduler-assist-server specified. Defaulting to {}".format(default) ))
            agent_conf.pscheduler_assist_server(default)

        self.pscheduler_url = self._build_pscheduler_url(agent_conf.pscheduler_assist_server()) 
        self.logger.debug(self.logf.format("pscheduler_url is " + str(self.pscheduler_url)))

        ##
        # Set intervals which have instance values used by daemon
        if agent_conf.check_interval():
            check_interval = None

            try:
                check_interval = int(duration_to_seconds(agent_conf.check_interval()))
            except Exception as e:
                self.logger.error(self.logf.format("Error parsing check-interval. Defaulting to " + str(self.check_interval_seconds) + " seconds: {}".format(e)))
                pass
            if not check_interval:
                self.logger.error(self.logf.format("check_interval has no value, sticking with default " + str(self.check_interval_seconds) + " seconds"))
            else:
                self.check_interval_seconds = check_interval
            
            self.logger.debug(self.logf.format("check_interval is " + str(self.check_interval_seconds) + " seconds"))
        
        if agent_conf.check_config_interval(): 
            check_config_interval = None

            try:
                check_config_interval = duration_to_seconds(agent_conf.check_config_interval()) 
            except Exception as e:
                self.logger.error(self.logf.format("Error parsing check-config-interval. Defaulting to " + str(self.check_config_interval_seconds) + " seconds: {}".format(e)))
                pass
            if not check_config_interval:
                self.logger.error(self.logf.format("check-config-interval has no value, sticking with default " + str(self.check_config_interval_seconds) + " seconds"))
            else:
                self.check_config_interval_seconds = check_config_interval

            self.logger.debug(self.logf.format("check_config_interval is " + str(self.check_config_interval_seconds) + " seconds"))

        ##
        # Build requesting_address which is used in address classes
        self.requesting_agent_addresses = self._requesting_agent_from_file(self.requesting_agent_file)
        if not self.requesting_agent_addresses:
            ##
            # Build requesting agent from all addresses on local machine
            auto_detected_addresses = self._get_addresses()
            requesting_agent = {}
            for address in auto_detected_addresses:
                requesting_agent[address] = {'address': address}
            self.requesting_agent_addresses = requesting_agent
            self.logger.debug(self.logf.format("Auto-detected requesting agent", {"requesting_agent" : requesting_agent}))
        
        ##
        # Reset logging context, done with config file
        self.logf.global_context = {'pscheduler_assist_url' : self.pscheduler_url}
        
        ##
        # Init the run. If returns false, exit
        if not self._run_start(agent_conf):
            return
        
        ##
        # Handle cache settings
        self.logger.debug(self.logf.format("disable-cache is " + str(agent_conf.disable_cache())))
        if agent_conf.cache_expires(): 
            cache_expires_seconds = None
            try:
                cache_expires_seconds = duration_to_seconds(agent_conf.cache_expires())
            except Exception as e:
                self.logger.error(self.logf.format("Error parsing cache-expires. Defaulting to " + str(self.cache_expires_seconds) + " seconds: {}".format(e)))
            if not cache_expires_seconds:
                self.logger.error(self.logf.format("cache-expires has no value, sticking with default " + str(self.cache_expires_seconds) + " seconds"))
            else:
                self.cache_expires_seconds = cache_expires_seconds 
        self.logger.debug(self.logf.format("cache-expires is " + str(self.cache_expires_seconds) + " seconds"))
        
        # Build cache client
        if (agent_conf.disable_cache()) or (agent_conf.cache_directory()): 
            self.template_cache = None
        else:
            cache_filename = 'cache.json'
            template_cache = CacheHandler(file_path=str(agent_conf.cache_directory()) + cache_filename,\
                expires_in=self.cache_expires_seconds) 
            
            try:
                template_cache.purge()
            except Exception as e:
                self.logger.debug("Unable to purge template cache directory. This is non-fatal so moving-on.")
            self.template_cache = template_cache
        
        ##
        # Process default archives directory
        self.logf.global_context = {} #reset logging context
        default_archives = []
        archive_files = glob.glob(str(self.archive_directory) + '/*.json')
        for archive_file in archive_files:
            log_ctx = {"archive_file" : archive_file}
            self.logger.debug(self.logf.format("Loading default archive file {}".format(archive_file), log_ctx))
            archive_client = ArchiveConnect(url=archive_file)
            archive = archive_client.get_config()
            if archive_client.error:
                self.logger.error(self.logf.format("Error reading default archive file: " + str(archive_client.error), log_ctx))
                continue
            
            #validate
            errors = archive.validate()
            if errors:
                cat = "archive_schema_validation_error"
                for error in errors:
                    self._log_validation_error(error, cat, strip_prefix="archives")
                continue
            
            default_archives.append(archive)

        self.default_archives = default_archives

        ##
        # process default transforms directory
        default_transforms = []
        transform_files = glob.glob(str(self.transform_directory) + '/*.json')

        for transform_file in transform_files:
            log_ctx = {"transform_file" : transform_file}
            self.logger.debug(self.logf.format("Loading transform file {}".format(transform_file), log_ctx))

            transform_client = TransformConnect(url=transform_file)
            transform = transform_client.get_config()

            if transform_client.error:
                self.logger.error(self.logf.format("Error reading default transform file: " + str(transform_client.error), log_ctx))
                continue

            #validate
            errors = transform.validate()
            if errors:
                cat = "transform_schema_validation_error"
                for error in errors:
                    self._log_validation_error(error, cat, strip_prefix="transform")
                continue

            default_transforms.append(transform)
        
        self.default_transforms = default_transforms

        ##
        # Process remotes
        psconfig_checksum_tracker = {}
        for remote in agent_conf.remotes(): 
            #create api filters
            filters = ApiFilters(ca_certificate_file=remote.ssl_ca_file()) 
            #create client
            psconfig_client = ApiConnect(
                url=remote.url(), 
                filters=filters,
                bind_address=remote.bind_address() 
            )

            #process tasks
            self.logf.global_context = {"config_src" : 'remote', 'config_url' : remote.url()}
            processed_psconfig = self._process_psconfig(psconfig_client, remote.transform()) 
            if not processed_psconfig:
                continue
            processed_psconfig_checksum = processed_psconfig.checksum() 
            if (psconfig_checksum_tracker.get(processed_psconfig_checksum)):
                self.logger.warning(self.logf.format("Checksum matches another psconfig already read, so skipping"))
                continue
            else:
                psconfig_checksum_tracker[processed_psconfig_checksum] = True
            if processed_psconfig:
                self._run_handle_psconfig(processed_psconfig, agent_conf, remote)
            self.logf.global_context = {}

        ##
        # process include directory
        include_files = glob.glob(str(self.include_directory) + '/*.json')
        for include_file in include_files:
            log_ctx = {"template_file": include_file}
            self.logger.debug(self.logf.format("Loading include file {}".format(include_file), log_ctx))
            #create client
            psconfig_client = ApiConnect(
                url=include_file
            )
            #process tasks
            self.logf.global_context = {"config_src" : 'include', 'config_file' : include_file}
            processed_psconfig = self._process_psconfig(psconfig_client, transform=None) ########################no transform supplied. does that mean no local transforms for default includes?
            if not processed_psconfig:
                continue
            processed_psconfig_checksum = processed_psconfig.checksum()
            if psconfig_checksum_tracker.get(processed_psconfig_checksum): 
                self.logger.warning(self.logf.format("Checksum matches another psconfig already read, so skipping", log_ctx))
                continue
            else:
                psconfig_checksum_tracker[processed_psconfig_checksum] = True
            if processed_psconfig:
                self._run_handle_psconfig(processed_psconfig, agent_conf)
            self.logf.global_context = {}
        
        ##
        # Call implementation specific code to wrap-up run
        self._run_end(agent_conf)
    
    def _process_psconfig(self, psconfig_client, transform):
        #variable to track whether we are working with cached copy
        using_cached = False

        #get config
        psconfig = psconfig_client.get_config()

        if psconfig_client.error:
            self.logger.error(self.logf.format("Error loading psconfig: " + str(psconfig_client.error)))
            
            psconfig = self._get_cached_template(psconfig_client.url)
            if not psconfig:
                return
            using_cached = True
        
        self.logger.debug(self.logf.format('Loaded pSConfig JSON', {'json' : psconfig.to_json()}))

        #validate
        errors = psconfig.validate()
        if errors:
            cat = "psconfig_schema_validation_error"
            for error in errors:
                self._log_validation_error(error, cat, log_obj={'expanded' : False, 'transformed' : False})

            psconfig = self._get_cached_template(psconfig_client.url)
            if not psconfig:
                return
            using_cached = True

        #expand
        if psconfig.includes():
            psconfig_client.expand_config(psconfig)
            if psconfig_client.error:
                self.logger.error(self.logf.format("Error expanding include directives in JSON: " + str(psconfig_client.error)))

                psconfig = self._get_cached_template(psconfig_client.url)
                if not psconfig:
                    return
                using_cached = True

            #validate
            errors = psconfig.validate() 
            if errors:
                cat = "psconfig_schema_validation_error"
                for error in errors:
                    self._log_validation_error(error, cat, log_obj={'expanded' : True, 'transformed' : False})
                psconfig = self._get_cached_template(psconfig_client.url)
                if not psconfig:
                    return
                using_cached = True

        #validate references
        errors = psconfig.validate_refs()
        if errors:
            cat = "psconfig_ref_validation_error"
            for error in errors:
                self.logger.error(self.logf.format(error, {
                'category' : cat,
                'expanded' : True,
                'transformed' : False
                }))

            psconfig = self._get_cached_template(psconfig_client.url)  
            if not psconfig:
                return
            using_cached = True
        
        #if we got this far, cache the template. do this prior to transforms or
        #we might get strange results. Do not do this if we are using a cached version  
        # or else the cached item will never expire
        if self.template_cache and (not using_cached):
            try:
                self.template_cache.set(psconfig_client.url, psconfig.to_json()) 
            except Exception as e:
                self.logger.debug("Error caching " + str(psconfig_client.url) + "This is non-fatal.")

        #apply default transforms
        for default_transform in self.default_transforms:
            self._apply_transform(default_transform, psconfig, 'include')
        
        #apply local transform
        self._apply_transform(transform, psconfig, 'remote_spec')

        #set requesting agent
        psconfig.requesting_agent_addresses = self.requesting_agent_addresses

        return psconfig
    
    def _get_cached_template(self, key):

        #if no cache, return
        if not self.template_cache:
            return
        
        #check cache
        try:
            psconfig_json = self.template_cache.getter(key)
        except Exception as e:
            self.logger.debug("Unable to load cached template for {}: {}").format(key, e)
        
        #build psconfig object
        psconfig = None
        if psconfig_json:
            psconfig = Config(data=psconfig_json)
            errors = psconfig.validate()
            if errors:
                self.logger.debug("Invalid cached template found for {}".format(key))
                for error in errors:
                    self._log_validation_error(error, "cached_schema_validation_error")
            else:
                self.logger.info("Using cached JSON template for {}".format(key))
        
        return psconfig

    def _apply_transform(self, transform, psconfig, transform_src):

        #make sure we got params we need
        if not (transform and psconfig and transform_src):
            return
        
        #set log context
        log_ctx = {'transform_src': transform_src} 

        #try to apply transformation
        new_data = transform.apply(psconfig.data)
        if ((not new_data) and transform.error):
            #error applying script
            self.logger.error(self.logf.format("Error applying transform: " + str(transform.error), log_ctx))
            return
        elif not new_data:
            #jq returned None
            self.logger.error(self.logf.format("Transform returned undefined value with no error. Check your JQ script logic.", log_ctx))
            return
        elif not isinstance(new_data, dict):
            # jq returned non dict value
            self.logger.error(self.logf.format("Transform returned a value that is not a JSON object. Check your JQ script logic.", log_ctx))
            return
        
        #validate json after applying
        psconfig.data = new_data
        errors = psconfig.validate()
        if errors:
            #validation errors
            cat = "psconfig_schema_validation_error"
            for error in errors:
                self._log_validation_error(error, cat, log_obj={'expanded' : True, 'transformed' : True, 'transform_src' : transform_src})
            return
        log_ctx['json'] = psconfig.to_json()
        self.logger.debug(self.logf.format("Transform completed", log_ctx))


    def _build_pscheduler_url(self, hostport): ###########check if this implementation is sufficient
        if hostport.startswith('['):
            host, port = hostport.split(']')
            host = host[1:]
            port = port[1:]
        else: 
            host = hostport
            port = None
        try:
            if type(ip_address(host)) is IPv6Address:
                address = "[{}]".format(host)
            elif type(ip_address(host)) is IPv4Address:
                address = host
            if port:
                address = address + ':' + port
            uri = 'https://{}/pscheduler'.format(address)
        except Exception as e:
            uri = 'https://{}/pscheduler'.format(hostport)
        return uri

    def _requesting_agent_from_file(self, requesting_agent_file):
        log_ctx = {'requesting_agent_file': requesting_agent_file}

        #if no file, return
        if not requesting_agent_file:
            return
        
        #if file does not exist then return
        if not os.path.isfile(requesting_agent_file): ##checks only if it is a regular file
            return
        
        #try loading from a file
        ra_client = RequestingAgentConnect(url=requesting_agent_file)
        requesting_agent = ra_client.get_config() 
        if ra_client.error:
            self.logger.error(self.logf().format("Error reading requesting agent file: " + str(ra_client.error), log_ctx))
            return
        
        #validate
        errors = requesting_agent.validate() 
        if errors:
            cat = "requesting_agent_schema_validation_error"
            for error in errors:
                self._log_validation_error(error, cat, strip_prefix='addresses', log_obj={'requesting_agent_file' : requesting_agent_file})
            return
        
        #return data
        log_ctx['requesting_agent'] = requesting_agent.data 
        self.logger.debug(self.logf.format("Loaded requesting agent from file {}".format(requesting_agent_file), log_ctx))
        return requesting_agent.data 

    def _get_addresses(self):
        ret_addresses = {}
        all_addresses = []

        #try to get the hostname a few different ways
        try:
            hostname = socket.gethostname()
            if hostname:
                all_addresses.append(hostname.strip())
        except:
            pass
        try:
            fqdn = socket.getfqdn()
            if fqdn:
                all_addresses.append(fqdn.strip())
        except:
            pass

        ips = Host().get_ips()
        for ip in ips:
            #skip invalid ips
            try:
                ip_type_addr = ip_address(ip)
                if not ((isinstance(ip_type_addr, IPv4Address) and ip_type_addr.is_loopback) or (isinstance(ip_type_addr, IPv6Address) and ip_type_addr in IPv6Network("::1/128"))): ####simplify
                    all_addresses.append(ip_type_addr)
            except:
                pass
        for address in all_addresses:
            if (not address) or ret_addresses.get(str(address)):
                continue
            ret_addresses[str(address)] = True

            if isinstance(address, IPv4Address) or isinstance(address, IPv6Address):
                hostnames = reverse_dns(str(address))
                all_addresses += hostnames
            else: #######not checking if address is hostname since dns resolution exceptions are handled
                addresses = resolve_address(address)
                all_addresses += addresses
        
        ret_addresses = list(ret_addresses.keys())

        return ret_addresses

    def _load_config(self, config_file):

        ##
        #Load config file
        agent_conf_client = self._config_client()
        agent_conf_client.url = config_file
        if agent_conf_client.error:
            raise Exception("Error opening {}: {}".format(config_file, agent_conf_client.error)) 
       
        agent_conf = agent_conf_client.get_config() 
        if agent_conf_client.error:
            raise Exception("Error parsing {}: {}".format(config_file, agent_conf_client.error))
        
        agent_conf_errors = agent_conf.validate() 
        if agent_conf_errors:
            err = self._format_validation_error(
                    agent_conf_errors, 
                    msg="{} is not valid. The following errors were encountered:".format(config_file)
                )
            raise Exception(err)
        
        return agent_conf
    
    def _format_validation_error(self, validation_errors, msg=""):
        for error in validation_errors:
            if msg:
                msg += "\n"
            if isinstance(error, ValidationError):
                if error.path:
                    msg += "    JSON Path: {}\n".format("/".join(list(map(lambda x: str(x), error.path))))
                msg += "    Error: {}\n".format(error.message)
            else:
                msg +=  "    {}".format(str(error))
        return msg

    def _log_validation_error(self, error, cat, strip_prefix="", log_obj={}):
        log_obj['category'] = cat
        msg = ""
        if isinstance(error, ValidationError):
            path = "/".join(list(map(lambda x: str(x), error.path)))
            if strip_prefix:
                path = re.sub('^/{}/'.format(strip_prefix), '', path) #makes prettier error message
            log_obj['json_path'] = path
            msg = error.message
        else:
            msg = str(error)
        self.logger.error(self.logf.format(msg, log_obj))

class BaseAgentNode(BaseNode):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.error = ''
    
    def remotes(self, val=None):
        '''Sets/gets list of Remote objects'''
        return self._field_class_list('remotes', Remote, val)
    
    def remote(self, index, val=None):
        '''Sets/gets Remote object at given index'''
        return self._field_class_list_item('remotes', index, Remote, val)
    
    def add_remote(self, val=None):
        '''Adds Remote object to remotes list'''
        self._add_field_class('remotes', Remote, val)
    
    def include_directory(self, val=None):
        '''Gets/sets the directory where local configuration files live'''
        return self._field('include-directory', val)
    
    def archive_directory(self, val=None):
        '''Gets/sets the directory where local archiver definitions live'''
        return self._field('archive-directory', val)
    
    def transform_directory(self, val=None):
        '''Gets/sets the directory where local transform scripts live'''
        return self._field('transform-directory', val)
    
    def requesting_agent_file(self, val=None):
        '''Gets/sets the location of a file with the requesting agent definition'''
        return self._field('requesting-agent-file', val)

    def pscheduler_assist_server(self, val=None):
        '''Sets/gets the pscheduler-assist-server field as a host with optional port in form HOST:PORT'''
        return self._field_urlhostport('pscheduler-assist-server', val)

    def check_interval(self, val=None):
        '''Gets/sets how often to check for changes to remote configuation files. Formatted as IS8601
        duration.'''
        return self._field_duration('check-interval', val)
    
    def check_config_interval(self, val=None):
        '''Gets/sets how often to check for changes to local configuation files. Formatted as IS8601
        duration.'''
        return self._field_duration('check-config-interval', val)
        
    def disable_cache(self, val=None):
        '''Gets/sets whether templates should be cached'''
        return self._field_bool('disable-cache', val)
    
    def cache_directory(self, val=None):
        '''Gets/sets the directory where cached templates live'''
        return self._field('cache-directory', val)
    
    def cache_expires(self, val=None):
        '''Gets/sets how long to keep templates cached'''
        return self._field_duration('cache-expires', val)
    
    def schema(self):
        '''Override this'''
        return {}

    def validate(self):
        '''Validates this object against JSON schema. Returns error messages of a 0 length array if valid'''
        schema = self.schema()
        try:
            validator = jsonvalidate(instance=self.data, schema=schema)
            return []
        except Exception as e:
            return [e]
