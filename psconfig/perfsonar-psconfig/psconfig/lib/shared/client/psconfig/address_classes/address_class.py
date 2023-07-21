from .filters.base_filter import BaseFilter
from .filters.filter_factory import FilterFactory
from .data_sources.data_source_factory import DataSourceFactory
from .data_sources.base_data_source import BaseDataSource
from ..base_meta_node import BaseMetaNode

class AddressClass(BaseMetaNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

    def data_source(self, val=None):
        '''Gets/sets data-source'''
        return self._field_class_factory('data-source',
        BaseDataSource, DataSourceFactory, val)

    def match_filter(self, val=None):
        '''Gets/sets match-filter'''
        return self._field_class_factory('match-filter',
        BaseFilter, FilterFactory, val)
    
    def exclude_filter(self, val=None):
        '''Gets/sets exclude-filter'''
        return self._field_class_factory('exclude-filter',
        BaseFilter, FilterFactory, val)

    def select(self, psconfig=None):
        '''selects all addresses in a given config objects that match this class. returns a
        list of dictionary with fields 'name', 'label', 'address'. '''

        #make sure we have a config
        if not psconfig:
            return (None, None)

        #make sure we have a data source
        data_source = self.data_source()
        if not data_source:
            return (None, None)
        
        #start off by selecting everything from data source
        ds_addrs = data_source.fetch(psconfig=psconfig)

        #prune down to only those that match and are not in exclude filter
        matching_nlas = []
        for ds_addr_name in ds_addrs:
            address = ds_addrs[ds_addr_name]
            #skip if gets filtered out
            if not self.matches(address, psconfig):
                continue
            #filters did not reject, include
            matching_nlas.append({'name': ds_addr_name, 'address': address})
        
        return matching_nlas
    
    def matches(self, address, psconfig):
        '''Return False or True depending on if given address and config object match this class'''
        
        #get filters
        match_filter = self.match_filter()
        exclude_filter = self.exclude_filter()

        #doesn't match match filter, exclude
        if match_filter and not match_filter.matches(address=address,psconfig=psconfig):
            return False
        
        #if does match exclude filter, exclude
        if exclude_filter and exclude_filter.matches(address=address, psconfig=psconfig):
            return False
        
        #filters did not reject, include
        return True
