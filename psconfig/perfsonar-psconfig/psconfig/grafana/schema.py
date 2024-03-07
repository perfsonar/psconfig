'''
Returns json schema
'''

class Schema(object):

    def psconfig_grafana_json_schema(self):

        raw_json = {
            "id": "http://www.perfsonar.net/psconfig-grafana-agent-schema#",
            "$schema": "http://json-schema.org/draft-04/schema#",
            "title": "pSConfig Grafana Agent Schema",
            "description": "Schema for pSConfig Grafana agent configuration file. This is the file that tells the agent what pSConfig files to download and controls basic behaviors of agent script.",
            "type": "object",
            "additionalProperties": False,
            "required": [ "displays", "grafana-dashboard-template" ],
            "properties": {
            
                "remotes": {
                    "type": "array",
                    "items": { "$ref": "#/pSConfig/RemoteSpecification" },
                    "description": "List of remote pSConfig JSON files to to read"
                }, 
                        
                "include-directory": {
                    "type": "string",
                    "description": "Directory with local pSConfig files to be processed. Default is /etc/perfsonar/psconfig/grafana.d"
                },
                
                "archive-directory": {
                    "type": "string",
                    "description": "Directory with default archives to be added to all tasks. Default is /etc/perfsonar/psconfig/archives.d"
                },
                
                "transform-directory": {
                    "type": "string",
                    "description": "Directory with default transformations to apply to JSON processed by agent. Default is /etc/perfsonar/psconfig/transforms.d"
                },
                
                "requesting-agent-file": {
                    "type": "string",
                    "description": "Path to file defining JSON to be used as the requesting-agent data source in address classes. Default is /etc/psconfig/requesting-agent.json. If file does not exist, a default set of JSON will be generated based on local host interfaces."
                },

                "pscheduler-assist-server": {
                    "$ref": "#/pSConfig/URLHostPort",
                    "description": "URL of pScheduler assist server to use when validating tests. Default is the local pScheduler server."
                },

                "check-interval": {
                    "$ref": "#/pSConfig/Duration",
                    "description": "ISO8601 indicating how often to check for changes to the pSConfig files in remotes and includes. Default is 1 hour ('PT1H')."
                },
                
                "check-config-interval": {
                    "$ref": "#/pSConfig/Duration",
                    "description": "ISO8601 indicating how often to check for changes to the local configuration files. This includes this config file, the includes directory, the requesting-agent file and the archives directory. Default is 1 minute ('PT60S')."
                },
                
                "disable-cache": {
                    "type": "boolean",
                    "description": "Boolean indicating that if a template cannot be accessed or is invalid, a cached version should NOT be used if exists. The cache prevents inaccessible or invalid templates from causing tasks to be deleted immediately. Items in cache expire, so it will only protect tasks from deletion while cache entry is valid. Default is False."
                },
                
                "cache-directory": {
                    "type": "string",
                    "description": "Path to directory where templates should be cached. Default is /var/lib/maddash/template_cache."
                },
                
                "cache-expires": {
                    "$ref": "#/pSConfig/Duration",
                    "description": "ISO8601 indicating how long to cache templates. Default is 1 day (P1D)."
                },

                "grafana-dashboard-template": {
                    "type": "string",
                    "description": "The file path to a Jinja2 template on the local system that will be used to build dashboards."
                },

                "grafana-url": {
                    "type": "string",
                    "format": "uri",
                    "description": "The URL of the grafana server where dashboards and datasources will be built"
                },

                "grafana-token": {
                    "type": "string",
                    "description": "The authentication token to use when contacting grafana"
                },

                "grafana-user": {
                    "type": "string",
                    "description": "The user for authentication to server. Ignored if token specified."
                },

                "grafana-password": {
                    "type": "string",
                    "description": "The password for authentication to server. Ignored if token specified."
                },

                "grafana-folder": {
                    "type": "string",
                    "description": "The folder in Grafana to store dashboards."
                },

                "grafana-dashboard-tag": {
                    "type": "string",
                    "description": "The tag applied to dashboards created by this agent. Defaults to perfsonar-psconfig."
                },

                "grafana-datasource-create": {
                    "type": "boolean",
                    "description": "Indicates whether we should automatically create datasources in Grafana from a default or use the existing datasource specified by grafana-datasource-name"
                },

                "grafana-datasource-settings": {
                    "type": "object",
                    "description": "Default settings for datasources created based on the archive definition in pSConfig template. Defaults to set for an Opensearch datasource setup as a perfSONAR Archive"
                },

                "grafana-datasource-name": {
                    "type": "string",
                    "description": "The name of an existing datasource in Grafana to use if automatic datasource creation is disabled or no suitable archive can be mapped to a data source for a task."
                },

                "grafana-datasource-name-format": {
                    "type": "string",
                    "description": "A python style formatted string used to generate Grafana datsource names. Any {} will be replaced with the datasource URL. Default: https://{}/opensearch"
                },

                "grafana-datasource-url-format": {
                    "type": "string",
                    "description": "A python style formatted string used to generate Grafana datsource names. Any {} will be replaced with the datasource URL. Default: pSConfig pScheduler - {}"
                },

                "task-group-default": {
                    "type": "string",
                    "description": "The name of a default task group for all displays. Example: 'All Dashboards'"
                },

                "task-groups": {
                    "type": "object",
                    "patternProperties": { 
                        "^[a-zA-Z0-9:._\\-]+$": { "type": "array", "items": { "type": "string" } }
                    },
                    "description": "Groups tasks together into the same dashboard. The key is just a name and the values must map to task names in a pSConfig file",
                    "additionalProperties": False
                },

                "displays": {
                    "type": "object",
                    "patternProperties": { 
                        "^[a-zA-Z0-9:._\\-]+$": { "$ref": "#/pSConfig/Display" }
                    },
                    "additionalProperties": False
                }
            },
            
            "pSConfig": {

                "AnyJSON": {
                    "anyOf": [
                        { "type": "array" },
                        { "type": "boolean" },
                        { "type": "integer" },
                        { "type": "null" },
                        { "type": "number" },
                        { "type": "object" },
                        { "type": "string" }
                    ]
                },
                
                "Cardinal": {
                    "type": "integer",
                    "minimum": 1
                },
                
                "Display": {
                    "type": "object",
                    "properties": {
                        "task_selector": {
                            "$ref": "#/pSConfig/TaskSelector",
                            "description": "Matches tasks that will be used to generate display"
                        },
                        "datasource_selector": {
                            "type": "string",
                            "enum": [ "auto", "manual" ],
                            "description": "Define how to determine the data source to use. 'auto' means it will try to detrmine an archive based on pSConfig template and will fallback to the default defined by grafana-datasource-name. 'manual' means it will just use grafana-datasource-name. "
                        },
                        "priority": {
                            "$ref": "#/pSConfig/Priority",
                            "description": "Priority of display."
                        },
                        "stat_field": {
                            "type": "string",
                            "description": "The field to use in calculating the stat for this display"
                        },
                        "stat_type": {
                            "type": "string",
                            "description": "The type of stat to calculate"
                        },
                        "stat_meta": {
                            "type": "object",
                            "description": "Additional information needed for certain types of stats"
                        },
                        "static_fields": {
                            "type": "boolean",
                            "description": "Boolean indicating that task will have static rows and columns"
                        },
                        "row_field": {
                            "type": "string",
                            "description": "The name of the field to use for the rows"
                        },
                        "col_field": {
                            "type": "string",
                            "description": "The name of the field to use for the columns"
                        },
                        "value_field": {
                            "type": "string",
                            "description": "The name of the field to use as the stat. Often the stat_type with first letter capitalized"
                        },
                        "value_text": {
                            "type": "string",
                            "description": "The name to be displayed as a label for the stat"
                        },
                        "unit": {
                            "type": "string",
                            "description": "The unit of the stat. See Grafana docs for built-in units."
                        },
                        "matrix_url": {
                            "type": "string",
                            "format": "uri",
                            "description": "A static URL to which matrices will link. This URL must link to a dashboard created outside pSConfig. See matrix_url_template if need dynamic creation of linked dashboard."
                        },
                        "matrix_url_template": {
                            "type": "string",
                            "description": "Path to a template file to which matrices will link"
                        },

                        "matrix_url_var1": {
                            "type": "string",
                            "description": "The variable name used when passing the row to the link"
                        },

                        "matrix_url_var2": {
                            "type": "string",
                            "description": "The variable name used when passing the column to the link"
                        },
                        "thresholds": {
                            "type": "array",
                            "items": { "$ref": "#/pSConfig/ThresholdSpecification" },
                            "description": "Ordered list of threshold to apply to stat."
                        }
                    },
                    "additionalProperties": False,
                    "required": [ "task_selector", "datasource_selector", "stat_field", "stat_type", "row_field", "col_field", "value_field", "value_text", "unit", "thresholds" ]
                },

                "Duration": {
                    "type": "string",
                    "pattern": "^P(?:\\d+(?:\\.\\d+)?W)?(?:\\d+(?:\\.\\d+)?D)?(?:T(?:\\d+(?:\\.\\d+)?H)?(?:\\d+(?:\\.\\d+)?M)?(?:\\d+(?:\\.\\d+)?S)?)?$",
                    "x-invalid-message": "'%s' is not a valid ISO 8601 duration."
                },
                
                "Priority": {
                    "type": "object",
                    "properties": {
                        "group": {
                            "type": "string",
                            "description": "Name of priority group. Only one check from group will be used."
                        },
                        "level": {
                            "$ref": "#/pSConfig/IntZero",
                            "description": "Priority level. Matching check with highest level will be chosen."
                        }
                    },
                    "additionalProperties": False,
                    "required": [ "group", "level" ]
                },
                
                "Host": {
                    "anyOf": [
                        { "$ref": "#/pSConfig/HostName" },
                        { "$ref": "#/pSConfig/IPAddress" }
                    ]
                },
                
                "HostName": {
                    "type": "string",
                    "format": "hostname"
                },
                
                "HostNamePort": {
                    "type": "string",
                    "pattern": "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])(:[0-9]+)?$"
                },
                
                "IntZero": {
                    "type": "integer",
                    "minimum": 0
                },
                
                "IPAddress": {
                    "oneOf": [
                        { "type": "string", "format": "ipv4" },
                        { "type": "string", "format": "ipv6" }
                    ]
                },
                
                "IPv6RFC2732": {
                    "type": "string",
                    "pattern": "^\\[(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))\\](:[0-9]+)?$"
                },
                
                "JQTransformSpecification": {
                    "type": "object",
                    "properties": {
                        "script":   {
                            "anyOf": [
                                { "type": "string" },
                                { "type": "array", "items": { "type": "string" } }
                            ]
                        }
                    },
                    "additionalProperties": False,
                    "required": [ "script" ]
                },
                
                "Probability": {
                    "type": "number",
                    "minimum": 0.0,
                    "maximum": 1.0
                },
                
                "RemoteSpecification": {
                    "type": "object",
                    "properties": {
                        "url": { 
                            "type": "string", 
                            "format": "uri",
                            "description": "URL of psconfig file to read"
                            
                        },
                        "configure-archives": { 
                            "type": "boolean",
                            "description": "If enabled will use archives specified in remote psconfig file. Default is True."
                        },
                        "transform": { 
                            "$ref": "#/pSConfig/JQTransformSpecification",
                            "description": "JQ script to transform downloaded pSConfig JSON"
                            
                        },
                        "bind-address": { 
                            "$ref": "#/pSConfig/Host",
                            "description": "Local address to use when downloading JSON. Default is to let local routing tables choose."
                        },
                        "ssl-ca-file": { 
                            "type": "string",
                            "description": "A certificate authority (CA) file used to verify server SSL certificate when using https." 
                        }
                    },
                    "additionalProperties": False,
                    "required": [ "url" ]
                },
                
                "TaskSelector": {
                    "oneOf": [
                        { "$ref": "#/pSConfig/TaskTestTypesSelector" },
                        { "$ref": "#/pSConfig/TaskNamesSelector" }
                    ]
                },

                "TaskTestTypesSelector": {
                    "type": "object",
                    "properties": {
                        "test_types": {
                            "type": "array",
                            "items": { "type": "string" },
                            "description": "Match a task in your pSConfig file if it is of any type in the list"
                        },
                        "jq": { 
                            "$ref": "#/pSConfig/JQTransformSpecification",
                            "description": "Match a task in your pSConfig file unless it is boolean False or an empty string"
                        }
                    },
                    "required": ["test_types"],
                    "additionalProperties": False
                },

                "TaskNamesSelector": {
                    "type": "object",
                    "properties": {
                        "names": {
                            "type": "array",
                            "items": { "type": "string" },
                            "description": "Match a task in your pSConfig file if it has one of the names in the list"
                        }
                    },
                    "required": ["names"],
                    "additionalProperties": False
                },

                "ThresholdSpecification": {
                    "type": "object",
                    "properties": {
                        "color": {
                            "type": "string",
                            "description": "A name or hex value of color to use this threshold level"
                        },
                        "value": {
                            "type": [ "number", "null" ],
                            "description": "Numeric value representing this threshold level"
                        }
                    },
                    "required": ["color", "value"],
                    "additionalProperties": False
                },
                
                "URLHostPort": {
                    "anyOf": [
                        { "$ref": "#/pSConfig/HostNamePort" },
                        { "$ref": "#/pSConfig/IPv6RFC2732" }
                    ]
                }
            }
        }
        return raw_json
