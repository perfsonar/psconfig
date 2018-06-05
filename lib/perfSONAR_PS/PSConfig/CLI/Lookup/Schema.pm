package perfSONAR_PS::PSConfig::CLI::Lookup::Schema;


use strict;
use warnings;
use JSON;

use base 'Exporter';

our @EXPORT_OK = qw( psconfig_lookup_json_schema );

=item psconfig_lookup_json_schema()

Returns the JSON schema

=cut

sub psconfig_lookup_json_schema() {

    my $raw_json = <<'EOF';
{
    "id": "http://www.perfsonar.net/psconfig-lookup-schema#",
    "$schema": "http://json-schema.org/draft-04/schema#",
    "title": "pSConfig Lookup Schema",
    "description": "Schema for 'psconfig lookup' command's input file",
    "type": "object",
    "additionalProperties": false,
    "required": [ "queries" ],
    "properties": {

        "ls-urls": {
            "type": "array",
            "items": { "type": "string", "format": "uri" }
        },
        
        "queries": {
            "type": "object",
            "patternProperties": { 
                "^[a-zA-Z0-9:._\\-]+$": { "$ref": "#/pSConfig/QuerySpecification" }
            }
        }
    },
    
    "pSConfig": {
        
        "QuerySpecification": {
            "type": "object",
            "properties": {
                "record-type": { 
                    "type": "string", 
                    "enum": ["service", "interface", "host"]    
                },
                "filters": { 
                    "type": "object",
                    "patternProperties": { 
                        "^[a-zA-Z0-9:._\\-]+$": { "type": "string" }
                    }
                },
                "output": { "$ref": "#/pSConfig/OutputSpecification" }
            },
            "additionalProperties": false,
            "required": [ "record-type" ]
        },
        
        "OutputSpecification": {
            "type": "object",
            "properties": {
                "tags": { "type": "array", "items": { "type": "string" } },
                "no-agent": { "type": "boolean" },
                "_meta": { "$ref": "#/pSConfig/AnyJSON" },
                "archives": {
                    "type": "object",
                    "patternProperties": { 
                        "^[a-zA-Z0-9:._\\-]+$": { "$ref": "#/pSConfig/ArchiveSpecification" }
                    }
                },
                "contexts": {
                    "type": "object",
                    "patternProperties": { 
                        "^[a-zA-Z0-9:._\\-]+$": { "$ref": "#/pSConfig/ContextSpecification" }
                    }
                }
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
        
        "ArchiveSpecification": {
            "type": "object",
            "properties": {
                "archiver": { "type": "string" },
                "data": { "$ref": "#/pSConfig/AnyJSON" },
                "transform": { "$ref": "#/pSConfig/ArchiveJQTransformSpecification" },
                "ttl": { "$ref": "#/pSConfig/Duration" },
                "_meta": { "$ref": "#/pSConfig/AnyJSON" }
            },
            "additionalProperties": false,
            "required": [ "archiver", "data"]
        },
        
        "ArchiveJQTransformSpecification": {
            "type": "object",
            "properties": {
                "script":   {
                    "anyOf": [
                        { "type": "string" },
                        { "type": "array", "items": { "type": "string" } }
                    ]
                },
                "output-raw": { "type": "boolean" },
                "args": { "$ref": "#/pSConfig/AnyJSON" }
            },
            "additionalProperties": false,
            "required": [ "script" ]
        },
        
        "ContextSpecification": {
            "type": "object",
            "properties": {
                "context": { "type": "string" },
                "data": { "$ref": "#/pSConfig/AnyJSON" },
                "_meta": { "$ref": "#/pSConfig/AnyJSON" }
            },
            "additionalProperties": false,
            "required": [ "context", "data" ]
        },
    
        "Duration": {
            "type": "string",
            "pattern": "^P(?:\\d+(?:\\.\\d+)?W)?(?:\\d+(?:\\.\\d+)?D)?(?:T(?:\\d+(?:\\.\\d+)?H)?(?:\\d+(?:\\.\\d+)?M)?(?:\\d+(?:\\.\\d+)?S)?)?$",
            "x-invalid-message": "'%s' is not a valid ISO 8601 duration."
        }
    }
}
EOF

    return from_json($raw_json);
}