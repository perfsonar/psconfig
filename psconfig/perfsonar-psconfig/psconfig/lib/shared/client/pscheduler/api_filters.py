'''
query parameters - getters and setters
'''

from typing import Any, Dict, List, Union

class ApiFilters(object):

    def __init__(self, **kwargs):
        self.task_filters = kwargs.get('task_filters', {})
        self.timeout = kwargs.get('timeout', 60)
        self.ca_certificate_file = None
        self.ca_certificate_path = None
        self.verify_hostname = None 

    def test_type(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'test')
            self.task_filters['test']['type'] = val
        
        if (not self._has_filter(self.task_filters, 'test')) or \
            (not self._has_filter(self.task_filters['test'], 'type')):
            return None
        
        return self.task_filters['test']['type']

    def test_spec(self, val: Dict = None) -> Union[Dict, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'test')
            self.task_filters['test']['spec'] = val
        
        if (not self._has_filter(self.task_filters, 'test')) or \
            (not self._has_filter(self.task_filters['test'], 'spec')):
            return None
        
        return self.task_filters['test']['spec']

    def test_spec_param(self, field: str = None, val: Union[str, int] = None) -> Union[str, None]:
        if field is None:
            return None
    
        if val is not None:
            self._init_filter(self.task_filters, 'test')
            self._init_filter(self.task_filters['test'], 'spec')
            self.task_filters['test']['spec'][field] = val
        
        try:
            return self.task_filters['test']['spec'][field]
        except KeyError:        
            return None
        
    
    def tool(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self.task_filters['tool'] = val
        
        return self.task_filters.get('tool',None)
    
    def reference(self, val: Dict = None) -> Union[Dict, None]:
        if val is not None:
            self.task_filters['reference'] = val
        
        return self.task_filters.get('reference', None)
    
    def reference_param(self, field: str = None, val: Union[str, Dict] = None) -> Union[str, Dict, None]:
        if field is None:
            return None
        
        if val is not None:
            self._init_filter(self.task_filters, 'reference')
            self.task_filters['reference'][field] = val
        
        if not self._has_filter(self.task_filters, 'reference'):
            return None
        
        return self.task_filters['reference'][field]
    
    def schedule(self, val: Dict = None) -> Union[Dict, None]:
        if val is not None:
            self.task_filters['schedule'] = val
        
        return self.task_filters.get('schedule', None)


    def schedule_maxruns(self, val:int = None) -> Union[int, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'schedule')
            self.task_filters['schedule']['max-runs'] = val

        try:
            return self.task_filters['schedule']['max-runs']
        except KeyError:
            return None
            
    def schedule_repeat(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'schedule')
            self.task_filters['schedule']['repeat'] = val
        
        try:
            return self.task_filters['schedule']['repeat']
        except KeyError:
            return None

    
    def schedule_sliprand(self, val: bool = None) -> Union[bool, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'schedule')
            if val:
                self.task_filters['schedule']['sliprand'] = True
            else:
                self.task_filters['schedule']['sliprand'] = False
        
        try:
            return self.task_filters['schedule']['sliprand']
        except KeyError:
            return None


    def schedule_slip(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'schedule')
            self.task_filters['schedule']['slip'] = val
        
        try:
            return self.task_filters['schedule']['slip']
        except KeyError:
            return None
        

    def schedule_start(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'schedule')
            self.task_filters['schedule']['start'] = val
        
        try:
            return self.task_filters['schedule']['start']
        except KeyError:
            return None

    
    def schedule_until(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'schedule')
            self.task_filters['schedule']['until'] = val
        
        try:
            return self.task_filters['schedule']['until']
        except KeyError:
            return None


    def detail(self, val: Dict = None) -> Union[Dict, None]:
        if val is not None:
            self.task_filters['detail'] = val
        return self.task_filters.get('detail', None)


    def detail_enabled(self, val: bool = None) -> Union[bool, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            if val:
                self.task_filters['detail']['enabled'] = True
            else:
                self.task_filters['detail']['enabled'] = False
        
        try:
            return self.task_filters['detail']['enabled']
        except KeyError:
            return None 
    
    def detail_start(self, val = None):
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            self.task_filters['detail']['start'] = val
        
        try:
            return self.task_filters['detail']['start']
        except KeyError:
            return None
            

    def detail_runs(self, val: int = None) -> Union[int, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            self.task_filters['detail']['runs'] = val
        
        try:
            return self.task_filters['detail']['runs']
        except KeyError:
            return None

    def detail_added(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            self.task_filters['detail']['added'] = val
        
        try:
            return self.task_filters['detail']['added']
        except KeyError:
            return None
    
    def detail_slip(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            self.task_filters['detail']['slip'] = val
        
        try:
            return self.task_filters['detail']['slip']
        except KeyError:
            return None
    
    def detail_duration(self, val: str = None) -> Union[str, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            self.task_filters['detail']['duration'] = val
        
        try:
            return self.task_filters['detail']['duration']
        except KeyError:
            return None
    
    def detail_participants(self, val: List[str] = None) -> Union[List[str], None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            self.task_filters['detail']['participants'] = val
        
        try:
            return self.task_filters['detail']['participants']
        except KeyError:
            return None

    def detail_exclusive(self, val: bool = None) -> Union[bool, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            if val:
                self.task_filters['detail']['exclusive'] = True
            else:
                self.task_filters['detail']['exclusive'] = False
        
        try:
            return self.task_filters['detail']['exclusive']
        except KeyError:
            return None
    
    def detail_multiresult(self, val: bool = None) -> Union[bool, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            if val:
                self.task_filters['detail']['multi-result'] = True
            else:
                self.task_filters['detail']['multi-result'] = False
        
        try:
            return self.task_filters['detail']['multi-result']
        except KeyError:
            return None

    def detail_anytime(self, val: bool = None) -> Union[bool, None]:
        if val is not None:
            self._init_filter(self.task_filters, 'detail')
            if val:
                self.task_filters['detail']['anytime'] = True
            else:
                self.task_filters['detail']['anytime'] = False
                
        try:
            return self.task_filters['detail']['anytime']
        except KeyError:
            return None
    
    def archives(self, val: List[Dict] = None) -> Union[List[Dict], None]:
        if val is not None:
            self.task_filters['archives'] = val
        return self.task_filters.get('archives', None)

    
    def add_archive_name(self, val: str = None) -> None:
        if val is not None:
            self._init_list_filter(self.task_filters, 'archives')
            self.task_filters['archives'].append({'name':val})
    
    def add_archive_data(self, val: Dict = None) -> None:
        if val is not None:
            self._init_list_filter(self.task_filters, 'archives')
            self.task_filters['archives'].append({'data':val})

    def add_archive(self, val: Dict = None) -> None:
        if val is not None:
            self._init_list_filter(self.task_filters, 'archives')
            self.task_filters['archives'].append({
                'name':val['name'], #######check usage
                'data':val['data']
                })
    
    def _has_filter(self, parent, field):
        if isinstance(parent, dict):
            return field in parent
        else:
            raise Exception('parent is not dictionary')

    def _init_filter(self, parent, field):
        if isinstance(parent, dict):
            parent[field] = parent.get(field, {})
        else:
            raise Exception('parent is not dictionary')
    
    def _init_list_filter(self, parent, field):
        if isinstance(parent, dict):
            parent[field] = parent.get(field, [])
        else:
            raise Exception('parent is not dictionary')
