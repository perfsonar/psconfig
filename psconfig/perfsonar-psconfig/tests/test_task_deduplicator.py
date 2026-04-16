#!/usr/bin/env python3
'''Unit and integration tests for TaskDeduplicator.'''

import copy
import json
import os
import sys
import types
import unittest
import unittest.mock

from psconfig.pscheduler.task_deduplicator import (
    TaskDeduplicator,
    _merge_references,
    _archive_identity_key,
    _hash_obj,
    ARCHIVE_KEY_FIELDS,
)


# ---------------------------------------------------------------------------
# Mock helpers
# ---------------------------------------------------------------------------

class MockPsconfigTask:
    '''Minimal stand-in for psconfig.client.psconfig.task.Task.'''
    def __init__(self, disabled=False, scheduled_by=None,
                 subtask_refs=None, meta=None):
        self._disabled = disabled
        self._scheduled_by = scheduled_by
        self._subtask_refs = subtask_refs or []
        self._meta = meta

    def disabled(self):
        return self._disabled

    def scheduled_by(self):
        return self._scheduled_by

    def subtask_refs(self):
        return self._subtask_refs

    def psconfig_meta(self):
        return self._meta


class MockSchedule:
    def __init__(self, data=None):
        self.data = data or {}


class MockAddress:
    '''Minimal stand-in for an address object used in lead_bind_map setup.'''
    def lead_bind_address(self):
        return None

    def address(self):
        return 'test.example.com'

    def pscheduler_address(self):
        return None


class MockTaskGenerator:
    '''Stand-in for TaskGenerator after a successful next() call.'''
    def __init__(self,
                 test_type='throughput',
                 test_spec=None,
                 test_meta=None,
                 archives=None,
                 contexts=None,
                 schedule_data=None,
                 tools=None,
                 priority=None,
                 reference=None,
                 scheduled_by=None,
                 subtask_refs=None,
                 task_meta=None,
                 disabled=False,
                 pscheduler_url='https://localhost/pscheduler',
                 bind_map=None):
        spec = test_spec or {'source': 'a.example.com', 'dest': 'b.example.com'}
        test_dict = {'type': test_type, 'spec': spec}
        if test_meta:
            test_dict['_meta'] = test_meta

        self.expanded_test = test_dict
        self.expanded_archives = archives if archives is not None else []
        self.expanded_contexts = contexts if contexts is not None else []
        self.schedule = MockSchedule(schedule_data) if schedule_data is not None else None
        self.tools = tools
        self.priority = priority
        self.expanded_reference = reference
        self.pscheduler_url = pscheduler_url
        self.bind_map = bind_map or {}
        self.addresses = [MockAddress()]
        self.task = MockPsconfigTask(
            disabled=disabled,
            scheduled_by=scheduled_by,
            subtask_refs=subtask_refs,
            meta=task_meta
        )


def _make_archive(archiver='esmond', url='http://example.com/esmond',
                  meta=None, schema=None):
    arc = {
        'archiver': archiver,
        'data': {'url': url},
    }
    if meta is not None:
        arc['_meta'] = meta
    if schema is not None:
        arc['schema'] = schema
    return arc


# ---------------------------------------------------------------------------
# Unit tests
# ---------------------------------------------------------------------------

class TestMergeReferences(unittest.TestCase):

    def test_both_none(self):
        self.assertIsNone(_merge_references(None, None))

    def test_base_none(self):
        incoming = {'key': 'val'}
        result = _merge_references(None, incoming)
        self.assertEqual(result, {'key': 'val'})

    def test_incoming_none(self):
        base = {'key': 'val'}
        result = _merge_references(base, None)
        self.assertEqual(result, {'key': 'val'})

    def test_no_collision(self):
        result = _merge_references({'a': 1}, {'b': 2})
        self.assertEqual(result, {'a': 1, 'b': 2})

    def test_collision_creates_list(self):
        result = _merge_references({'x': 'abc'}, {'x': '123'})
        self.assertEqual(result, {'x': ['abc', '123']})

    def test_equal_values_no_list(self):
        result = _merge_references({'x': 'abc'}, {'x': 'abc'})
        self.assertEqual(result, {'x': 'abc'})

    def test_existing_list_appends(self):
        base = {'x': ['abc', '123']}
        result = _merge_references(base, {'x': 'zzz'})
        self.assertIn('zzz', result['x'])
        self.assertEqual(len(result['x']), 3)

    def test_existing_list_no_duplicate(self):
        base = {'x': ['abc', '123']}
        result = _merge_references(base, {'x': '123'})
        self.assertEqual(result['x'].count('123'), 1)


