from jsonschema import validate
from .archive_jq_transform import ArchiveJqTransform
from .schema import Schema
from .base_meta_node import BaseMetaNode

class Archive(BaseMetaNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def archiver(self, val=None):
        '''Gets/sets archiver'''

        return self._field('archiver', val)
    
    def archiver_data(self, val=None):
        '''Gets/sets data'''

        return self._field_anyobj('data', val)
    
    def archiver_data_param(self, field, val=None):
        '''Gets/sets data parameter at given field'''

        return self._field_anyobj_param('data', field, val)
    
    def transform(self, val=None):
        '''Gets/sets transform'''

        return self._field_class('transform', ArchiveJqTransform, val)
    
    def ttl(self, val=None):
        '''Gets/sets ttl'''

        return self._field_duration('ttl', val)

    def label(self, val=None):
        '''Gets/sets label'''

        return self._field('label', val)

    def schema(self, val=None):
        '''Gets/sets schema'''

        return self._field_cardinal('schema', val)

    def validate(self):
        '''Validates archive against JSON schema. Returns list of errors. Will be empty list if no
            errors.'''

        schema = Schema().psconfig_json_schema()
        #tweak it so we just look at ArchiveSpecification
        schema['required'] = ['archives']

        try:
            #plug-in archive in a way that will validate
            validate(instance={'archives':{'archive':self.data}}, schema=schema)
            return []
        except Exception as e:
            return [e]
