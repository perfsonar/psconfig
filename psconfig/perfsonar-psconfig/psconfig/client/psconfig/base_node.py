import json
from hashlib import md5
from base64 import b64encode
from ipaddress import IPv4Network, IPv6Network, ip_network, ip_address, IPv6Address, IPv4Address
import copy
import re
import urllib
#from w3lib.url import canonicalize_url
import isodate
import datetime

class BaseNode(object):

    def __init__(self, **kwargs):
        self.data = kwargs.get('data', {})
        self.validation_error = ''
        self.map_name = ''
    
    def checksum(self):
        '''
        Calculates checksum for object that can be used in comparisons
        '''

        data_copy = copy.deepcopy(self.data)
        #keep consistent by sorting keys
        data_copy_canonical = json.dumps(data_copy, sort_keys=True, separators=(',',':')).encode('utf-8')
        return b64encode(md5(data_copy_canonical).digest()).decode().rstrip('=')
    
    def to_json(self, formatting_params=None):
        '''Converts object to JSON string. Accepts option dictionary with JSON formatting options.'''
        if not formatting_params:
            formatting_params = {}
        
        formatting_params['utf8'] = formatting_params.get('utf8', True)
        formatting_params['canonical'] = formatting_params.get('canonical', False)
        indentation = formatting_params.get('pretty')
        if not indentation:
            indentation = None
        else:
            indentation = 2
        
        if formatting_params.get('canonical'):
            psconfig_canonical = json.dumps(self.data, sort_keys=True, separators=(',',':'), indent=indentation)
        else:
            psconfig_canonical = json.dumps(self.data, indent=indentation)
        
        # defaults to utf8
        #if formatting_params.get('utf8'):
        #    psconfig_canonical = psconfig_canonical.encode('utf-8')
        
        return psconfig_canonical

    def remove(self, field):
        '''
        Removes item from data hash with given key
        '''

        self._remove_map(self._normalize_key(field))

    
    def _normalize_key(self, field):
        field = re.sub(r'_', '-', field) #normalize to json key in case used perl style key
        return field
    
    def remove_list_item(self, field, index):
        '''
        removes item from list in data with given key and index
        '''

        field = self._normalize_key(field)

        if not isinstance(index, int):
            return
        
        if not (isinstance(self.data.get(field), list) and len(self.data.get(field))>index):
            return
        
        del self.data[field][index]
    
    def _add_list_item(self, field, val=None):
        if val is None:
            return
        
        if not self.data.get(field):
            self.data[field] = []
        
        self.data[field].append(val)

    def _field(self, field, val=None):
        if val is not None:
            self.data[field] = val
        
        return self.data.get(field)
    

    def _field_list(self, field, val=None):

        #handle case where scalar is provided
        if val is not None:
            if isinstance(val, list):
                self.data[field] = val
            
            else:
                self.data[field] = [val]
        
        if (field in self.data) and (not isinstance(self.data.get(field), list)):
            return [self.data[field]]
        
        return self.data.get(field)
    
    def _field_map(self, field, val=None):
        if val is not None:
            if not isinstance(val, dict):
                self.validation_error = 'Unable to set {}. Value must be a dictionary.'.format(field)
                return
            tmp_map = {}
            for v in val:
                tmp_map[v] = val[v].data
            self.data[field] = tmp_map
        return self.data.get(field)
    
    def _field_map_item(self, field, param, val=None):
        if not (field and param):
            return

        if val is not None:
            self._init_field(self.data, field)
            self.data[field][param] = val
        
        if not self._has_field(self.data, field):
            return
        
        if not self._has_field(self.data[field], param):
            return
        
        return self.data[field][param]
    
    def _field_class(self, field, field_class, val=None):
        if not (field and field_class):
            return
        
        if val is not None:
            if self._validate_class(field, field_class, val):
                self.data[field] = val.data
            else:
                return
        
        if not self.data.get(field):
            return
        
        return field_class(data=self.data.get(field))
    
    def _field_class_list(self, field, field_class, val=None):
        if val is not None:
            if not isinstance(val, list):
                self.validation_error = '{} must be a list'.format(field)
                return
            tmp = []
            for v in val:
                if self._validate_class(field, field_class, v):
                    tmp.append(v.data)
                else:
                    return
            self.data[field] = tmp
        
        tmp_objs = []

        for data in self.data.get(field, []):
            tmp_objs.append(field_class(data=data))
        
        return tmp_objs
    
    def _field_class_list_item(self, field, index, field_class, val=None):

        if not (field and self.data.get(field) and \
            isinstance(self.data.get(field), list) and \
                (index is not None) and len(self.data[field]) > index):
                return
        
        if val is not None:
            if self._validate_class(field, field_class, val):
                self.data[field][index] = val.data
            else:
                return
        
        return field_class(data=self.data[field][index])
    
    def _field_class_map(self, field, field_class, val=None):
        if val is not None:
            if not isinstance(val, dict):
                self.validation_error = 'Unable to set {}. value must be a dictionary'.fomat(field)
                return
            tmp_map = {}
            for v in val:
                if self._validate_class(field, field_class, val[v]):
                    tmp_map[v] = val[v].data
                else:
                    return
            
            self.data[field] = tmp_map
        
        tmp_obj_map = {}
        
        if self.data.get(field):
            for field_key in self.data.get(field):
                tmp_obj = self._field_class_map_item(field, field_key, field_class)
                tmp_obj_map[field_key] = tmp_obj

        return tmp_obj_map
    
    def _field_class_map_item(self, field, param, field_class, val=None):
        if not (field and param and field_class):
            return
        
        if val is not None:
            if self._validate_class(field, field_class, val):
                self._init_field(self.data, field)
                self.data[field][param] = val.data
            else:
                return
            
        if not self._has_field(self.data, field):
            return
        
        if not self._has_field(self.data[field], param):
            return
        
        o = field_class(data=self.data[field][param])
        o.map_name = param
        return o

    def _field_class_factory(self, field, base_class, factory_class, val=None):
        if not (field and base_class and factory_class):
            return
        
        if val is not None:
            if self._validate_class(field, base_class, val):
                self.data[field] = val.data
            else:
                return
        factory = factory_class()
        return factory.build(self.data.get(field))
    
    def _field_class_factory_list(self, field, base_class, factory_class, val=None):
        if val is not None:
            if not isinstance(val, list):
                self.validation_error = '{} must be an array'.format(field)
                return
            tmp = []

            for v in val:
                if self._validate_class(field, base_class, v):
                    tmp.append(v.data)
                else:
                    return
            self.data[field] = tmp

        tmp_objs = []
        factory = factory_class()
        for data in self.data.get(field):
            tmp_objs.append(factory.build(data))
        
        return tmp_objs

    def _field_class_factory_list_item(self, field, index, base_class, factory_class, val=None):
        if not (field and self.data.get(field) and \
            isinstance(self.data.get(field), list) and 
            (index is not None) and 
            len(self.data.get(field))  > index):
            return

        if val is not None:
            if self._validate_class(field, base_class, val):
                self.data[field][index] = val.data
            else:
                return
        
        factory = factory_class()
        return factory.build(self.data[field][index])
    
    
    def _field_class_factory_map(self, field, base_class, factory_class, val=None):
        if val is not None:
            if not isinstance(val, dict):
                self.validation_error = 'Unable to set {}. Value must be a dictionary'.format(field)
                return
            
            tmp_map = {}
            for v in val:
                if self._validate_class(field, base_class, val[v]):
                    tmp_map[v] = val[v].data
                else:
                    return
            self.data[field] = tmp_map
        
        tmp_obj_map = {}

        for field_key in self.data.get(field):
            tmp_obj = self._field_class_factory_map_item(field, field_key, base_class, factory_class)
            tmp_obj_map[field_key] = tmp_obj
        
        return tmp_obj_map
    
    def _field_class_factory_map_item(self, field, param, base_class, factory_class, val=None):
        if not (field and param and base_class and factory_class):
            return None
        
        if val is not None:
            if (self._validate_class(field, base_class, val)):
                self._init_field(self.data, field)
                self.data[field][param] = val.data
            else:
                return

        if not self._has_field(self.data, field):
            return
        
        if not self._has_field(self.data[field], param):
            return
        
        factory = factory_class()
        return factory.build(self.data[field][param])
        

    def _add_field_class(self, field, field_class, val=None):
        if not (field and field_class and val):
            return
        
        if not (self.data.get(field)):
            self.data[field] = []

        if self._validate_class(field, field_class, val):
            self.data[field].append(val.data)
        
        else:
            return
        
    

    def _field_refs(self, field, val=None):
        if val is not None:
            if not isinstance(val, list):
                self.validation_error = '{} must be a list'.format(field)
                return
            
            for v in val:
                if not self._validate_name(v):
                    self.validation_error = '{} cannot be set to {}. Must contain only letters, numbers, periods, underscores, hyphens and colons.'.format(field, val)
                    return
            
            self.data[field] = val
        
        return self.data.get(field)

    
    def _add_field_ref(self, field, val=None):
        if not val:
            return
        
        if not self._validate_name(val):
            self.validation_error = '{} cannot be set to {}. Must contain only letters, numbers, periods, underscores, hyphens and colons.'.format(field, val)
            return
        
        if not self.data.get(field):
            self.data[field] = []
        
        self.data[field].append(val)
    
    def _field_anyobj(self, field, val=None):
        if val is not None:
            if isinstance(val, dict):
                self.data[field] = val
            else:
                self.validation_error = 'Unable to set {}. Value must be a dictionary'.format(field)
                return
        return self.data.get(field)
    
    def _field_anyobj_param(self, field, param, val=None):
        if not (field and param):
            return
        
        if val is not None:
            self._init_field(self.data, field)
            self.data[field][param] = val
        
        if not self._has_field(self.data, field):
            return
        
        return self.data.get(field, {}).get(param)

    def _field_enum(self, field, val, valid):
        if val is not None:
            if valid:
                if val in valid:
                    self.data[field] = val
                else:
                    self.validation_error = '{} cannot be set to {}. Must be one of '.format(field, val) + ','.join(valid.keys())
                    return
            else:
                self.data[field] = val
        
        return self.data.get(field)
    
    def _field_name(self, field, val=None):
        if val is not None:
            if self._validate_name(val):
                self.data[field] = val
            else:
                self.validation_error = '{} cannot be set to {}. Must contain only letters, numbers, periods, underscores, hyphens and colons.'.format(field, val)
                return
        return self.data.get(field)
    
    def _field_bool(self, field, val=None):
        if val is not None:
            if val is True:
                self.data[field] = True
            elif val is False:
                self.data[field] = False
            else: #to differentiate False and None
                self.validation_error = '{} cannot be set to {}. It is a boolean and must be set to False and True.'.format(field, val)
                return
        if self.data.get(field):
            return True #returns None as well
        else:
            return False
    
    def _field_bool_default_true(self, field, val=None):
        #if not setting the value and the existing field value is None, default to true
        if val is None and self.data.get(field, None) is None:
            return True
        #otherwise, do the normal boolean operation
        return self._field_bool(field, val)

    def _field_ipversion(self, field, val=None):
        if val is not None:
            if val==4 or val==6:
                self.data[field] = val
            else:
                self.validation_error = '{} cannot be set to {}. Allowed IP versions are 4 and 6.'.format(field, val)
                return
        return self.data.get(field)
    
    def _field_ipcidr(self, field, val):
        if val is not None:
            try:
                if type(ip_network(val, strict=False)) is IPv4Network:
                    self.data[field] = val
                elif type(ip_network(val, strict=False)) is IPv6Network:
                    self.data[field] = val
                else:
                    self.validation_error = 'field cannot be set to val. Must be a valid IPv4 or IPv6 CIDR.'
                    return
            except Exception as e:
                self.validation_error = e
        return self.data.get(field)
    
    def _field_host(self, field, val=None):
        if val is not None:
            if self._validate_host(val):
                self.data[field] = val
            else:
                self.validation_error = '{} cannnot be set to val. Must be a valid IPv4 or IPv6 or hostname'.format(field)
                return
        return self.data.get(field)
    
    def _field_host_list(self, field, val=None):
        if val is not None:
            if not isinstance(val, list):
                self.validation_error = '{} must be a list'.format(field)
                return
            for v in val:
                if not self._validate_host(v):
                    self.validation_error = '{} cannot be set to {}. Must be valid IPv4, IPv6 or hostname.'.format(field, v)
                    return
            self.data[field] = val
        
        return self.data.get(field)

    def _field_host_list_item(self, field, index, val=None):
        if not (field and self.data.get(field) and \
            isinstance(self.data.get(field), list) and 
            (index is not None) and len(self.data.get(field))> index):
            return
        
        if val is not None:
            if self._validate_host(val):
                self.data[field][index] = val
            else:
                return
        
        return self.data[field][index]

    def _add_field_host(self, field, val=None):
        if not val:
            return
        
        if self._validate_host(val):
            self.validation_error = '{} cannot be set to {}. Must be valid IPv4, IPv6 or hostname'.format(field, val)
            return
        
        if not self.data.get(field):
            self.data[field] = []
        
        self.data[field].append(val)

    def _field_cardinal(self, field, val=None):
        if val is not None:
            if int(val) > 0:
                self.data[field] = int(val)
            else:
                self.validation_error = '{} cannot be set to {}. Must be an integer greater than 0.'.format(field, val)
                return
        return self.data.get(field)
    
    def _field_int(self, field, val=None):
        if val is not None:
            self.data[field] = int(val)
        return self.data.get(field)
    
    def _field_intzero(self, field, val=None):
        if val is not None:
            if int(val) >= 0:
                self.data[field] = int(val)
            else:
                self.validation_error = '{} cannot be set to {}. Must be an integer greater than or equal to 0'.format(field, val)
                return
        
        return self.data.get(field)
    
    def _field_numbernull(self, field, val=None, set_null=False):
        if set_null:
            self.data[field] = None
        elif val is not None:
            try:
                self.data[field] = float(val)
            except:
                self.validation_error = '{} cannot be set to {}. Must evaluate to float'.format(field, val)
                return
        
        return self.data.get(field)
    
    def _field_probability(self, field, val=None):
        if val is not None:
            if (val >= 0.0 and val <= 1.0):
                self.data[field] = val + 0.0
            else:
                self.validation_error = '{} cannot be set to {}. Must be a number between 0 and 1 (inclusive)'.format(field, val)
                return
        return self.data.get(field)

    def _field_duration(self, field, val=None):
        if val is not None:
            if self._validate_duration(val):
                self.data[field] = val
            else:
                self.validation_error = '{} cannot be set to {}. Must be IS8601 duration'.format(field, val)
                return
        return self.data.get(field)

    def _field_url(self, field, val=None, allowed_scheme_map=None):
        if not allowed_scheme_map:
            allowed_scheme_map = {'http': True, 'https': True, 'file': True}
        
        if val is not None:
            #allowed URLs or absolute file paths
            uri = urllib.parse.urlsplit(val)
            if uri.scheme and not allowed_scheme_map.get(uri.scheme):
                prefixes = ','.join(allowed_scheme_map.keys())
                self.validation_error = '{} cannot be set to {}. URL must start with {}'.format(field, val, prefixes)
                return
            elif not uri.scheme and not val.startswith('/'):
                #not an absolute file, then error
                self.validation_error = '{} cannot be set to {}. Must be valid URL or absolute filename'.format(field, val)
                return
            if uri.netloc:
                #file:// does not do host-port, so need to make sure it can
                if not self._validate_urlhostport(uri.netloc):
                    self.validation_error = '{} field cannot be set to {}. Cannot determine valid URL host and port.'.format(field, val)
                    return
            
            self.data[field] = urllib.parse.urlunsplit(uri) #canonicalize_url(urllib.parse.urlunsplit(uri))
        
        return self.data.get(field)

    
    def _field_urlhostport(self, field, val=None):
        if val is not None:
            if self._validate_urlhostport(val):
                self.data[field] = val
            else:
                self.validation_error = '{} cannot be set to {}. Must be valid host/port combo or RFC2732 value.'.format(field, val)
                return
        return self.data.get(field)

    def _field_timestampabsrel(self, field, val=None):
        if val is not None:
            if self._validate_duration(val):
                self.data[field] = val
            elif self._validate_datetime(val):
                self.data[field] = val
            #elif self._validate_date(val):
            #    self.data[field] = val
            #elif self._validate_time(val):
            #   self.data[field] = val
            else:
                self.validation_error = '{} cannot be set to {}. Must be valid IS8061 duration or timestamp'.format(field, val)
                return

        return self.data.get(field)
    
    def _validate_class(self, field, field_class, val=None):
        if val:
            try:
                if not isinstance(val, field_class):
                    raise Exception("Value of {} is an object but must be of type {}".format(field, field_class))
            except Exception as e:
                self.validation_error = 'Error validating {} is of type {}: {}'.format(field, field_class, e)
                return False
            return True
        return False
    
    def _validate_datetime(self, val=None):
        if val:
            try:
                date_time = isodate.parse_datetime(val)
                return True
            except Exception:
                return False
        return False
    
    def _validate_date(self, val=None):
        if val:
            try:
                date_time = isodate.parse_date(val)
                return True
            except Exception:
                return False
        return False
    
    def _validate_time(self, val=None):
        if val:
            try:
                date_time = isodate.parse_time(val)
                return True
            except Exception:
                return False
        return False

    def _validate_duration(self, val=None):
        if val:
            try:
                duration = isodate.parse_duration(val)
            except isodate.isoerror.ISO8601Error:
                return False
            if not isinstance(duration, datetime.timedelta):
                #does not support months and years
                return False
            return True
        return False
    
    def _validate_name(self, val=None):
        # Must contain only letters, numbers, periods, underscores, hyphens and colons
        if val:
            reg = re.compile(r'^[a-zA-Z0-9:._\-]+$')
            return bool(reg.fullmatch(val))
        return False
    
    def _is_hostname(self, name=None):
        if name:
            
            if len(name) > 253:
                return False
            labels = name.split('.')

            #top level domain should not be all numeric
            if len(labels) > 0:
                if labels[-1].isdigit():
                    return False

            #Allowed characters and length
            reg = re.compile(r'^[a-zA-Z0-9\-]{1,63}$')
            
            # Does not allow '_' in the hostname!
            for label in labels:
                #label cannot end with '-'
                if label.endswith('-') or (not reg.fullmatch(label)):
                    return False
            return True
        return False

    def _validate_host(self, val=None):
        if val:
            # remove leading and trailing brackets for ipv6
            val = re.sub('^\[','', val)
            val = re.sub('\]$','', val)

            try:
                if type(ip_address(val)) is IPv6Address or type(ip_address(val)) is IPv4Address:
                    return True
            except Exception as e:
                return self._is_hostname(val)
        return False
    
    def _validate_urlhostport(self, val=None):
        #ipv4 = re.compile(r'^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])(:[0-9]+)?$') ### does not validate the limits?
        #ipv6 = re.compile(r'^\[(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))\](:[0-9]+)?$')
        if val:
            host, port = urllib.parse.splitport(val)
            if port:
                try:
                    port = int(port)
                    if port > 65535 or port < 0:
                        return False
                except Exception:
                    return False
            if host:
                return self._validate_host(host)
        return False
    
    def _has_field(self, parent, field):
        return parent.get(field)

    def _init_field(self, parent, field):
        if not self._has_field(parent, field):
            parent[field] = {}
    
    def _get_map_names(self, field):
        if not self._has_field(self.data, field):
            return []
        
        names = list(self.data[field].keys())
        return names
    
    def _remove_map_item(self, parent_field, field):
        if not (self.data.get(parent_field) and self.data.get(parent_field).get(field)):
            return
        
        del self.data[parent_field][field]
    
    def _remove_map(self, field):
        if not self.data.get(field):
            return
        
        del self.data[field]

