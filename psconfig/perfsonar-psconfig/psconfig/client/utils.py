from requests import Request, Session
import json
from urllib.parse import urlparse, urlunparse
import urllib3
from ipaddress import ip_address
import re


class Utils(object):
    def __init__(self):
        #default interface without bind address (if same object needs to be used with multiple local bind addresses)
        self.urllib_create_connection = urllib3.util.connection.create_connection ######## check if this is global and causes issues with threading
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

    def send_http_request(self, **kwargs):
        url = kwargs.get('url')
#        param_count = 0
        params = {}

        if kwargs.get('get_params'):
            for key in kwargs.get('get_params').keys():
                params[key] = json.dumps(kwargs['get_params'][key])

#        if kwargs.get('get_params'):
#            if len(kwargs.get('get_params')):
#                url += '?'
#                for key in kwargs.get('get_params').keys():
#                    if param_count > 0:
#                        url += '&'
#                    url += '{}='.format(key) + kwargs['get_params'][key]
#                    param_count += 1

        if kwargs.get('timeout'):
            timeout = kwargs['timeout']
        else:
            timeout = 120

        #set default redirects to something greater than 0
        #max_redirects = 3
        #if kwargs.get('max_redirects'):
        #    max_redirects = kwargs['max_redirects']

        #lookup address if map provided
        if kwargs.get('address_map'):
            url_obj = urlparse(url)
            host = url_obj.hostname
            if isinstance(kwargs.get('address_map'), dict):
                if kwargs.get('address_map').get(host):
                    url_obj = url_obj._replace(netloc=url_obj.netloc.replace(url_obj.hostname, kwargs.get('address_map').get(host)))
                    url = urlunparse(url_obj)
        
        #determine where to bind locally, if needed ############check this!!
        bind_address = ''
        if isinstance(kwargs.get('bind_map'), dict):
            url_obj = urlparse(url)
            host = url_obj.hostname
            if kwargs.get('bind_map').get(host):
                bind_address = kwargs.get('bind_map').get(host)
                

            elif kwargs.get('bind_map').get('_default'):
                if not (ip_address(host).is_loopback or host.startswith('localhost')):
                        bind_address = kwargs.get('bind_map').get('_default')
            
        #what if the host is loopback and passed local_address is loopback? valid case? then dont check for loopback host
        if (not bind_address) and kwargs.get('local_address'):
            bind_address = kwargs['local_address']
        
        if bind_address:
            conn = urllib3.util.connection.create_connection

            def set_src_addr(address, timeout, *args, **kwargs):
                source_address = (bind_address, 0) ########should configure port?
                return conn(address, timeout=timeout, source_address=source_address)
            urllib3.util.connection.create_connection = set_src_addr
            
        else:
            urllib3.util.connection.create_connection = self.urllib_create_connection
        
            
        #check for ca cert verification examples
        ##### handle errors max retires and max redirects
        with Session() as s:
            req = Request(kwargs.get('connection_type'),\
                url,
                params=params,
                json=kwargs.get('data'),
                headers=kwargs.get('headers'),
                )
            prepped = req.prepare()
            try:
                resp = s.send(prepped,\
                    verify=kwargs.get('ca_certificate_file', False),
                    timeout=timeout,
                    allow_redirects=kwargs.get('allow_redirects', True)
                    )
                
                return {'response': resp, 'exception': None}
            except Exception as e:
                return {'response': None, 'exception': e}
    
def build_err_msg(http_response):
    errmsg = ''
    errmsg += '{}.'.format(http_response.reason)
    errmsg += ' Status Code: {}'.format(http_response.status_code)
    errmsg += http_response.text.strip()

    return errmsg

######verify the regex and multiple uuids in url
def extract_url_uuid(url):
    url = url.strip()
    url = url.strip('"')
    pattern = re.compile('([0-9a-zA-Z\-]+)$')
    uuids  = pattern.findall(url)
    if len(uuids) > 0:
        task_uuid = uuids[0]
        return task_uuid
    return