class TestTaskDeduplicator(unittest.TestCase):

    def test_single_task_no_dedup(self):
        dedup = TaskDeduplicator()
        tg = MockTaskGenerator()
        self.assertTrue(dedup.add(tg))
        self.assertEqual(dedup.total_seen, 1)
        self.assertEqual(dedup.duplicate_count, 0)
        tasks = list(dedup.unique_tasks())
        self.assertEqual(len(tasks), 1)

    def test_two_different_tasks_no_dedup(self):
        dedup = TaskDeduplicator()
        tg1 = MockTaskGenerator(test_type='throughput')
        tg2 = MockTaskGenerator(test_type='latency')
        dedup.add(tg1)
        dedup.add(tg2)
        self.assertEqual(dedup.total_seen, 2)
        self.assertEqual(dedup.duplicate_count, 0)
        self.assertEqual(len(list(dedup.unique_tasks())), 2)

    def test_identical_tasks_deduped(self):
        dedup = TaskDeduplicator()
        tg1 = MockTaskGenerator()
        tg2 = MockTaskGenerator()
        dedup.add(tg1)
        dedup.add(tg2)
        self.assertEqual(dedup.total_seen, 2)
        self.assertEqual(dedup.duplicate_count, 1)
        self.assertEqual(len(list(dedup.unique_tasks())), 1)

    def test_disabled_task_skipped(self):
        dedup = TaskDeduplicator()
        tg = MockTaskGenerator(disabled=True)
        result = dedup.add(tg)
        self.assertIsNone(result)
        self.assertEqual(dedup.total_seen, 0)
        self.assertEqual(len(list(dedup.unique_tasks())), 0)

    def test_no_expanded_test_skipped(self):
        dedup = TaskDeduplicator()
        tg = MockTaskGenerator()
        tg.expanded_test = None
        result = dedup.add(tg)
        self.assertIsNone(result)
        self.assertEqual(dedup.total_seen, 0)

    def test_different_scheduled_by_not_deduped(self):
        dedup = TaskDeduplicator()
        tg1 = MockTaskGenerator(scheduled_by=0)
        tg2 = MockTaskGenerator(scheduled_by=1)
        dedup.add(tg1)
        dedup.add(tg2)
        self.assertEqual(dedup.duplicate_count, 0)
        self.assertEqual(len(list(dedup.unique_tasks())), 2)

    def test_different_tools_not_deduped(self):
        dedup = TaskDeduplicator()
        tg1 = MockTaskGenerator(tools=['iperf3'])
        tg2 = MockTaskGenerator(tools=['nuttcp'])
        dedup.add(tg1)
        dedup.add(tg2)
        self.assertEqual(dedup.duplicate_count, 0)
        self.assertEqual(len(list(dedup.unique_tasks())), 2)

    def test_different_contexts_not_deduped(self):
        dedup = TaskDeduplicator()
        ctx_a = [{'context': 'ctx-a', 'data': {'param': 1}}]
        ctx_b = [{'context': 'ctx-b', 'data': {'param': 2}}]
        tg1 = MockTaskGenerator(contexts=[ctx_a])
        tg2 = MockTaskGenerator(contexts=[ctx_b])
        dedup.add(tg1)
        dedup.add(tg2)
        self.assertEqual(dedup.duplicate_count, 0)
        self.assertEqual(len(list(dedup.unique_tasks())), 2)

    def test_priority_highest_kept(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(priority=3))
        dedup.add(MockTaskGenerator(priority=7))
        tasks = list(dedup.unique_tasks())
        self.assertEqual(len(tasks), 1)
        self.assertEqual(tasks[0].priority(), 7)

    def test_priority_none_then_value(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(priority=None))
        dedup.add(MockTaskGenerator(priority=5))
        tasks = list(dedup.unique_tasks())
        self.assertEqual(tasks[0].priority(), 5)

    def test_priority_value_then_none(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(priority=5))
        dedup.add(MockTaskGenerator(priority=None))
        tasks = list(dedup.unique_tasks())
        self.assertEqual(tasks[0].priority(), 5)

    def test_priority_both_none(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(priority=None))
        dedup.add(MockTaskGenerator(priority=None))
        tasks = list(dedup.unique_tasks())
        self.assertIsNone(tasks[0].priority())

    def test_reference_merge_no_collision(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(reference={'key1': 'val1'}))
        dedup.add(MockTaskGenerator(reference={'key2': 'val2'}))
        tasks = list(dedup.unique_tasks())
        ref = tasks[0].reference()
        self.assertEqual(ref.get('key1'), 'val1')
        self.assertEqual(ref.get('key2'), 'val2')

    def test_reference_merge_collision_becomes_list(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(reference={'created-by': 'abc'}))
        dedup.add(MockTaskGenerator(reference={'created-by': '123'}))
        tasks = list(dedup.unique_tasks())
        val = tasks[0].reference().get('created-by')
        self.assertIsInstance(val, list)
        self.assertIn('abc', val)
        self.assertIn('123', val)

    def test_reference_first_none_second_has_value(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(reference=None))
        dedup.add(MockTaskGenerator(reference={'key': 'val'}))
        tasks = list(dedup.unique_tasks())
        ref = tasks[0].reference()
        self.assertEqual(ref.get('key'), 'val')

    def test_subtask_refs_union(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(subtask_refs=['sub-a', 'sub-b']))
        dedup.add(MockTaskGenerator(subtask_refs=['sub-b', 'sub-c']))
        entry = list(dedup._entries.values())[0]
        self.assertEqual(entry['subtask_refs'], {'sub-a', 'sub-b', 'sub-c'})

    def test_task_meta_collected_as_array(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(task_meta={'owner': 'team-a'}))
        dedup.add(MockTaskGenerator(task_meta={'owner': 'team-b'}))
        tasks = list(dedup.unique_tasks())
        meta = tasks[0].data.get('_meta')
        self.assertIsInstance(meta, list)
        self.assertEqual(len(meta), 2)

    def test_task_meta_single_kept_as_dict(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(task_meta={'owner': 'team-a'}))
        tasks = list(dedup.unique_tasks())
        meta = tasks[0].data.get('_meta')
        self.assertIsInstance(meta, dict)
        self.assertEqual(meta.get('owner'), 'team-a')

    def test_task_meta_stripped_by_prep_if_no_meta(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(task_meta=None))
        tasks = list(dedup.unique_tasks())
        self.assertNotIn('_meta', tasks[0].data)

    def test_archive_schema_minimum_kept(self):
        arc1 = _make_archive(schema=2)
        arc2 = _make_archive(schema=5)
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(archives=[arc1]))
        dedup.add(MockTaskGenerator(archives=[arc2]))
        tasks = list(dedup.unique_tasks())
        archives = tasks[0].data.get('archives', [])
        self.assertEqual(len(archives), 1)
        self.assertEqual(archives[0].get('schema'), 2)

    def test_archive_schema_single_kept_as_scalar(self):
        arc = _make_archive(schema=3)
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(archives=[arc]))
        tasks = list(dedup.unique_tasks())
        archives = tasks[0].data.get('archives', [])
        self.assertEqual(archives[0].get('schema'), 3)

    def test_archive_meta_stripped(self):
        arc = _make_archive(meta={'info': 'test'})
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(archives=[arc]))
        tasks = list(dedup.unique_tasks())
        archives = tasks[0].data.get('archives', [])
        self.assertNotIn('_meta', archives[0])

    def test_archive_order_independence(self):
        '''Archives [A, B] and [B, A] produce the same dedup key.'''
        arc_a = _make_archive(archiver='esmond', url='http://a.example.com/esmond')
        arc_b = _make_archive(archiver='http', url='http://b.example.com/logstash')
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(archives=[arc_a, arc_b]))
        dedup.add(MockTaskGenerator(archives=[arc_b, arc_a]))
        self.assertEqual(dedup.duplicate_count, 1)
        self.assertEqual(len(list(dedup.unique_tasks())), 1)

    def test_schedule_key_fields_form_key(self):
        '''Different repeat values = different tasks.'''
        sched_a = {'repeat': 'PT4H', 'slip': 'PT1H', '_meta': {'tag': 'a'}}
        sched_b = {'repeat': 'PT8H', 'slip': 'PT1H', '_meta': {'tag': 'b'}}
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(schedule_data=sched_a))
        dedup.add(MockTaskGenerator(schedule_data=sched_b))
        self.assertEqual(dedup.duplicate_count, 0)
        self.assertEqual(len(list(dedup.unique_tasks())), 2)

    def test_schedule_meta_stripped(self):
        sched = {'repeat': 'PT4H', '_meta': {'tag': 'test'}}
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(schedule_data=sched))
        tasks = list(dedup.unique_tasks())
        schedule = tasks[0].data.get('schedule', {})
        self.assertNotIn('_meta', schedule)

    def test_schedule_same_key_fields_deduped(self):
        '''Same repeat/slip but different _meta = still duplicate (key ignores _meta).'''
        sched_a = {'repeat': 'PT4H', '_meta': {'note': 'first'}}
        sched_b = {'repeat': 'PT4H', '_meta': {'note': 'second'}}
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(schedule_data=sched_a))
        dedup.add(MockTaskGenerator(schedule_data=sched_b))
        self.assertEqual(dedup.duplicate_count, 1)

    def test_pscheduler_task_has_correct_test(self):
        spec = {'source': 'a.example.com', 'dest': 'b.example.com', 'duration': 'PT30S'}
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(test_type='throughput', test_spec=spec))
        tasks = list(dedup.unique_tasks())
        self.assertEqual(tasks[0].test_type(), 'throughput')
        self.assertEqual(tasks[0].test_spec_param('duration'), 'PT30S')

    def test_pscheduler_task_test_meta_stripped(self):
        '''_meta is removed from the test spec by _pscheduler_prep.'''
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(test_meta={'info': 'test'}))
        tasks = list(dedup.unique_tasks())
        self.assertNotIn('_meta', tasks[0].data.get('test', {}))

    def test_no_archives_no_archives_in_task(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(archives=[]))
        tasks = list(dedup.unique_tasks())
        self.assertNotIn('archives', tasks[0].data)

    def test_tools_in_task(self):
        dedup = TaskDeduplicator()
        dedup.add(MockTaskGenerator(tools=['iperf3']))
        tasks = list(dedup.unique_tasks())
        self.assertEqual(tasks[0].requested_tools(), ['iperf3'])

    def test_insertion_order_preserved(self):
        dedup = TaskDeduplicator()
        for i in range(5):
            spec = {'source': 'a{}.example.com'.format(i), 'dest': 'b.example.com'}
            dedup.add(MockTaskGenerator(test_spec=spec))
        tasks = list(dedup.unique_tasks())
        self.assertEqual(len(tasks), 5)
        for i, task in enumerate(tasks):
            self.assertEqual(task.test_spec_param('source'), 'a{}.example.com'.format(i))

    def test_multiple_duplicates_counted_correctly(self):
        dedup = TaskDeduplicator()
        for _ in range(5):
            dedup.add(MockTaskGenerator())
        self.assertEqual(dedup.total_seen, 5)
        self.assertEqual(dedup.duplicate_count, 4)
        self.assertEqual(dedup.unique_count, 1)
        self.assertEqual(len(list(dedup.unique_tasks())), 1)

    def test_unique_count_mixed(self):
        dedup = TaskDeduplicator()
        # 2 copies of task A, 3 copies of task B -> 2 unique
        for _ in range(2):
            dedup.add(MockTaskGenerator(test_type='throughput'))
        for _ in range(3):
            dedup.add(MockTaskGenerator(test_type='latency'))
        self.assertEqual(dedup.total_seen, 5)
        self.assertEqual(dedup.duplicate_count, 3)
        self.assertEqual(dedup.unique_count, 2)


