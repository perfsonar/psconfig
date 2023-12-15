from jsonschema import validate
from ...utilities.jq import jq
from .base_node import BaseNode

class JQTransform(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.error = ''
    
    def script(self, val=None):
        '''Getter/ setter script for JQ script. Can be string or array of strings where each item in list
        is a line of the JQ script'''
        return self._field_list('script', val)
    
    def apply(self, json_obj):
        '''applies jqscript to the provided object'''
        #reset error
        self.error = ''

        #convert script to string
        script = self.script()
        if isinstance(script, list):
            script = "\n".join(script)

        #apply script
        transformed = None
        try:
            transformed = jq(script, json_obj)
        except Exception as e:
            self.error = e
            return
        
        return transformed

    def validate(self):
        '''validates this object against JSON schema. Returns any errors found. Valid if list in empty'''
        try:
            validator = validate(instance=self.data, schema=self._schema())
            return []
        except Exception as e:
            return [e]

    def _schema(self):
        raw_json = {
            "$schema": "http://json-schema.org/draft-04/schema#",
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
            }
        
        return raw_json


