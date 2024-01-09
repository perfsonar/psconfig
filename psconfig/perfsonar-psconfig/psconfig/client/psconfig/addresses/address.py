from .base_labelled_address import BaseLabelledAddress
from .remote_address import RemoteAddress

class Address(BaseLabelledAddress):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    def host_ref(self, val=None):
        '''Gets/sets the host'''

        return self._field_name('host', val)
    
    def tags(self, val=None):
        '''Gets/sets the tags as a list'''
        return self._field('tags', val)

    def add_tag(self, val):
        '''Adds a tag to the list'''
        self._add_list_item('tags', val)
    
    def remote_addresses(self, val=None):
        '''Gets/sets remote-addresses as a dictionary of RemoteAddress objects'''
        return self._field_class_map('remote-addresses', RemoteAddress, val)
    
    def remote_address(self, field, val=None):
        '''Gets/sets remote-address specified by field'''
        return self._field_class_map_item('remote-addresses', field, RemoteAddress, val)
    
    def remote_address_names(self):
        '''Gets the list of keys found in remote-address dictionary'''
        return self._get_map_names('remote-addresses')
    
    def remove_remote_address(self, field):
        '''Removes the remote-address specified by field'''
        self._remove_map_item('remote-addresses', field)
        