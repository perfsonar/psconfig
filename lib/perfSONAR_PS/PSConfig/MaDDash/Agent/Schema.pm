package perfSONAR_PS::PSConfig::MaDDash::Agent::Schema;


use strict;
use warnings;
use JSON;

use base 'Exporter';

our @EXPORT_OK = qw( psconfig_maddash_agent_json_schema );

=item psconfig_maddash_agent_json_schema()

Returns the JSON schema

=cut

sub psconfig_maddash_agent_json_schema() {

    my $raw_json = <<'EOF';
{
    "id": "http://www.perfsonar.net/psconfig-maddash-agent-schema#",
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "pSConfig MaDDash Agent Schema",
    "description": "Schema for pSConfig MaDDash agent configuration file. This is the file that tells the agent what pSConfig files to download and controls basic behaviors of agent script.",
    "type": "object",
    "additionalProperties": false,
    "required": [ "grids" ],
    "properties": {
    
        "remotes": {
            "type": "array",
            "items": { "$ref": "#/pSConfig/RemoteSpecification" },
            "description": "List of remote pSConfig JSON files to to read"
        }, 
                
        "include-directory": {
            "type": "string",
            "description": "Directory with local pSConfig files to be processed. Default is /etc/perfsonar/psconfig/maddash.d"
        },
        
        "archive-directory": {
            "type": "string",
            "description": "Directory with default archives to be added to all tasks. Default is /etc/perfsonar/psconfig/archives.d"
        },
        
        "transform-directory": {
            "type": "string",
            "description": "Directory with default transformations to apply to JSON processed by agent. Default is /etc/perfsonar/psconfig/transforms.d"
        },
        
        "check-plugin-directory": {
            "type": "string",
            "description": "Directory with plugins for checks. Default is /usr/lib/perfsonar/psconfig/checks"
        },
        
        "visualization-plugin-directory": {
            "type": "string",
            "description": "Directory with plugins for visualizations. Default is /usr/lib/perfsonar/psconfig/visualization"
        },
        
        "maddash-yaml-file": {
            "type": "string",
            "description": "MaDDash YAML configuration file to generate. Default is /etc/maddash/maddash-server/maddash.yaml"
        },
        
        "pscheduler-assist-server": {
            "$ref": "#/pSConfig/URLHostPort",
            "description": "URL of pScheduler assist server to use when validating tests. Default is the local pScheduler server."
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
        
        "grids": {
            "type": "object",
            "patternProperties": { 
                "^[a-zA-Z0-9:._\\-]+$": { "$ref": "#/pSConfig/Grid" }
            },
            "additionalProperties": false
        }

    },
    
    "pSConfig": {
        
        "AddressMap": {
            "type": "object",
            "patternProperties": { 
                "^[a-zA-Z0-9:._\\-]+$": { "$ref": "#/pSConfig/Host" }
            },
            "additionalProperties": false
        },
        
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
        
        "CheckConfig": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "Type of check"
                },
                "archive-selector": {
                    "$ref": "#/pSConfig/JQTransformSpecification",
                    "description": "Allows you to select an archive based on additional criteria to be passed to the check"
                },
                "check-interval": {
                    "$ref": "#/pSConfig/Duration",
                    "description": "How often to run check"
                },
                "warning-threshold": {
                    "type": "string",
                    "description": "Threshold for warning level"
                },
                "critical-threshold": {
                    "type": "string",
                    "description": "Threshold for critical level"
                },
                "report-yaml-file": {
                    "type": "string",
                    "description": "Location of YAML file with report to use for this check"
                },
                "retry-interval": {
                    "$ref": "#/pSConfig/Duration",
                    "description": "How often to check after a check detects a change in state"
                },
                "retry-attempts": {
                    "$ref": "#/pSConfig/IntZero",
                    "description": "How many times to retry after detecting a change in state"
                },
                "timeout": {
                    "$ref": "#/pSConfig/Duration",
                    "description": "How long to wait for check to complete"
                },
                "params": {
                    "$ref": "#/pSConfig/AnyJSON",
                    "description": "Plug-in specific parameters"
                }
            },
            "additionalProperties": false,
            "required": [ "type" ]
        },
        
    
        "Duration": {
            "type": "string",
            "pattern": "^P(?:\\d+(?:\\.\\d+)?W)?(?:\\d+(?:\\.\\d+)?D)?(?:T(?:\\d+(?:\\.\\d+)?H)?(?:\\d+(?:\\.\\d+)?M)?(?:\\d+(?:\\.\\d+)?S)?)?$",
            "x-invalid-message": "'%s' is not a valid ISO 8601 duration."
        },
        
        "Grid": {
            "type": "object",
            "properties": {
                "display-name": {
                    "type": "string",
                    "description": "Name to be used in title of maddash grids."
                },
                "check": {
                    "$ref": "#/pSConfig/CheckConfig",
                    "description": "Configuration of check plugin used in this grid"
                },
                "visualization": {
                    "$ref": "#/pSConfig/VisualizationConfig",
                    "description": "Configuration of visualization used in this grid"
                },
                "selector": {
                    "$ref": "#/pSConfig/TaskSelector",
                    "description": "Matches tasks that will be used to generate grids"
                },
                "priority": {
                    "$ref": "#/pSConfig/GridPriority",
                    "description": "Priority of grid."
                }
            },
            "additionalProperties": false,
            "required": [ "display-name", "check", "visualization" ]
        },
        
        "GridPriority": {
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
            "additionalProperties": false,
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
            "additionalProperties": false,
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
                    "description": "If true will use archives specified in remote psconfig file. Default it false."
                },
                "transform": { 
                    "$ref": "#/pSConfig/JQTransformSpecification",
                    "description": "JQ script to transform downloaded pSConfig JSON"
                    
                },
                "bind-address": { 
                    "$ref": "#/pSConfig/Host",
                    "description": "Local address to use when downloading JSON. Default is to let local routing tables choose."
                },
                "ssl-validate-certificate": { 
                    "type": "boolean",
                    "description": "If true, validates SSL certificate common name matches hostname. Default is false." 
                },
                "ssl-ca-file": { 
                    "type": "string",
                    "description": "A typical certificate authority (CA) file found on BSD. Used to verify server SSL certificate when using https." 
                },
                "ssl-ca-path": { 
                    "type": "string",
                    "description": "A typical certificate authority (CA) path found on Linux. Used to verify server SSL certificate when using https." 
                }
            },
            "additionalProperties": false,
            "required": [ "url" ]
        },
        
        "TaskSelector": {
            "type": "object",
            "properties": {
                "test-type": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Match against any test-type in the list"
                },
                "task-name": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Match against any task name in the list"
                },
                "archive-type": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Match against any archiver with the given type"
                },
                "jq": { 
                    "$ref": "#/pSConfig/JQTransformSpecification",
                    "description": "JQ script to transform downloaded pSConfig JSON"
                    
                }
            },
            "additionalProperties": false
        },
        
        "URLHostPort": {
            "anyOf": [
                { "$ref": "#/pSConfig/HostNamePort" },
                { "$ref": "#/pSConfig/IPv6RFC2732" }
            ]
        },
        
        "VisualizationConfig": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "description": "Type of check"
                },
                "base-url": {
                    "type": "string",
                    "description": "Overrides default base-url"
                },
                "params": {
                    "$ref": "#/pSConfig/AnyJSON",
                    "description": "Plug-in specific parameters"
                }
            },
            "additionalProperties": false,
            "required": [ "type" ]
        }
    }
}
EOF

    return from_json($raw_json);
}