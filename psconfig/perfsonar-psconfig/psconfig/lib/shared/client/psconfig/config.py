from jsonschema import validate as jsonvalidate
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
        except Exception as e:
            return [e]

