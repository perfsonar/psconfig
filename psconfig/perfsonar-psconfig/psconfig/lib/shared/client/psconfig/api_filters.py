

class ApiFilters(object):
    def __init__(self, **kwargs):
        self.timeout = kwargs.get('timeout', 60)
        self.ca_certificate_file = kwargs.get('ca_certificate_file')