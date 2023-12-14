'''Agent that loads config and submits to Grafana
'''
from ..client.psconfig.parsers.task_generator import TaskGenerator
from .config_connect import ConfigConnect
from ..base_agent import BaseAgent
from ..client.psconfig.archive import Archive
from ..client.psconfig.test import Test
import uuid
import requests
from requests.auth import HTTPBasicAuth
import logging
from urllib.parse import urlparse
from ..utilities.logging_utils import LoggingUtils

class Agent(BaseAgent):
    '''Agent that loads config and submits to Grafana'''
    
    PSCONFIG_KEY_DISPLAY_TASK_GROUP = "display-task-group"
    PSCONFIG_KEY_DISPLAY_TASK_NAME = "display-task-name"
    UUID_NAMESPACE_PS=uuid.UUID(hex='8caa5877-053a-42ae-9fc7-2681c3d02511')
    PSCONFIG_KEY_GF_DS_URL = "grafana-datasource-url"
    PSCONFIG_KEY_GF_DS_SETTINGS = "grafana-datasource-settings"
    DEFAULT_GRAFANA_DS_NAME_FORMAT = "pSConfig pScheduler - {}"
    DEFAULT_GRAFANA_URL_FORMAT = "https://{}/opensearch"
    DEFAULT_GRAFANA_SETTINGS = {
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
        
        #  Set cache directory per agent. Will not work to share since agents may
        #  have different permissions
        if not agent_conf.cache_directory():
            default = "/var/lib/perfsonar/psconfig/grafana_template_cache"
            self.logger.debug(self.logf.format("No cache-dir specified. Defaulting to {}".format(default)))
            agent_conf.cache_directory(default)

        # Setting related to task groups
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

        # Setting related to Grafana
        if agent_conf.grafana_url() and not (agent_conf.grafana_token() or (agent_conf.grafana_user() and agent_conf.grafana_password())):
            default = "https://localhost/grafana"
            self.logger.warn(self.logf.format("No grafana-token or grafana-user/grafana-password specified. Unless your grafana instance does not require authentication, then your attempts to create dashboards may fail ".format(default)))

        if not agent_conf.grafana_url():
            default = "https://localhost/grafana"
            self.logger.debug(self.logf.format("No grafana-url specified. Defaulting to {}".format(default)))
            agent_conf.grafana_url(default)
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
            default = "General"
            self.logger.debug(self.logf.format("No grafana-folder specified. Defaulting to {}".format(default)))
            agent_conf.grafana_folder(default)
        self.grafana_folder = agent_conf.grafana_folder()

        if not agent_conf.grafana_matrix_url():
            #This is the standard endpoint pair dashboard
            default = "/grafana/d/c5ce2fcb-e7f9-4aaf-b16d-0bc008a6e6f9/esnet-endpoint-pair-explorer?orgId=1"
            self.logger.debug(self.logf.format("No grafana-matrix-url specified. Defaulting to {}".format(default)))
            agent_conf.grafana_matrix_url(default)
        self.grafana_matrix_url = agent_conf.grafana_matrix_url()

        if not agent_conf.grafana_matrix_url_var1():
            #This is the standard endpoint pair dashboard
            default = "source"
            self.logger.debug(self.logf.format("No grafana-matrix-url-var1 specified. Defaulting to {}".format(default)))
            agent_conf.grafana_matrix_url_var1(default)
        self.grafana_matrix_url_var1 = agent_conf.grafana_matrix_url_var1()

        if not agent_conf.grafana_matrix_url_var2():
            #This is the standard endpoint pair dashboard
            default = "target"
            self.logger.debug(self.logf.format("No grafana-matrix-url-var2 specified. Defaulting to {}".format(default)))
            agent_conf.grafana_matrix_url_var2(default)
        self.grafana_matrix_url_var2 = agent_conf.grafana_matrix_url_var2()
        
        if not agent_conf.grafana_datasource_name_format():
            agent_conf.grafana_datasource_name_format(self.DEFAULT_GRAFANA_DS_NAME_FORMAT)
        self.grafana_datasource_name_format = agent_conf.grafana_datasource_name_format()
        
        if not agent_conf.grafana_datasource_url_format():
            agent_conf.grafana_datasource_url_format(self.DEFAULT_GRAFANA_URL_FORMAT)
        self.grafana_datasource_url_format = agent_conf.grafana_datasource_url_format()
        
        if not agent_conf.grafana_datasource_settings():
            agent_conf.grafana_datasource_settings(self.DEFAULT_GRAFANA_SETTINGS)
        self.grafana_datasource_settings = agent_conf.grafana_datasource_settings()
        
        self.grafana_datasource_create = agent_conf.grafana_datasource_create()
        self.grafana_datasource_name = agent_conf.grafana_datasource_name()
        #Lookup if grafana datasource exists
        if self.grafana_datasource_name:
            self.grafana_datasource = self._gf_find_datasource(self.grafana_datasource_name)
            if not self.grafana_datasource:
                self.logger.error(self.logf.format("grafana-datasource-name '{}' does not exist on Grafana server. No dashboards will be created until data source is created manually on Grafana server or configuration is updated with the name of a valid data source.".format(self.grafana_datasource_name)))
                return False

        ##
        # Build map of existing grafana datasource organized by name
        self.grafana_datasource_by_name = self._gf_list_datasources_by_name()

        
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
            print(task_name)
            print("-------------------")

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
                print("WARN: Task {} does not have a valid test definition".format(task_name))
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
                if disp_config.task_selector().jq():
                    #TODO: run some jq, if does not match then continue
                    pass
                self._eval_display(disp_name, disp_config, matching_display_config, displays_by_prio)

            # make sure we have at least one matching display
            if not matching_display_config:
                self.logger.warn(self.logf.format("No display config for task {} of type {}. Skipping.".format(task_name, test_type)))
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
                #TODO: LOGGING
                print("Invalid group name {}. Check for typos in your pSConfig template file.".format(task.group_ref()))
                continue
            #TODO: Support single dimension?
            if group.dimension_count() != 2:
                #TODO: LOGGING
                print("WARN: Only support groups with 2 dimensions")
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
                print("mdc_name={}".format(mdc_name))
                
                ##
                # Determine the Grafana datasource
                if mdc.datasource_selector() == 'auto':
                    # create the data source or find existing based on pSConfig template
                    mdc_var_obj["grafana_datasource"] = self._select_gf_datasource(expanded_archives)
                elif mdc.datasource_selector() == 'manual' and self.grafana_datasource:
                    #use the manally defined datasource in the agent config
                    mdc_var_obj["grafana_datasource"] = self.grafana_datasource
                else:
                    print("'datasource_selector' is not auto and no grafana_datasource_name is defined for display {}. Skipping.".format(mdc_name))
                    continue
                
                #make sure datasource was actually set 
                if not mdc_var_obj["grafana_datasource"]:
                    continue
                
                ##
                # Apply display-specific settings 
                display_fields = [ "stat_field", "stat_type", "stat_meta", "row_field", "col_field", "value_field", "value_text", "unit", "matrix_url", "matrix_url_var1", "matrix_url_var2" ]
                for display_field in display_fields:
                    if mdc.data.get(display_field, None):
                        mdc_var_obj[display_field] = mdc.data[display_field]

                # Check if we need a reverse copy of display variables for disjoint
                rev_var_obj = {}
                if sorted(mdc_var_obj[d_keys[0]]) != sorted(mdc_var_obj[d_keys[1]]):
                    rev_var_obj = mdc_var_obj.copy()
                    rev_var_obj["reverse"] = True
                   
                # Finally, organize the var_objs display task group
                # add to template variables organized by display task group
                for dtg in display_task_groups:
                    if dtg not in jinja_vars.keys():
                        uuid.uuid5(self.UUID_NAMESPACE_PS, dtg)
                        jinja_vars[dtg] = {
                            "display_task_group": dtg, 
                            "grafana_uuid": str(uuid.uuid5(self.UUID_NAMESPACE_PS, dtg)),
                            "tasks": []
                        }
                    jinja_vars[dtg]['tasks'].append(mdc_var_obj)
                    if rev_var_obj:
                        jinja_vars[dtg]['tasks'].append(rev_var_obj)

        ##
        # Apply jinja template
        print("jinja_vars={}".format(jinja_vars))
        for jv in jinja_vars.values():
            pass

        #TODO:Delete old data sources
        #TODO:Delete old dashboards
        #TODO:can we use tags to indicate which dashboard psconfig controls?

    def _eval_display(self, disp_name, disp_config, matching_display_config, displays_by_prio):
        if disp_config.priority() is not None:
            if disp_config.priority().level() > displays_by_prio.get(disp_config.priority().group(), {}).get("level", -1):
                displays_by_prio[disp_config.priority().group()] = {
                    "level": disp_config.priority().level(),
                    "config": { disp_name: disp_config } 
                }
        else:
            matching_display_config[disp_name] = disp_config

    def _gf_build_header(self):
        header = {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": "Bearer {}".format(self.grafana_token)
        }
        if self.grafana_token:
            header["Authorization"] = "Bearer {}".format(self.grafana_token)

        return header

    def _gf_build_auth(self):
        auth = None
        if self.grafana_user and self.grafana_password:
            auth = HTTPBasicAuth(self.grafana_user, self.grafana_password)

        return auth
    
    def _gf_build_url(self, path):
        return "{}{}".format(self.grafana_url.strip().rstrip('/'), path)

    def _gf_http(self, url_path, action, method="get", data={}):
        url = self._gf_build_url(url_path)
        local_context = {}
        local_context["grafana_url"] = url
        local_context["action"] = "{}.start".format(action)
        if data:
            local_context["data"] = data
        self.transaction_logger.info(self.logf.format("", local_context=local_context))
        r = None
        msg=None
        try:
            r = None
            if method == "get":
                r = requests.get(url, headers=self.grafana_header, auth=self.grafana_auth, verify=False)
            elif method == "post":
                r = requests.post(url, json=data, headers=self.grafana_header, auth=self.grafana_auth, verify=False)
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

        r, msg = self._gf_http('/api/org', "grafana_test")

        return msg

    def _gf_find_datasource(self, name):
        r, msg = self._gf_http(f'/api/datasources/name/{name}', "find_datasource")
        if msg or not r:
            return
        uid = r.json().get("uid", None)
        type = r.json().get("type", None)
        if type is None or uid is None:
            return
        
        return { "type": type, "uid": uid}

    def _gf_list_datasources_by_name(self):
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

    def _build_ds_name(self, ds_url):
        return  self.grafana_datasource_name_format.format(ds_url)

    def _gf_create_datasource(self, ds_url, ds_settings):
        ds_body = ds_settings.copy()
        ds_body["url"] = ds_url
        ds_body["name"] = self._build_ds_name(ds_url)
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

    def _select_gf_datasource(self, archives):
        for archive in archives:
            url = None
            type = None
            settings = {}
            #a couple variables for readability
            meta_url = archive.psconfig_meta_param(self.PSCONFIG_KEY_GF_DS_URL)
            data_url = archive.archiver_data_param("_url")
            if meta_url:
                # use the meta parameters set in psconfig. only URL required.
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
            if self.grafana_datasource_by_name.get(ds_name, None):
                return self.grafana_datasource_by_name[ds_name]
            elif self.grafana_datasource_create:
                return self._gf_create_datasource(url, settings)
        
        #if no matches, then return 
        self.logger.error(self.logf.format("Unable to find a suitable archive to use as Grafana datasource"))
        return

    def _run_end(self, agent_conf):
        pass

