from .address_label import AddressLabel
from .base_address import BaseAddress

class BaseLabelledAddress(BaseAddress):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    def labels(self, val=None):
        '''Gets/sets labels as dictionary of AddressLabel objects'''
        return self._field_class_map('labels', AddressLabel, val)
    
    def label(self, field, val=None):
        '''Gets/sets label specified by field'''
        return self._field_class_map_item('labels', field, AddressLabel, val)
    
    def label_names(self):
        '''Gets the keys in the label dictionary'''
        return self._get_map_names("labels")
    
    def remove_label(self, field):
        '''Removes label specified by field'''
        self._remove_map_item('labels', field)
        