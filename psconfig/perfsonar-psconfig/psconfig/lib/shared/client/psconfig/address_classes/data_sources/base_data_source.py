from ...base_node import BaseNode

class BaseDataSource(BaseNode):

    def __init__(self):
        self.type = None #override this

    def fetch(self, config):
        '''A function for accepting a config object and returning a HashRef of Address objects'''
        raise Exception('Override this')