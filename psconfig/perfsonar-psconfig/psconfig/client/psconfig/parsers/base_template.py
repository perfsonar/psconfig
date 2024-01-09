'''BaseTemplate - A base library for filling in template variables in JSON'''
import json
import re
from ....utilities.jq import jq

class BaseTemplate():

    def __init__(self, **kwargs) -> None:
        self.jq_obj = kwargs.get('jq_obj', {})
        self.replace_quotes = kwargs.get('replace_quotes',True)
        self.error = ''

    def expand(self, obj = None):
        '''Parse the given object replace template variables with appropriate values. Returns copy of object with expanded values'''

        #make sure we have an object, otherwise return what was given
        if not obj:
            return obj
        
        #reset error
        self.error = ''

        #convert to string so we get copy and can do replace
        obj_str = json.dumps(obj)

        #handle quotes
        quote = ""
        if self.replace_quotes:
            quote = '"'
        
        #find the variables used
        template_var_map = {}

        for template_var in re.findall('{%\s+(.+?)\s+%\}', obj_str):
            template_var = template_var.strip()
            if template_var_map.get(template_var):
                continue
            expanded_val = self._expand_var(template_var)
            if expanded_val is None:
                self.error = "Unable to expand variable {}: {}".format(template_var, self.error)
                return
            template_var_map[template_var] = expanded_val

        #do the substitutions
        for template_var in template_var_map:
            #replace with expanded values
            if quote:
                template_var_str = "{}".format(template_var_map[template_var]) #make sure value is string
                obj_str = re.sub(r''+re.escape(quote)+r'{%\s+'+re.escape(template_var)+r'\s+%\}'+re.escape(quote), template_var_str, obj_str)
                #remove start/end quotes for next substitution
                template_var_map[template_var] = re.sub(r'^'+re.escape(quote), "", template_var_str)
                template_var_map[template_var] = re.sub(re.escape(quote)+r'$', "", template_var_str)

            #replace embedded variables
            obj_str = re.sub(r'{%\s+' + re.escape(template_var) +  r'\s+%\}', template_var_str, obj_str)

        # post processing
        ##bracket IPv6 URLs
        obj_str = self._bracket_ipv6_url(obj_str)

        #convert back to object
        try:
            expanded_obj = json.loads(obj_str)
        except Exception as e:
            self.error = "Unable to create valid JSON after expanding template, error: {}".format(e)
            return
        
        return expanded_obj
    
    def _expand_var(self, template_var):
        ##
        # There is probably a more generic way to do this, but starting here
        raise Exception("Override _expand_var")
    
    def _parse_jq(self, jq_str):
        jq_result = ""
        try:
            jq_str = jq_str.replace("\\\"", "\"")
            jq_result = jq(jq_str, self.jq_obj)
        except Exception as e:
            self.error = 'Error handling jq template variable: {}'.format(e)
            return
        # Force result to a string. If no match, just return empty string.
        return '"' + (jq_result if jq_result is not None else '') + '"'
    
    def _bracket_ipv6_url(self, json_str):
        IPv4 = "((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))"
        G = "[0-9a-fA-F]{1,4}"
        tail = ( ":",
	     "(:(" + G + ")?|" + IPv4 + ")",
             ":(" + IPv4 + "|" + G + "(:" + G + ")?|)",
             "(:" + IPv4 + "|:" + G + "(:" + IPv4 + "|(:" + G + "){0,2})|:)",
	     "((:" + G + "){0,2}(:" + IPv4 + "|(:" + G + "){1,2})|:)",
	     "((:" + G + "){0,3}(:" + IPv4 + "|(:" + G + "){1,2})|:)",
	     "((:" + G + "){0,4}(:" + IPv4 + "|(:" + G + "){1,2})|:)" )
        
        IPv6_re = G
        for _ in tail:
            IPv6_re = "{}:(".format(G)+IPv6_re+"|{})".format(_)

        IPv6_re = ":(:" + G + "){0,5}((:" + G + "){1,2}|:" + IPv4 + ")|" + IPv6_re
        IPv6_re = re.sub('\(', '(?:', IPv6_re)
        json_str = re.sub('(https?)://'+'('+IPv6_re+')', r'\g<1>://[\g<2>]', json_str)

        return json_str
