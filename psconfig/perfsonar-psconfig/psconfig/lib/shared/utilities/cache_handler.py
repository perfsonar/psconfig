import json
import datetime

class CacheHandler():
    
    def __init__(self, file_path=None, expires_in=None) -> None:
        self.data = {}
        self.file_path = file_path
        self.expires_in = expires_in
    
    def expires_timestamp(self, expires_in):
        return datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)
        
    def set(self, key, value, expires_in=None):
        expires_in = expires_in if expires_in else self.expires_in
        if expires_in:
            expires_in_timestamp = datetime.datetime.utcnow() + datetime.timedelta(seconds=expires_in)
        else:
            #does not expire
            expires_in_timestamp = None
        self.data[key] = {'value': value,\
            'expires_in': expires_in_timestamp}
        
        #overwrite the file with data everytime a value is set
        with open(self.file_path, 'w') as file:
            json.dump(self.data, file)
    
    def get(self, key):
        if self.get(key):
            return self.get(key).get('value')
        else:
            return
    
    def get_expires_at(self, key):
        if self.get(key):
            return self.get(key).get('expires_in')
        else:
            return
    
    def purge(self):
        current_timestamp = datetime.datetime.utcnow()
        for key in self.data:
            #expiry can be None as well
            expiry = self.data[key]['expires_in']
            if expiry and current_timestamp > expiry:
                del self.data[key]
        
        #overwrite the file with remaining data
        with open(self.file_path, 'w') as file:
            json.dump(self.data, file)

    def read_file(self):
        with open(self.file_path, 'r') as file:
            self.data = json.load(self.data, file)

