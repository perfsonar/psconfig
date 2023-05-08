
from base64 import b64encode
from hashlib import md5
import json

class Archive(object):

    def __init__(self, **kwargs) -> None:
        self.name = kwargs.get('name')
        self.ttl = kwargs.get('ttl')
        self.transform = kwargs.get('transform', {})
        self.data = kwargs.get('data', {})

    def data_param(self, field, val=None):
        if field is None:
            return
        if val is not None:
            self.data[field] = val
        return self.data.get(field, None)
    
    def checksum(self, include_private=False):
        #calculates checksum for comparing tasks ignoring stuff like UUID and lead url
        #disable canonical since we do not care at the moment

        archive = {'name': self.name, 'ttl': self.ttl, 'data': {}}
        #clear out private fields that won't get displayed by remote tasks
        for datum in self.data.keys():
            if datum.startswith('_') and not include_private:
                archive['data'][datum] = ''
            else:
                archive['data'][datum] = self.data[datum]
            
        #canonical should keep it consistent by sorting keys
        archive_canonical = json.dumps(archive, sort_keys=True, separators=(',',':')).encode('utf-8')
        return b64encode(md5(archive_canonical).digest()).decode().rstrip('=')
        
