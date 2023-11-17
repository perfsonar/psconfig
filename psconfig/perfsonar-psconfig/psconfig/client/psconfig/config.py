from jsonschema import validate as jsonvalidate, ValidationError
from .archive import Archive
from .host import Host
from .schedule import Schedule
from .task import Task
from .context import Context
from .groups.base_group import BaseGroup
from .groups.group_factory import GroupFactory
from .address_classes.address_class import AddressClass
from .schema import Schema
from .base_meta_node import BaseMetaNode
from .addresses.address import Address
from .sub_task import SubTask
from .test import Test

class Config(BaseMetaNode):
    
    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)
        self.requesting_agent_addresses = kwargs.get('requesting_agent_addresses', {})
        self.error = ''
        
    def addresses(self, val=None):
        '''Gets/sets addresses as dictionary'''
        return self._field_class_map('addresses', Address, val)

    def address(self, field, val=None):
        '''Gets/sets address at specific field'''
        return self._field_class_map_item('addresses', field, Address, val)
    
    def address_names(self):
        '''Gets keys of addresses dictionary'''
        return self._get_map_names('addresses')
    
    def remove_address(self, field):
        '''Remove address at specified field'''
        return self._remove_map_item('addresses', field)
    
    def address_classes(self, val=None):
        '''Gets/sets addresses-classes as dictionary'''
        return self._field_class_map('address-classes', AddressClass, val)

    def address_class(self, field, val=None):
        '''Gets/sets address-class at specified field'''
        return self._field_class_map_item('address-classes', field, AddressClass, val)
    
    def address_class_names(self):
        '''Gets keys of address-classes dictionary'''
        return self._get_map_names('address-classes')
    
    def remove_address_class(self, field):
        '''removes address-class at specified field'''
        self._remove_map_item('address-classes', field)
    
    def archives(self, val=None):
        '''Gets/sets archives as dictionary'''
        return self._field_class_map('archives', Archive, val)
    
    def archive(self, field, val=None):
        '''Gets/sets archive at specific field'''
        return self._field_class_map_item('archives', field, Archive, val)

    def archive_names(self):
        '''Gets keys of archives dictionary'''
        return self._get_map_names('archives')

    def remove_archive(self, field):
        '''removes archive at specified field'''
        self._remove_map_item('archives', field)
    
    def contexts(self, val=None):
        '''Gets/sets contexts as dictionary'''
        return self._field_class_map('contexts', Context, val)

    def context(self, field, val=None):
        '''Gets/sets context at specified field'''
        return self._field_class_map_item('contexts', field, Context, val)
    
    def context_names(self):
        '''Gets keys of contexts dictionary'''
        return self._get_map_names('contexts')
    
    def remove_context(self, field):
        '''Removes context at specified field'''
        self._remove_map_item('contexts', field)
    
    def groups(self, val=None):
        '''Gets/sets groups as dictionary'''
        return self._field_class_factory_map('groups',
        BaseGroup, GroupFactory, val)
    
    def group(self, field, val=None):
        '''Gets/sets group at specified field'''
        return self._field_class_factory_map_item(
            'groups',
            field,
            BaseGroup,
            GroupFactory,
            val
        )
    
    def group_names(self):
        '''Gets keys of groups dictionary'''
        return self._get_map_names('groups')
    
    def remove_group(self, field):
        '''Removes group at specified field'''
        self._remove_map_item('groups', field)
    
    def hosts(self, val=None):
        '''Gets/sets hosts as dictionary'''
        return self._field_class_map('hosts', Host, val)
    
    def host(self, field, val=None):
        '''Gets/sets host at specified field'''
        return self._field_class_map_item('hosts', field, Host, val)
    
    def host_names(self):
        '''Gets keys of hosts dictionary'''
        return self._get_map_names('hosts')
    
    def remove_host(self, field):
        '''Removes host at specified field'''
        self._remove_map_item('hosts', field)
    
    def includes(self, val=None):
        '''Gets/sets includes as list'''
        return self._field('includes', val)
    
    def add_include(self, val=None):
        '''Adds include to list'''
        self._add_list_item('includes', val)
    
    def schedules(self, val=None):
        '''Gets/sets schedules as dictionary'''
        return self._field_class_map('schedules', Schedule, val)
    
    def schedule(self, field, val=None):
        '''Gets/sets schedule at specified field'''
        return self._field_class_map_item('schedules', field, Schedule, val)
    
    def schedule_names(self):
        '''Gets keys of schedules dictionary'''
        return self._get_map_names('schedules')
    
    def remove_schedule(self, field):
        '''Removes schedule at specified field'''
        self._remove_map_item('schedules', field)
    
    def subtasks(self, val=None):
        '''Gets/sets subtasks as dictionary'''
        return self._field_class_map('subtasks', SubTask, val)
    
    def subtask(self, field, val=None):
        '''Gets/sets subtask at specified field'''
        return self._field_class_map_item('subtasks', field, SubTask, val)
    
    def subtask_names(self):
        '''Gets keys of subtasks dictionary'''
        return self._get_map_names('subtasks')
    
    def remove_subtask(self, field):
        '''Removes subtask at specified field'''
        self._remove_map_item('subtasks', field)
    
    def tasks(self, val=None):
        '''Gets/sets tasks as dictionary'''
        return self._field_class_map('tasks', Task, val)
    
    def task(self, field, val=None):
        '''Gets/sets task at specified field'''
        return self._field_class_map_item('tasks', field, Task, val)
    
    def task_names(self):
        '''Gets keys of tasks dictionary'''
        return self._get_map_names('tasks')
    
    def remove_task(self, field):
        'Removes task at specified field'
        self._remove_map_item('tasks', field)
    
    def tests(self, val=None):
        '''Gets/sets tests as dictionary'''
        return self._field_class_map('tests', Test, val)
    
    def test(self, field, val=None):
        '''Gets/sets test at specified field'''
        return self._field_class_map_item('tests', field, Test, val)

    def test_names(self):
        '''Gets keys of tests dictionary'''
        return self._get_map_names('tests')
    
    def remove_test(self, field):
        '''Removes test at specified field'''
        self._remove_map_item('tests', field)
    
    def validate(self):
        '''Validates config against JSON schema. Return list of errors if finds any, return empty
        list otherwise'''
        schema = Schema().psconfig_json_schema()
        try:
            validator = jsonvalidate(instance=self.data, schema=schema)
            return []
        except ValidationError as e:
            return [e]
        except Exception as e:
            return [e]

    def _ref_check_addr_select(self, addr_sel, group_name, psconfig, errors):
        try:
            addr_name = addr_sel.name()
            addr_obj = psconfig.address(addr_name)
            if not addr_obj:
                errors.append("Group {} references an address object {} that does not exist.".format(group_name, addr_name))
                return
            addr_label_name = addr_sel.label()
            if addr_label_name and not addr_obj.label(addr_label_name):
                errors.append("Group {} references a label {} for address object {} that does not exist.".format(group_name, addr_label_name, addr_name))
        except Exception:
            try:
                class_name = addr_sel.field_class()
                if not psconfig.address_class():
                    errors.append("Group {} references a class object {} that does not exist.".format(group_name, class_name))
                    return
            except Exception:
                pass

    def validate_refs(self):
        ref_errors = []

        #check addresses
        for addr_name in self.address_names():
            address = self.address(addr_name)
            host_ref = address.host_ref()
            context_refs = address.context_refs()
            #check host ref
            if host_ref and not self.host(host_ref):
                ref_errors.append("Address {} references a host object {} that does not exist.".format(addr_name, host_ref))
            
            #check context refs
            if context_refs:
                for context_ref in context_refs:
                    if not self.context(context_ref):
                        ref_errors.append("Address {} references a context object {} that does not exist.".format(addr_name, context_ref))
            
            #check remote addresses
            for remote_name in address.remote_address_names():
                #check remote context refs
                remote  = address.remote_address(remote_name)
                if remote.context_refs():
                    for context_ref in remote.context_refs():
                        if not self.context(context_ref):
                            ref_errors.append("Address {} has a remote definition for {} using a context object {} that does not exist.".format(addr_name, remote_name, context_ref))
                
                #check remote labels
                for label_name in remote.label_names():
                    label = address.label(label_name)
                    if label and label.context_refs():
                        for context_ref in label.context_refs():
                            if not self.context(context_ref):
                                ref_errors.append("Address {} has a label {} using a context object {} that does not exist.".format(addr_name, label_name, context_ref))
            
            #check labels
            for label_name in address.label_names():
                label = address.label(label_name)
                #check label context refs
                if label and label.context_refs():
                    for context_ref in label.context_refs:
                        if not self.context(context_ref):
                            ref_errors.append("Address {} has a label {} using a context object {} that does not exist.".format(addr_name, label_name, context_ref))
                        
        
        #check groups
        for group_name in self.group_names():
            group = self.group(group_name)
            if group.type == 'disjoint':
                for a_addr_sel in group.a_addresses():
                    self._ref_check_addr_select(a_addr_sel, group_name, self, ref_errors)
                for b_addr_sel in group.b_addresses():
                    self._ref_check_addr_select(b_addr_sel, group_name, self, ref_errors)
            else:
                try:
                    for addr_sel in group.addresses():
                        self._ref_check_addr_select(addr_sel, group_name, self, ref_errors)
                except Exception:
                    pass
        
        #check hosts
        for host_name in self.host_names():
            host = self.host(host_name)
            if host and host.archive_refs():
                for archive_ref in host.archive_refs():
                    if archive_ref and not self.archive(archive_ref):
                        ref_errors.append("Host {} references an archive {} that does not exist.".format(host_name, archive_ref))
        
        #check tasks
        for task_name in self.task_names():
            task = self.task(task_name)
            group_ref = task.group_ref()
            test_ref = task.test_ref()
            schedule_ref = task.schedule_ref()

            #check group ref
            if group_ref and not self.group(group_ref):
                ref_errors.append("Task {} references a group {} that does not exist.".format(task_name, group_ref))
            #check test ref
            if test_ref and not self.test(test_ref):
                ref_errors.append("Task {} references a test {} that does not exist.".format(task_name, test_ref))
            #check schedule ref
            if schedule_ref and not self.schedule(schedule_ref):
                ref_errors.append("Task {} references a schedule {} that does not exist.".format(task_name, schedule_ref))
            #check archive refs
            if task.archive_refs():
                for archive_ref in task.archive_refs():
                    if archive_ref and not self.archive(archive_ref):
                        ref_errors.append("Task {} references an archive {} that does not exist.".format(task_name, archive_ref))
        
        return ref_errors