# ---------------------------------------------------------------------------
# Integration test with example.json
# ---------------------------------------------------------------------------

def _install_mock_pyjq():
    '''
    Install a mock pyjq module so psconfig modules that depend on it can be
    imported in environments where pyjq is not available.  The mock simply
    returns None for every pyjq.one() call; this is fine for example.json
    which uses {% ... %} template syntax (handled by Template), not JQ.
    '''
    if 'pyjq' not in sys.modules:
        mock_pyjq = types.ModuleType('pyjq')
        mock_pyjq.one = lambda *args, **kwargs: None
        sys.modules['pyjq'] = mock_pyjq


class TestTaskDeduplicatorIntegration(unittest.TestCase):

    def setUp(self):
        _install_mock_pyjq()
        from psconfig.client.psconfig.config import Config
        example_path = os.path.join(os.path.dirname(__file__), 'example.json')
        with open(example_path) as f:
            data = json.load(f)
        self.psconfig = Config(data=data)
        self.assertIsNotNone(self.psconfig)

    def _make_tg(self, task_name):
        from psconfig.client.psconfig.parsers.task_generator import TaskGenerator
        return TaskGenerator(
            psconfig=self.psconfig,
            pscheduler_url='https://localhost/pscheduler',
            task_name=task_name,
            match_addresses=[],   # empty -> all addresses match
            default_archives=[],
            use_psconfig_archives=True,
            bind_map={}
        )

    def test_throughput_tasks_deduped(self):
        '''
        throughput_task and throughput_task2 reference the same test, archives,
        and schedule but use different mesh groups with identical membership.
        Each mesh of 3 addresses produces 6 ordered pairs (3*3 - 3 self-pairs).
        Total: 12 expanded tasks -> 6 unique after dedup.
        '''
        dedup = TaskDeduplicator()

        for task_name in ('throughput_task', 'throughput_task2'):
            tg = self._make_tg(task_name)
            self.assertTrue(tg.start(), 'tg.start() failed: ' + str(tg.error))
            while tg.next():
                if tg.error:
                    self.fail('tg.next() error: ' + str(tg.error))
                result = dedup.add(tg)
                self.assertTrue(result, 'dedup.add() failed')
            tg.stop()

        self.assertEqual(dedup.total_seen, 12)
        self.assertEqual(dedup.duplicate_count, 6)
        unique = list(dedup.unique_tasks())
        self.assertEqual(len(unique), 6)

    def test_unique_tasks_have_correct_test_type(self):
        dedup = TaskDeduplicator()
        tg = self._make_tg('throughput_task')
        tg.start()
        while tg.next():
            dedup.add(tg)
        tg.stop()

        for task in dedup.unique_tasks():
            self.assertEqual(task.test_type(), 'throughput')

    def test_unique_tasks_have_archives(self):
        dedup = TaskDeduplicator()
        tg = self._make_tg('throughput_task')
        tg.start()
        while tg.next():
            dedup.add(tg)
        tg.stop()

        for task in dedup.unique_tasks():
            archives = task.data.get('archives', [])
            self.assertGreater(len(archives), 0)
            self.assertEqual(archives[0]['archiver'], 'http')


if __name__ == '__main__':
    unittest.main()
