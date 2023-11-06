
class Maintainer(object):

    def __init__(self, **kwargs):
        self.name = kwargs.get('name')
        self.email = kwargs.get('email')
        self.href = kwargs.get('href')