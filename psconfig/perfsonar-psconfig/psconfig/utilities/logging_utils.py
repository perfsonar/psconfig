'''Utility to help with formatting log messages'''
import uuid
import json

class LoggingUtils():
    '''A client for reading in JQTransform files'''

    def __init__(self, **kwargs) -> None:
        self.logging_format = kwargs.get('logging_format', '%(asctime)s %(levelname)s pid=%(process)d prog=%(funcName)s line=%(lineno)d %(message)s')
        self.global_context = kwargs.get('global_context', {})
        self.guid = kwargs.get('guid', '')
        self.guid_label = kwargs.get('guid_label', 'guid')

    def format(self, msg, local_context=None):

        #init with guid
        m = self._append_guid()

        #set contexts
        m += self._append_contexts(local_context, m)

        #add message
        msg = msg.strip()
        msg += self._append_msg('msg', msg, m)

        return m
    
    def format_task(self, task, local_context=None):

        #init with guid
        m = self._append_guid()

        #set contexts
        m += self._append_contexts(local_context, m)

        #add message
        m += self._append_msg('task', task.data, m)

        return m
    
    def generate_guid(self):

        self.guid = uuid.UUID(bytes=uuid.uuid4().bytes).__str__()

    def _append_guid(self):
        m = ''

        if self.guid:
            m += self.guid_label + '=' + self.guid

        return m
    
    def _append_contexts(self, local_context, msg):

        m = ''

        #add global context variables
        for ctx in self.global_context:
            m += self._append_msg(ctx, self.global_context[ctx], m)

        #add local context variables
        if local_context:
            for ctx in local_context:
                m += self._append_msg(ctx, local_context[ctx], m)

        #make sure there is a space if needed
        if m and msg:
            m = ' ' + m
        
        return m
    
    def _append_msg(self, k, v, msg):
        m = ''
        if msg:
            m += ' '
        val = v

        if isinstance(val, dict) or isinstance(val, list):
            val = json.dumps(val, ensure_ascii=False)
        
        m += "{}={}".format(k, val)

        return m
