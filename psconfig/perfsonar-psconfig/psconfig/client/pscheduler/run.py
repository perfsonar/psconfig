from .base_node import BaseNode

class Run(BaseNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
    
    def start_time(self, val=None):
        if val is not None:
            self.data['start-time'] = val
        return self.data.get('start-time', None)
    
    def end_time(self, val=None):
        if val is not None:
            self.data['end-time'] = val
        return self.data.get('end-time', None)

    def state(self, val=None):
        if val is not None:
            self.data['state'] = val
        return self.data.get('state', None)
    
    def duration(self, val=None):
        if val is not None:
            self.data['duration'] = val
        return self.data.get('duration', None)
    
    def state_display(self, val=None):
        if val is not None:
            self.data['state-display'] = val
        return self.data.get('state-display', None)
    
    def participant(self, val=None):
        if val is not None:
            self.data['participant'] = val
        return self.data.get('participant', None)
    
    def participants(self, val=None):
        if val is not None:
            self.data['participants'] = val
        return self.data.get('participants', None)
    
    def participant_data(self, val=None):
        if val is not None:
            self.data['participant-data'] = val
        return self.data.get('participant-data', None)
    
    def participant_data_full(self, val=None):
        if val is not None:
            self.data['participant-data-full'] = val
        return self.data.get('participant-data-full', None)
    
    def errors(self, val=None):
        if val is not None:
            self.data['errors'] = val
        return self.data.get('errors', None)
    
    def result_merged(self, val=None):
        if val is not None:
            self.data['result-merged'] = val
        return self.data.get('result-merged', None)
    
    def result_full(self, val=None):
        if val is not None:
            self.data['result-full'] = val
        return self.data.get('result-full', None)
    
    def result(self, val=None):
        if val is not None:
            self.data['result'] = val
        return self.data.get('result', None)
    