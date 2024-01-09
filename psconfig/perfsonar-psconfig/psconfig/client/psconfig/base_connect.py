'''
Abstract class for reading in a JSON from http or file
'''
from ..utils import build_err_msg, Utils
from .api_filters import ApiFilters
import re
import os
import json
from urllib.parse import urlparse
import logging

class BaseConnect(object):

    def __init__(self, **kwargs):
        self.filters = kwargs.get('filters',ApiFilters())
        self.error = ''
        self.bind_address = kwargs.get('bind_address')
        self.save_filename = kwargs.get('save_filename')
        self.url = kwargs.get('url')
        self.logger = logging.getLogger(__name__)

    def config_obj(self):
        ##
        # override this with the type of config object you want returned

        raise Exception ('Override config_obj')

    def needs_translation(self, json_obj):
        ##
        # Abstract method that returns true if given JSON needs to be translated, false otherwise.
        # Default behavior is to always return False, Should be overridden by subclasses

        return False

    def translators(self):
        ##
        # Abstract method that returns list of BaseTranslator
        # objects that can be used to convert input JSON to format supported by implementing client

        return []

    def _merge_configs(self, psconfig1, psconfig2):

        #if no configs then nothing to do
        if not (psconfig1 and psconfig2):
            return
        
        #merge psconfig2 and psconfig1
        fields = ['addresses', 'address-classes', 'archives', \
            'contexts', 'groups', 'hosts', 'schedules', 'subtasks', \
                'tasks', 'tests']
        
        for field in fields:
            #if no key, then continue
            if not psconfig2.data.get(field):
                continue

            #init psconfig1 if needed
            psconfig1.data[field] = psconfig1.data.get(field, {})

            #iterate through psconfig2 but do not overwrite any fields that already exist
            for psconfig2_key in psconfig2.data.get(field).keys():
                if psconfig1.data[field].get(psconfig2_key, None):
                    if self.logger:
                        self.logger.warn("PSConfig merge: Skipping {} field's {} because it already exists".format(field, psconfig2_key)) 
                else:
                    psconfig1.data[field][psconfig2_key] = psconfig2.data[field][psconfig2_key]


    def _config_from_file(self):

        #remove prefix
        filename = self.url
        filename.strip()
        filename = re.sub(r'^file://', '', filename)

        psconfig = None

        try:
            with open(filename, 'r') as file:
                raw_config = file.read()
        except Exception as e:
            self.error = 'Can\'t open {} and load json. Error: {}'.format(filename, e)
            return
        
        psconfig = self._raw_config_to_psconfig(raw_config)

        if not psconfig:
            self.error = "No config object found {}".format(filename)
            return

        return psconfig
    
    def _config_from_http(self):

        psconfig = None
        try:
            result = Utils().send_http_request(
                connection_type = 'GET',
                url = self.url,
                timeout = self.filters.timeout,
                ca_certificate_file = self.filters.ca_certificate_file,
                local_address = self.bind_address 
            )
        
            response = result['response']
            if result['exception']:
                self.error = result['exception']
                return

            if not response.ok:
                msg = build_err_msg(http_response=response)
                self.error = msg
                return
            
            psconfig = self._raw_config_to_psconfig(response.text)
            if not psconfig:
                self.error = "No task objects returned"
                return
        except Exception as e:
            self.error = e
            return
        
        return psconfig


    def _raw_config_to_psconfig(self, raw_config):
        #check if translation needed
        translator_error = ''
        psconfig = None
        json_error = ""
        json_obj = None

        try:
            json_obj = json.loads(raw_config)
        except Exception as e:
            json_error = e

        if (not json_obj) or self.needs_translation(json_obj):
            #try to find a translator that works
            for translator in self.translators():
                if translator.can_translate(raw_config, json_obj):
                    psconfig = translator.translate(raw_config, json_obj)
                    translator_error = translator.error
                    if psconfig: #if translation fails, try others
                        break
        else:
            #build psconfig directly
            psconfig = self.config_obj()
            psconfig.data = json_obj

        #we should have a json object now, if not its an error
        if not psconfig:
            if json_error:
                raise Exception(json_error)
            elif translator_error:
                raise Exception(translator_error)

        # return None if no error
        return psconfig


    def get_config(self):
        '''
        loads configuration from file or url and returns config object
        '''

        #Make sure we have a url
        if not self.url:
            self.error = 'No url defined.'
            return

        u = urlparse(self.url)
        
        #retrieved based on url type
        if u.scheme=='' or u.scheme=='file':
            psconfig = self._config_from_file()
            return psconfig
        #check for both http and https (for possible errors)
        elif u.scheme=='http' or u.scheme=='https':
            psconfig = self._config_from_http()
            return psconfig
        else:
            self.error = 'Unrecognized url type ( {} ). Must start with http://, file:// or be a file path'.format(self.url)
            return
    

    def save_config(self, psconfig, formatting_params=None, chmod=None):
        '''
        Saves configuration file to disk
        '''

        if not formatting_params:
            formatting_params = {}
        filename = self.save_filename
        filename = filename.strip()
        filename = re.sub(r'^file://', '', filename)

        if not filename:
            self.error = 'No save_filename set'
            return

        try:
            psconfig_canonical = psconfig.to_json(formatting_params=formatting_params)
            with open(filename, 'w') as file:
                    file.write(psconfig_canonical)
                    if chmod:
                        os.fchmod(file.fileno(), chmod)
        except Exception as e:
            self.error = e
        
    def expand_config(self, psconfig1):
        '''
        Expands includes in config
        '''
        #check if can handle includes
        #if not psconfig1.get('includes'):
        #    self.error = 'Configuration does not support includes'
        #    return
        
        #exit if no psconfig
        includes = psconfig1.includes()
        if not (psconfig1 and includes):
            return
        
        #iterate through includes and expand
        self._clear_error()
        errors = []

        for include_url in includes:
            psconfig2_client = self.__class__(url=include_url)
            psconfig2 = psconfig2_client.get_config()
            if psconfig2_client.error:
                #if error getting an include, proceed with the rest
                errors.append("Error including {}: {}".format(include_url, psconfig2_client.error))
                continue
            #do the merge
            self._merge_configs(psconfig1, psconfig2)
        
        if len(errors) > 0:
            self.error = '\n'.join(errors)
    
    def _clear_error(self):
        self.error = ''
