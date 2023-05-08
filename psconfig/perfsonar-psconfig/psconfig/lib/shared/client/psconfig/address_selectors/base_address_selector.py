from ..base_node import BaseNode

class BaseAddressSelector(BaseNode):

    def __init__(self):
        self.type = None #override this

    def disabled(self, val=None):
        '''Gets/sets disabled'''
        return self._field_bool('disabled', val)
    
    def select(self, config):
        '''
        A function for accepting a config and returning a list containing maps with:
            # 1. "label" => The label to use when selecting an address. None if unable to determine
            # 2. "name" => The name of the address
            # 3. "address" => A map of matching addresses where the key is the name and the value is an Address object
        '''
        raise Exception('Override this')
        