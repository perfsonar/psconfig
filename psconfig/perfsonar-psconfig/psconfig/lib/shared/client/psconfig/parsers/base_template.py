'''BaseTemplate - A base library for filling in template variables in JSON'''

class BaseTemplate():

    def __init__(self) -> None:
        self.jq_obj = {}
        self.replace_quotes = True
        self.error = ''

    def expand(self, obj):
        '''Parse the given object replace template variables with appropriate values. Returns copy of object with expanded values'''

        #make sure we have an object, otherwise return what was given
        if not obj:
            return obj
        
        #reset error
        self.error = ''

        #convert to string so we get copy and can do replace

        #handle quotes
        quote = ""
        if self.replace_quotes:
            quote = '"'
        
        