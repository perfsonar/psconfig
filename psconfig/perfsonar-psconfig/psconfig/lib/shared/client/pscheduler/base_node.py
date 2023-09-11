#from urllib import response
from .api_filters import ApiFilters
from ..utils import Utils, build_err_msg

class BaseNode(object):

    def __init__(self, **kwargs):
        self.data = kwargs.get('data', {})
        self.url = kwargs.get('url')
        self.bind_address = kwargs.get('bind_address')
        self.uuid = kwargs.get('uuid')
        self.filters = kwargs.get('uuid', ApiFilters())
        self.error = None

    
    def json(self, formatting_params):
        if formatting_params is None: formatting_params = {}
        formatting_params['utf8'] = formatting_params.get('utf8', True)
        formatting_params['canonical'] = formatting_params.get('canonical', 0)
        return

    def _post_url(self):
        #return api url by default. override to build new url
        return self.url
    
    def _delete_url(self):
        if self.uuid is None:
            return
        delete_url = self._post_url()
        if not delete_url.endswith('/'):
            delete_url += '/'
        delete_url += self.uuid

        return delete_url
    
    def _post(self, data):

        response = Utils().send_http_request(
            connection_type='POST',
            url=self._post_url(),
            timeout=self.filters.timeout,
            ca_certificate_file=self.filters.ca_certificate_file,
            ca_certificate_path=self.filters.ca_certificate_path,
            verify_hostname=self.filters.verify_hostname,
            local_address=self.bind_address,
            data=data
        )
    
        if not response.ok:
            self.error = build_err_msg(http_response=response)
            return
        
        return response.json()
    
    
    def _put(self, data):
        response = Utils().send_http_request(
            connection_type='PUT',
            url=self._post_url(),
            timeout=self.filters.timeout,
            ca_certificate_file=self.filters.ca_certificate_file,
            ca_certificate_path=self.filters.ca_certificate_path,
            verify_hostname=self.filters.verify_hostname,
            local_address=self.bind_address,
            data=data
        )

        if not response.ok:
            self.error = build_err_msg(http_response=response)
            return
        
        return response.json()
    
    
    def _delete(self):
        response = Utils().send_http_request(
            connection_type='DELETE',
            url=self._delete_url(),
            timeout=self.filters.timeout,
            ca_certificate_file=self.filters.ca_certificate_file,
            ca_certificate_path=self.filters.ca_certificate_file,
            verify_hostname=self.filters.verify_hostname,
            local_address=self.bind_address
        )

        if not response.ok:
            self.error = build_err_msg(http_response=response)
            return
        
        return response.json()

    
    def _has_field(self, parent, field):
        if isinstance(parent, dict):
            return 'field' in parent
        else:
            raise Exception('parent is not a dictionary')
    
    def _init_field(self, parent, field):
        if isinstance(parent, dict):
            parent[field] = parent.get(field, {})
        else:
            raise Exception('parent is not dictionary')
    
