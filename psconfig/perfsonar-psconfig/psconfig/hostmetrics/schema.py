'''
Returns json schema
'''

class Schema(object):

    def psconfig_hostmetrics_json_schema(self):

        raw_json = {
            "id": "http://www.perfsonar.net/psconfig-grafana-agent-schema#",
            "$schema": "http://json-schema.org/draft-04/schema#",
            "title": "pSConfig Host Metric Agent Schema",
            "description": "Schema for pSConfig Host Metric Agent configuration file. This is the file that tells the agent what pSConfig files to download and controls basic behaviors of agent script.",
            "type": "object",
            "additionalProperties": False,
            "required": [ "template-file", "output-file" ],
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

                "address-pattern": {
                    "type": "string",
                    "description": "Regex that matches addresses that should be included in generate configuration"
                },

                "node-exporter-url-format": {
                    "type": "string",
                    "description": "Python format string for creating the node_exporter URL where {} is the placeholder for the address. Default: https://{}/node_exporter/metrics"
                },

                "pshost-exporter-url-format": {
                    "type": "string",
                    "description": "Python format string for create perfSONAR Host Exporter URL where {} is the placeholder for the address. Default: https://{}/perfsonar_host_exporter"
                },

                "template-file": {
                    "type": "string",
                    "description": "Path to a Jinja2 template used to generate desired configuration"
                },

                "output-file": {
                    "type": "string",
                    "description": "Path to location where generated file should be stored."
                }, 

                "restart-service": {
                    "type": "string",
                    "description": "Name of a service to restart with systemctl if output file is updated"
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

                "Duration": {
                    "type": "string",
                    "pattern": "^P(?:\\d+(?:\\.\\d+)?W)?(?:\\d+(?:\\.\\d+)?D)?(?:T(?:\\d+(?:\\.\\d+)?H)?(?:\\d+(?:\\.\\d+)?M)?(?:\\d+(?:\\.\\d+)?S)?)?$",
                    "x-invalid-message": "'%s' is not a valid ISO 8601 duration."
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

                "URLHostPort": {
                    "anyOf": [
                        { "$ref": "#/pSConfig/HostNamePort" },
                        { "$ref": "#/pSConfig/IPv6RFC2732" }
                    ]
                }
            }
        }
        return raw_json
