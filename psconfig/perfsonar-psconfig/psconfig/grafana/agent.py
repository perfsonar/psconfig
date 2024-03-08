'''Agent that loads config and submits to Grafana
'''
import json
import logging
import os
import uuid
import requests
from .config_connect import ConfigConnect
from ..base_agent import BaseAgent
from ..client.psconfig.archive import Archive
from ..client.psconfig.parsers.task_generator import TaskGenerator
from ..client.psconfig.test import Test
from ..utilities.logging_utils import LoggingUtils
from jinja2 import Environment, FileSystemLoader
from requests.auth import HTTPBasicAuth
from urllib.parse import urlparse

class Agent(BaseAgent):
    '''Agent that loads config and submits to Grafana'''
    
    PSCONFIG_KEY_DISPLAY_TASK_GROUP = "display-task-group"
    PSCONFIG_KEY_DISPLAY_TASK_NAME = "display-task-name"
    UUID_NAMESPACE_PS=uuid.UUID(hex='8caa5877-053a-42ae-9fc7-2681c3d02511')
    PSCONFIG_KEY_GF_DS_URL = "grafana-datasource-url"
    PSCONFIG_KEY_GF_DS_SETTINGS = "grafana-datasource-settings"
    DEFAULT_GRAFANA_FOLDER = "perfSONAR pSConfig"
    DEFAULT_GRAFANA_DASHBOARD_TAG = "perfsonar-psconfig"
    DEFAULT_GRAFANA_DS_NAME_FORMAT = "pSConfig pScheduler - {}"
    DEFAULT_GRAFANA_URL_FORMAT = "https://{}/opensearch"
    DEFAULT_GRAFANA_DS_SETTINGS = {
        "type": "grafana-opensearch-datasource", 
        "url": "https://34.171.24.112/opensearch", 
        "user": "", 
        "database": "", 
        "basicAuth": False, 
        "isDefault": False, 
        "access": "proxy",
        "jsonData": {
            "database": "pscheduler*", 
            "flavor": "opensearch", 
            "maxConcurrentShardRequests": 5, 
            "pplEnabled": True, 
            "timeField": "pscheduler.start_time", 
            "tlsAuth": False, 
            "tlsSkipVerify": True,
            "version": "AUTO"
        }, 
        "readOnly": False
    }

    def __init__(self, **kwargs):
        super(Agent, self).__init__(**kwargs)
        self.logf = kwargs.get('logf', LoggingUtils())
        self.logger = logging.getLogger(__name__)
        self.task_logger = logging.getLogger('TaskLogger')
        self.transaction_logger = logging.getLogger('TransactionLogger')
    
    def _agent_name(self):
        return 'grafana'
    
    def _config_client(self):
        return ConfigConnect()

    def _run_start(self, agent_conf):
        ##
        # This runs at the beginning of each iteration before pulling down pSConfig templates

        ## Set defaults
        
        ##
        # Check for template file and exit if not specified
        if not agent_conf.grafana_dashboard_template():
            self.logger.error(self.logf.format("No grafana-dashboard-template specified. Unable to build dashboards without template."))
            return False
        #Load jinja template
        j2_environment = Environment(loader=FileSystemLoader(os.path.dirname(agent_conf.grafana_dashboard_template())))            
        self.grafana_dashboard_template = j2_environment.get_template(os.path.basename(agent_conf.grafana_dashboard_template()))

        ##
        #  Set cache directory per agent. Will not work to share since agents may
        #  have different permissions
        if not agent_conf.cache_directory():
            default = "/var/lib/perfsonar/psconfig/grafana_template_cache"
            self.logger.debug(self.logf.format("No cache-dir specified. Defaulting to {}".format(default)))
            agent_conf.cache_directory(default)

        ##
        # Settings related to task groups
        self.task_group_default = agent_conf.task_group_default()
        # Build mapping of task name to task groups
        self.task_groups_by_name = {}
        if agent_conf.task_groups():
            for tg_key, tg_vals in agent_conf.task_groups().items():
                for tg_val in tg_vals:
                    if not self.task_groups_by_name.get(tg_val, None):
                        self.task_groups_by_name[tg_val] = [ tg_key ]
                    else:
                        self.task_groups_by_name[tg_val].append(tg_key)

        ##
        # Settings related to Grafana
        if not agent_conf.grafana_url():
            default = "https://localhost/grafana"
            self.logger.debug(self.logf.format("No grafana-url specified. Defaulting to {}".format(default)))
            agent_conf.grafana_url(default)
        if not (agent_conf.grafana_token() or (agent_conf.grafana_user() and agent_conf.grafana_password())):
            self.logger.warn(self.logf.format("No grafana-token or grafana-user/grafana-password specified. Unless your grafana instance does not require authentication, then your attempts to create dashboards may fail ".format(default)))
        self.grafana_url = agent_conf.grafana_url()
        self.grafana_token = agent_conf.grafana_token()
        self.grafana_user = agent_conf.grafana_user()
        self.grafana_password = agent_conf.grafana_password()
        self.grafana_header = self._gf_build_header()
        self.grafana_auth = self._gf_build_auth()
        grafana_error = self._gf_test_connection()
        if grafana_error:
            self.logger.error(self.logf.format("Unable to reach grafana at {}: {}".format(self.grafana_url, grafana_error)))
            return False

        if not agent_conf.grafana_folder():
            default = self.DEFAULT_GRAFANA_FOLDER
            self.logger.debug(self.logf.format("No grafana-folder specified. Defaulting to {}".format(default)))
            agent_conf.grafana_folder(default)
        self.grafana_folder = agent_conf.grafana_folder()

        if not agent_conf.grafana_dashboard_tag():
            default = self.DEFAULT_GRAFANA_DASHBOARD_TAG
            self.logger.debug(self.logf.format("No grafana-dashboard-tag specified. Defaulting to {}".format(default)))
            agent_conf.grafana_dashboard_tag(default)
        self.grafana_dashboard_tag = agent_conf.grafana_dashboard_tag()
        self.managed_dashboards_by_uid = self._gf_list_dashboards_by_tag(self.grafana_dashboard_tag)

        if not agent_conf.grafana_datasource_name_format():
            agent_conf.grafana_datasource_name_format(self.DEFAULT_GRAFANA_DS_NAME_FORMAT)
        self.grafana_datasource_name_format = agent_conf.grafana_datasource_name_format()
        
        if not agent_conf.grafana_datasource_url_format():
            agent_conf.grafana_datasource_url_format(self.DEFAULT_GRAFANA_URL_FORMAT)
        self.grafana_datasource_url_format = agent_conf.grafana_datasource_url_format()
        
        if not agent_conf.grafana_datasource_settings():
            agent_conf.grafana_datasource_settings(self.DEFAULT_GRAFANA_DS_SETTINGS)
        self.grafana_datasource_settings = agent_conf.grafana_datasource_settings()
        
        self.grafana_datasource_create = agent_conf.grafana_datasource_create()
        self.grafana_datasource_name = agent_conf.grafana_datasource_name()
        
        #Lookup if grafana datasource exists
        self.grafana_datasource = None
        if self.grafana_datasource_name:
            self.grafana_datasource = self._gf_find_datasource(self.grafana_datasource_name)
            if not self.grafana_datasource:
                self.logger.error(self.logf.format("grafana-datasource-name '{}' does not exist on Grafana server. No dashboards will be created until data source is created manually on Grafana server or configuration is updated with the name of a valid data source.".format(self.grafana_datasource_name)))
                return False

        ##
        # Build map of existing grafana datasource organized by name
        self.grafana_datasource_by_name = self._gf_list_datasources_by_name()
        # Also init a map where we will track data sources we create/update this round so we only do so once per run
        self.grafana_datasource_updated_this_run = {}
        #Also init a map where we can track matrix_url dashboards created
        self.grafana_matrix_url_dash_created = {}

        ##
        # Lookup if folder exists and create if not
        self.folder_uid = self._gf_find_folder(self.grafana_folder)
        #If did not find, then create
        if not self.folder_uid:
            self.folder_uid = self._gf_create_folder(self.grafana_folder)
            #if create failed, then return false
            if not self.folder_uid:
                return False

        ##
        # Set home dashboard
        if agent_conf.grafana_home_dashboard_uid():
            self._gf_set_home_dashboard(agent_conf.grafana_home_dashboard_uid())

        return True
    
    def _run_handle_psconfig(self, psconfig, agent_conf, remote=None):
        #####
        # Build map of displays for faster lookups when we compare to tasks
        display_by_task_name = {}
        display_by_task_type = {}
        for display_name, display_config in agent_conf.displays().items():
            task_sel = display_config.task_selector()
            #build name map
            if task_sel.names():
                for task_name in task_sel.names():
                    #set if not exists
                    display_by_task_name[task_name] = display_by_task_name.get(task_name, {})
                    display_by_task_name[task_name][display_name] = display_config

            #build test type map
            if task_sel.test_types():
                for test_type in task_sel.test_types():
                    #set if not exists
                    display_by_task_type[test_type] = display_by_task_type.get(test_type, {})
                    display_by_task_type[test_type][display_name] = display_config
        
        ##
        # Iterate through tasks
        jinja_vars = {}
        for task_name in psconfig.task_names():
            #find task
            task = psconfig.task(task_name)
            if not task or task.disabled(): continue

            #expand task
            tg = TaskGenerator(
                psconfig=psconfig,
                pscheduler_url="",
                task_name=task_name,
                use_psconfig_archives=True
            )
            tg.start()
            tg.next()
            if tg.expanded_test is None:
                self.logger.warn(self.logf.format("Task {} does not have a valid test definition. Skipping.".format(task_name)))
                continue
            expanded_test = Test(data=tg.expanded_test)
            #get archives with template vars filled-in
            expanded_archives = []
            for expanded_archive in tg.expanded_archives:
                expanded_archives.append(Archive(data=expanded_archive))
            #get reference field
            task.reference(tg.expanded_reference)
            tg.stop()

            ##
            # Figure out our matching displays
            matching_display_config = {}
            displays_by_prio = {}
            # First try the name matches. Add unless is had prio
            for disp_name, disp_config in display_by_task_name.get(task_name, {}):
                self._eval_display(disp_name, disp_config, matching_display_config, displays_by_prio)

            #now try the test type matches
            for disp_name, disp_config in display_by_task_type.get(expanded_test.type(), {}).items():
                json_obj = {
                    "test": expanded_test.data,
                    "reference": task.reference(tg.expanded_reference)
                }
                if disp_config.task_selector().jq() and not disp_config.task_selector().jq().apply(json_obj):
                    #if jq script specified, skip if script does not match
                    self.logger.debug(self.logf.format("JQ from display config {} does not match task {}. Skipping.".format(disp_name, task_name)))
                    continue
                self._eval_display(disp_name, disp_config, matching_display_config, displays_by_prio)

            # make sure we have at least one matching display
            if not matching_display_config:
                self.logger.warn(self.logf.format("No display config for task {}. Skipping.".format(task_name)))
                continue
            
            ##
            # Determine how to group displays together 
            # Initialize with catch-all group
            display_task_groups = []
            if self.task_group_default:
                display_task_groups.append(self.task_group_default)
            # Load groups from local config
            if self.task_groups_by_name.get(task_name, None):
                #value is a list, so += to merge
                display_task_groups += self.task_groups_by_name[task_name]                   
            # Load any group from psconfig template
            meta_dtg = task.reference_param(self.PSCONFIG_KEY_DISPLAY_TASK_GROUP)
            if meta_dtg and isinstance(meta_dtg, list):
                #meta_dtg is a list, so += to merge
                display_task_groups +=meta_dtg

            ## 
            # Build the rows and columns from the pSConfig data
            group = psconfig.group(task.group_ref())
            if not group:
                self.logger.warn(self.logf.format("Invalid group name {}. Check for typos in your pSConfig template file. Skipping task {}.".format(task.group_ref(), task_name)))
                continue
            #TODO: Support single dimension?
            if group.dimension_count() != 2:
                self.logger.warn(self.logf.format("Only support groups with 2 dimensions. Skipping task {}.".format(task_name)))
                continue

            ##
            # Initialize Jinja vars common to all displays
            display_task_name = task.reference_param(self.PSCONFIG_KEY_DISPLAY_TASK_NAME)
            if not display_task_name:
                #default to task_name
                display_task_name = task_name
            var_obj = {
                "task_name": task_name,
                "display_task_name": display_task_name,
                "task": task.data,
                "group": group.data,
                "test": tg.expanded_test,
                "reverse": False
            }
            if task.schedule_ref():
                var_obj["schedule"] = psconfig.schedule(task.schedule_ref()).data
            #parse rows and cols   
            d_keys = ["rows", "cols"]
            for d in range(0,2):
                addresses = []
                for addr_sel in group.dimension(d):
                    for nla in addr_sel.select(psconfig):
                        if nla.get("label", None) and nla.get("address", None):
                            addresses.append(nla["address"].label(nla["label"]))
                        elif nla.get("address", None):
                            addresses.append(nla["address"].address())
                var_obj[d_keys[d]] = addresses

            for mdc_name, mdc in matching_display_config.items():
                ##
                # Init variables
                #build a display config specific version of template variables
                mdc_var_obj = var_obj.copy()

                ##
                # Determine the Grafana datasource
                if mdc.datasource_selector() == 'auto':
                    # create the data source or find existing based on pSConfig template
                    mdc_var_obj["grafana_datasource_name"], mdc_var_obj["grafana_datasource"] = self._select_gf_datasource(expanded_archives)
                elif mdc.datasource_selector() == 'manual' and self.grafana_datasource:
                    #use the manally defined datasource in the agent config
                    mdc_var_obj["grafana_datasource"] = self.grafana_datasource
                    mdc_var_obj["grafana_datasource_name"] = self.grafana_datasource_name
                else:
                    self.logger.warn(self.logf.format("'datasource_selector' is not auto and no grafana_datasource_name is defined for display {}. Skipping.".format(mdc_name)))
                    continue
                
                #make sure datasource was actually set 
                if not mdc_var_obj["grafana_datasource"]:
                    continue
                
                #build linked dashboard if needed
                mdc_var_obj["matrix_url"] = self._build_matrix_url(mdc, mdc_var_obj)

                #determine if we need static fields
                mdc_var_obj["static_fields"] = mdc.static_fields()

                ##
                # Apply display-specific settings 
                display_fields = [ "stat_field", "stat_type", "stat_meta", "row_field", "col_field", "value_field", "value_text", "unit", "matrix_url_var1", "matrix_url_var2", "thresholds" ]
                for display_field in display_fields:
                    if mdc.data.get(display_field, None):
                        mdc_var_obj[display_field] = mdc.data[display_field]

                # Check if we need a reverse copy of display variables for disjoint
                rev_var_obj = {}
                if not group.data.get("unidirectional", False) and sorted(mdc_var_obj[d_keys[0]]) != sorted(mdc_var_obj[d_keys[1]]):
                    rev_var_obj = mdc_var_obj.copy()
                    rev_var_obj["reverse"] = True
                   
                # Finally, organize the var_objs display task group
                # add to template variables organized by display task group
                for dtg in display_task_groups:
                    if dtg not in jinja_vars.keys():
                        jinja_vars[dtg] = {
                            "display_task_group": dtg, 
                            "grafana_uuid": str(uuid.uuid5(self.UUID_NAMESPACE_PS, dtg)),
                            "dashboard_tag": self.grafana_dashboard_tag,
                            "grafana_folder_uid": self.folder_uid,
                            "tasks": []
                        }
                    jinja_vars[dtg]['tasks'].append(mdc_var_obj)
                    if rev_var_obj:
                        jinja_vars[dtg]['tasks'].append(rev_var_obj)

        ##
        # Apply jinja template
        for jv in jinja_vars.values():
            #Remove from list we will use to delete old dashboards
            if self.managed_dashboards_by_uid.get(jv["grafana_uuid"]):
                del self.managed_dashboards_by_uid[jv["grafana_uuid"]]
            rendered_content = self.grafana_dashboard_template.render(jv)
            self._gf_create_dashboard(rendered_content, self.folder_uid)

    def _eval_display(self, disp_name, disp_config, matching_display_config, displays_by_prio):
        '''
        Evaluates a display configuration. If a priority is set, 
        the only adds to list if it has highest priority in priority 
        group. Otherwise just adds it to the match list.
        '''
        if disp_config.priority() is not None:
            if disp_config.priority().level() > displays_by_prio.get(disp_config.priority().group(), {}).get("level", -1):
                displays_by_prio[disp_config.priority().group()] = {
                    "level": disp_config.priority().level(),
                    "config": { disp_name: disp_config } 
                }
        else:
            matching_display_config[disp_name] = disp_config

    def _gf_build_header(self):
        '''
        Builds an HTTP header for submitting to Grafana API.
        '''
        header = {
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        if self.grafana_token:
            header["Authorization"] = "Bearer {}".format(self.grafana_token)

        return header

    def _gf_build_auth(self):
        '''
        Builds an Auth object for python requests if user/pass set for Grafana
        '''
        auth = None
        if self.grafana_user and self.grafana_password:
            auth = HTTPBasicAuth(self.grafana_user, self.grafana_password)

        return auth
    
    def _gf_build_url(self, path):
        '''
        Builds a URL for the Grafana API
        '''
        return "{}{}".format(self.grafana_url.strip().rstrip('/'), path)

    def _gf_http(self, url_path, action, method="get", data={}):
        '''
        General function for sending HTTP requests to Grafana and handling errors
        '''
        url = self._gf_build_url(url_path)
        return self._http(url, action, method, data, headers=self.grafana_header, auth=self.grafana_auth, log_prefix="grafana_")

    def _http(self, url, action, method="get", data={}, headers={}, auth=None, log_prefix=""):
        '''
        General function for sending HTTP requests and handling errors
        '''
        local_context = {}
        local_context["{}url".format(log_prefix)] = url
        local_context["action"] = "{}.start".format(action)
        if data:
            local_context["data"] = data
        self.transaction_logger.info(self.logf.format("", local_context=local_context))
        r = None
        msg=None
        try:
            r = None
            if method == "get":
                r = requests.get(url, headers=headers, auth=auth, verify=False)
            elif method == "post":
                r = requests.post(url, json=data, headers=headers, auth=auth, verify=False)
            elif method == "put":
                r = requests.put(url, json=data, headers=headers, auth=auth, verify=False)
            elif method == "patch":
                r = requests.patch(url, json=data, headers=headers, auth=auth, verify=False)
            elif method == "delete":
                r = requests.delete(url, headers=headers, auth=auth, verify=False)
            else:
                return None, "Invalid method specified."
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            msg="HTTP Error - {}".format(err)
        except requests.exceptions.Timeout as err:
            msg="Timeout Error - {}".format(err)
        except requests.exceptions.RequestException as err:
            msg="Request Error - {}".format(err)
        except:
            msg="General exception trying to contact {}".format(url)
        
        #log depending on if we got an error
        if msg:
            local_context["action"] = "{}.error".format(action)
            self.transaction_logger.error(self.logf.format(msg, local_context=local_context))
        else:
            local_context["action"] = "{}.end".format(action)
            try:
                local_context["response"] = r.json()
            except:
                pass
            self.transaction_logger.info(self.logf.format("", local_context=local_context))

        return r, msg
    
    ##
    # Tests grafana request and returns error message if a problem occurs
    def _gf_test_connection(self):
        '''
        Tests connection to Grafana by reaching out to the organization API
        '''
        r, msg = self._gf_http('/api/org', "grafana_test")

        return msg

    def _gf_find_datasource(self, name):
        '''
        Finds a datasource by name by querying grafana API and searching list
        '''
        r, msg = self._gf_http(f'/api/datasources/name/{name}', "find_datasource")
        if msg or not r:
            return
        uid = r.json().get("uid", None)
        type = r.json().get("type", None)
        if type is None or uid is None:
            return
        
        return { "type": type, "uid": uid}

    def _gf_list_datasources_by_name(self):
        '''
        Retrieves list of datasources from Grafana API and organizes 
        into dictionary where key is the datasource name and value is 
        an object with datasource type and uid
        '''
        r, msg = self._gf_http("/api/datasources", "list_datasources")
        if msg or not r:
            return {}
        ds_list = r.json()
        if not isinstance(ds_list, list):
            return {}
        ds_by_name = {}
        for ds in ds_list:
            if ds.get("name", None) and ds.get("type", None) and ds.get("uid", None):
                ds_by_name[ds["name"]] = {
                    "type": ds["type"],
                    "uid": ds["uid"],
                }

        return ds_by_name

    def _gf_list_dashboards_by_tag(self, tag):
        '''
        Retrieves list of dashbaords from Grafana API with a given tag
        and maps into dictionary where key is the dashboard UID and value
        is a boolean. This is used to track what dashboards we need to delete.
        '''
        r, msg = self._gf_http(f'/api/search?type=dash-db&tag={tag}', "search_dashboards_by_tag")
        if msg or not r:
            return {}
        dash_list = r.json()
        if not isinstance(dash_list, list):
            return {}
        dash_by_uid = {}
        for dash in dash_list:
            if dash.get("uid", None):
                dash_by_uid[dash['uid']] = True

        return dash_by_uid

    def _build_ds_name(self, ds_url):
        '''
        Formats the name of a datasource given the database URL. Format is 
        based on config.
        '''
        return  self.grafana_datasource_name_format.format(ds_url)

    def _ds_version(self, ds_body):
        '''
        Determine version of database for datasource. Required for Opensearch.
        '''
        #Detect database version if set to AUTO
        if ds_body.get("jsonData", {}).get("version","").upper() != "AUTO":
            #nothing to do
            return

        #clear out AUTO in case something fails
        ds_body["jsonData"]["version"] = None
        if ds_body["type"] != "grafana-opensearch-datasource":
            #only know how to get version for opensearch
            self.logger.error(self.logf.format("Datasource version set to AUTO but setting version not supported for datasource type {}. Manually change jsonData.version in config with {}".format(ds_body["type"], self.PSCONFIG_KEY_GF_DS_SETTINGS)))
            return

        #fetch version
        r, msg = self._http(ds_body["url"], "ds_version", log_prefix="ds_")
        if msg:
            #return if error making request
            return

        #parse version
        ds_body["jsonData"]["version"] = r.json().get("version", {}).get("number", None)
        if ds_body["jsonData"]["version"] is None:
            self.logger.error(self.logf.format("Unable to detect version for {} of type {}. Manually set version in config with {}".format(ds_body["url"], ds_body["type"], self.PSCONFIG_KEY_GF_DS_SETTINGS)))

    def _gf_create_datasource(self, ds_url, ds_settings):
        '''
        Creates a datasource using the Grafana API
        '''
        ds_body = ds_settings.copy()
        ds_body["url"] = ds_url
        ds_body["name"] = self._build_ds_name(ds_url)
        self._ds_version(ds_body)
        r, msg = self._gf_http("/api/datasources", "create_datasource", method="post", data=ds_body)
        if msg:
            self.logger.error(self.logf.format("Unable to create datasource for {}: {}".format(ds_url, msg)))
            return {}
        uid = r.json().get("datasource", {}).get("uid", None)
        ds_type = r.json().get("datasource", {}).get("type", None)
        if uid and ds_type:
            self.grafana_datasource_by_name[ds_body["name"]] = {
                "type": ds_type,
                "uid": uid
            }
            return self.grafana_datasource_by_name[ds_body["name"]]
        else:
            self.logger.error(self.logf.format("Something went wrong with datasource for {}. Unable to find uid.".format(ds_url)))
        
        return {}
    
    def _gf_update_datasource(self, ds_url, ds_settings, ds_name):
        '''
        Updates an existing datasource using Grafana API
        '''
        ds_body = ds_settings.copy()
        ds_body["url"] = ds_url
        ds_body["name"] = ds_name
        ds_body["uid"] = self.grafana_datasource_by_name.get(ds_name, {}).get("uid", None)
        ds_body["type"] = self.grafana_datasource_by_name.get(ds_name, {}).get("type", None)
        self._ds_version(ds_body)
        r, msg = self._gf_http(f'/api/datasources/uid/{ds_body["uid"]}', "update_datasource", method="put", data=ds_body)
        if msg:
            self.logger.error(self.logf.format("Unable to update datasource for {}: {}".format(ds_url, msg)))
            return {}
        uid = r.json().get("datasource", {}).get("uid", None)
        ds_type = r.json().get("datasource", {}).get("type", None)
        if uid and ds_type:
            self.grafana_datasource_by_name[ds_body["name"]] = {
                "type": ds_type,
                "uid": uid
            }
            return self.grafana_datasource_by_name[ds_body["name"]]
        else:
            self.logger.error(self.logf.format("Something went wrong with datasource for {}. Unable to find uid.".format(ds_url)))
        
        return {}

    def _select_gf_datasource(self, archives):
        '''
        Selects a grafana datasource based on a list of archives from pSConfig. 
        We only know how to configure datasource from archives that looks like 
        a standard perfSONAR logstash instance
        '''
        for archive in archives:
            url = None
            settings = {}
            # a couple variables for readability
            meta_url = archive.psconfig_meta_param(self.PSCONFIG_KEY_GF_DS_URL)
            data_url = archive.archiver_data_param("_url")
            if meta_url:
                # use the meta parameters set in psconfig. only URL required, settings optional.
                url = meta_url
                settings = archive.psconfig_meta_param(self.PSCONFIG_KEY_GF_DS_SETTINGS)
            elif archive.archiver("http") and data_url and data_url.endswith("/logstash"):
                # Extract URL from HTTP archiver that looks like logstash on perfsonar-archive
                url = self.grafana_datasource_url_format.format(urlparse(data_url).hostname)
            else:
                #can't build a data source from this archive
                continue

            #clean up any missing fields
            if not settings:
                settings = self.grafana_datasource_settings

            ds_name = self._build_ds_name(url)
            ds = None
            if self.grafana_datasource_by_name.get(ds_name, None) and self.grafana_datasource_updated_this_run.get(ds_name, False):
                #if datasource existsed and we created or updated this run, then use info we alreadt have
                ds = self.grafana_datasource_by_name[ds_name]
            elif self.grafana_datasource_create and self.grafana_datasource_by_name.get(ds_name, None):
                # if exists but we have not created or updated this run, then update now
                ds = self._gf_update_datasource(url, settings, ds_name)
            elif self.grafana_datasource_create:
                # if does not exist, then create
                ds = self._gf_create_datasource(url, settings)
            # If we have a data source, then we can stop searching
            if ds:
                self.grafana_datasource_updated_this_run[ds_name] = True
                return ds_name, ds

        #if no matches, then fallback to manual if set
        if self.grafana_datasource:
            return self.grafana_datasource_name, self.grafana_datasource
        else:
            self.logger.error(self.logf.format("Unable to find a suitable archive to use as Grafana datasource"))

        return None, {}

    def _gf_find_folder(self, name):
        '''
        Find folder with a given name using Grafana API
        '''
        r, msg = self._gf_http("/api/folders", "list_folders")
        if msg:
            self.logger.warn(self.logf.format("Unable to list grafana folders: {}".format(msg)))
        else:
            for folder in r.json():
                if name == folder.get("title", None):
                    return folder.get("uid", None)
            
        return

    def _gf_create_folder(self, name):
        '''
        Creates a folder using Grafana API
        '''
        r, msg = self._gf_http("/api/folders", "create_folder", method="post", data={"title": name})
        if msg:
            self.logger.warn(self.logf.format("Unable to create grafana folder: {}".format(msg)))
            return 
        
        return r.json().get("uid", None)

    def _gf_set_home_dashboard(self, uid):
        '''
        Sets home dashboard using Grafana API
        '''
        r, msg = self._gf_http("/api/org/preferences", "set_home_dashboard", method="patch", data={"homeDashboardUID": uid})
        if msg:
            self.logger.warn(self.logf.format("Unable to set home dashboard: {}".format(msg)))
            return

        return r.json()

    def _gf_create_dashboard(self, dash, folder_uid):
        '''
        Creates a dashboard using Grafana API
        '''
        data = {
            "dashboard": json.loads(dash),
            "overwrite": True,
            "folderUid": folder_uid
        }
        r, msg = self._gf_http("/api/dashboards/db", "create_dashboard", method="post", data=data)
        if msg:
            self.logger.error(self.logf.format("Unable to create grafana dashboard: {}".format(msg)))
        
        return r.json()

    def _gf_delete_dashboard(self, dash_uid):
        '''
        Deletes a dashboard using Grafana API
        '''
        r, msg = self._gf_http(f'/api/dashboards/uid/{dash_uid}', "delete_dashboard", method="delete")
        if msg:
            self.logger.error(self.logf.format("Unable to delete grafana dashboard {}: {}".format(dash_uid, msg)))

    def _build_matrix_url(self, mdc, mdc_var_obj):

        #check for static matrix url
        if mdc.matrix_url():
            return mdc.matrix_url()

        #Build dashboard for matrix_url_template if needed
        if not mdc.matrix_url_template():
            return
        
        #check if already built and return URL
        matrix_url_dash_key = "{}::{}".format(mdc.matrix_url_template(), mdc_var_obj["grafana_datasource_name"])
        if self.grafana_matrix_url_dash_created.get(matrix_url_dash_key, None):
            return self.grafana_matrix_url_dash_created[matrix_url_dash_key]
        
        #not built yet, so build
        j2_environment = Environment(loader=FileSystemLoader(os.path.dirname(mdc.matrix_url_template())))            
        j2_template = j2_environment.get_template(os.path.basename(mdc.matrix_url_template()))
        ds_jv_obj = {
            "grafana_datasource_name": mdc_var_obj["grafana_datasource_name"],
            "grafana_datasource": mdc_var_obj["grafana_datasource"],
            "grafana_uuid": str(uuid.uuid5(self.UUID_NAMESPACE_PS, matrix_url_dash_key)),
            "grafana_folder_uid": self.folder_uid,
            "dashboard_tag": self.grafana_dashboard_tag
        }
        rendered_content = j2_template.render(ds_jv_obj)
        if self.managed_dashboards_by_uid.get(ds_jv_obj["grafana_uuid"]):
                del self.managed_dashboards_by_uid[ds_jv_obj["grafana_uuid"]]
        dash_url = self._gf_create_dashboard(rendered_content, self.folder_uid).get("url", None)
        if dash_url:
            dash_url += "?"
            self.grafana_matrix_url_dash_created[matrix_url_dash_key] = dash_url
        return dash_url

    def _run_end(self, agent_conf):
        '''
        Runs when done processing all pSConfig files
        '''
        ##
        # Delete old dashboards
        for dash_uid in self.managed_dashboards_by_uid.keys():
            self._gf_delete_dashboard(dash_uid)

