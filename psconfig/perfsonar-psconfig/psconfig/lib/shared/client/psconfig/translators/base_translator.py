'''
Abstract class for config object that reads input and translates to another format
'''

from ..base_node import BaseNode

class BaseTranslator(BaseNode):

    def __init__(self):
        error = ''
    
    def name(self):
        ##
        # override this method with name of translator
        raise Exception('Override name method')
    
    def can_translate(self, raw_config, json_obj):

        ##
        # override this with method to look at given raw config and/ or json object and
        # determines if this class is able to translate
        raise Exception('Override can_translate method')
    
    def translate(self, raw_config, json_obj):
        ##
        # override this with method to translate given raw config or object to target format
        raise Exception('Override translate method')
