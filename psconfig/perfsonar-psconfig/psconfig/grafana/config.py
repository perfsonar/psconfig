from .schema import Schema
from ..base_agent import BaseAgentNode
from ..client.psconfig.base_node import BaseNode
from ..client.psconfig.jq_transform import JQTransform

class Config(BaseAgentNode):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.error = ''

    def schema(self):
        '''Returns the JSON schema for this config'''
        return Schema().psconfig_grafana_json_schema()

    def grafana_dashboard_template(self, val=None):
        return self._field('grafana-dashboard-template', val)

    def grafana_url(self, val=None):
        return self._field_url('grafana-url', val)

    def grafana_token(self, val=None):
        return self._field('grafana-token', val)
    
    def grafana_user(self, val=None):
        return self._field('grafana-user', val)

    def grafana_password(self, val=None):
        return self._field('grafana-password', val)
    
    def grafana_folder(self, val=None):
        return self._field('grafana-folder', val)

    def grafana_dashboard_tag(self, val=None):
        return self._field('grafana-dashboard-tag', val)

    def grafana_datasource_create(self, val=None):
        return self._field_bool_default_true('grafana-datasource-create', val)

    def grafana_datasource_settings(self, val=None):
        return self._field_anyobj('grafana-datasource-settings', val)
    
    def grafana_datasource_name(self, val=None):
        return self._field('grafana-datasource-name', val)
    
    def grafana_datasource_name_format(self, val=None):
        return self._field('grafana-datasource-name-format', val)
    
    def grafana_datasource_url_format(self, val=None):
        return self._field('grafana-datasource-url-format', val)
    
    def displays(self, val=None):
        return self._field_class_map('displays', Display, val)

    def display(self, field, val=None):
        return self._field_class_map_item('displays', field, Display, val)
    
    def display_names(self):
        return self._get_map_names('displays')
    
    def remove_display(self, field):
        self._remove_map_item('displays', field)

    def task_group_default(self, val=None):
        return self._field('task-group-default', val)
    
    def task_groups(self, val=None):
        return self._field_map('task-groups', val)

    def task_group(self, field, val=None):
        return self._field_map_item('task-groups', field, val)
    
    def task_group_names(self):
        return self._get_map_names('task-groups')
    
    def remove_task_group(self, field):
        self._remove_map_item('task-groups', field)

class Display(BaseNode):

    def stat_field(self, val=None):
        return self._field('stat_field', val)

    def stat_type(self, val=None):
        return self._field('stat_type', val)
    
    def stat_meta(self, val=None):
        return self._field_map('stat_meta', val)

    def static_fields(self, val=None):
        return self._field_bool_default_true('static_fields', val)

    def row_field(self, val=None):
        return self._field('row_field', val)

    def col_field(self, val=None):
        return self._field('col_field', val)
    
    def value_field(self, val=None):
        return self._field('value_field', val)

    def value_text(self, val=None):
        return self._field('value_text', val)

    def unit(self, val=None):
        return self._field('unit', val)

    def matrix_url(self, val=None):
        return self._field_url('matrix_url', val)

    def matrix_url_template(self, val=None):
        return self._field('matrix_url_template', val)

    def matrix_url_var1(self, val=None):
        return self._field('matrix_url_var1', val)

    def matrix_url_var2(self, val=None):
        return self._field('matrix_url_var2', val)

    def task_selector(self, val=None):
        return self._field_class('task_selector', TaskSelector, val)
    
    def datasource_selector(self, val=None):
        return self._field_enum('datasource_selector', val, [ "auto", "manual" ])

    def priority(self, val=None):
        return self._field_class('priority', Priority, val)

    def thresholds(self, val=None):
        return self._field_class_list('thresholds', ThresholdSpecification, val)
    
    def threshold(self, index, val=None):
        return self._field_class_list_item('thresholds', index, ThresholdSpecification, val)
    
    def add_threshold(self, val=None):
        self._add_field_class('thresholds', ThresholdSpecification, val)

class TaskSelector(BaseNode):
    
    def test_types(self, val=None):
        return self._field_list('test_types', val)

    def names(self, val=None):
        return self._field_list('names', val)
    
    def jq(self, val=None):
        return self._field_class('jq', JQTransform, val)


class Priority(BaseNode):

    def group(self, val=None):
        return self._field('group', val)
    
    def level(self, val=None):
        return self._field_intzero('level', val)

class ThresholdSpecification(BaseNode):

    def color(self, val=None):
        return self._field('color', val)

    def value(self, val=None, set_null=False):
        return self._field_numbernull('value', val, set_null=set_null)

