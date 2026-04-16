'''
Deduplicates expanded pSConfig tasks across meshes and psconfig files.

When the same address pairs appear in multiple mesh groups (or across multiple
psconfig templates), TaskGenerator produces duplicate expanded tasks. This module
collects all expanded tasks, deduplicates them by key identity fields, merges
non-key fields from duplicates, and yields unique pScheduler Task objects.
'''

import copy
import json
import logging
from hashlib import md5
from base64 import b64encode

from ..client.pscheduler.task import Task

# Fields used as the identity key for schedule dedup
SCHEDULE_KEY_FIELDS = ['start', 'slip', 'sliprand', 'repeat', 'until', 'max-runs']

# Fields used as the identity key for archive dedup
ARCHIVE_KEY_FIELDS = ['archiver', 'data', 'transform', 'ttl', 'runs', 'label']


def _pscheduler_prep(obj):
    '''Strips _meta from a dict in place, mirroring TaskGenerator._pscheduler_prep.'''
    if isinstance(obj, dict) and obj.get('_meta'):
        del obj['_meta']
    return obj


def _hash_obj(obj):
    '''Returns a base64-encoded MD5 hash of the canonical JSON of obj.'''
    canonical = json.dumps(obj, sort_keys=True, separators=(',', ':')).encode('utf-8')
    return b64encode(md5(canonical).digest()).decode().rstrip('=')


def _archive_identity_key(archive):
    '''Build a dedup key for an archive using only identity fields.'''
    identity = {f: copy.deepcopy(archive[f]) for f in ARCHIVE_KEY_FIELDS if f in archive}
    return _hash_obj(identity)


def _merge_references(base, incoming):
    '''
    Merge two reference dicts. When the same key appears in both with different
    values, collect values into a list (union). Equal values are kept as-is.
    Both base and incoming may be None.
    '''
    if incoming is None:
        return base
    if base is None:
        return copy.deepcopy(incoming)

    result = copy.deepcopy(base)
    for key, new_val in incoming.items():
        if key not in result:
            result[key] = copy.deepcopy(new_val)
        else:
            old_val = result[key]
            if isinstance(old_val, list):
                # Already a list from previous merge -- add new_val if not present
                if new_val not in old_val:
                    old_val.append(copy.deepcopy(new_val))
            elif old_val != new_val:
                # Collision -- convert to list
                result[key] = [old_val, copy.deepcopy(new_val)]
            # else: values are equal, keep as-is
    return result


class TaskDeduplicator:
    '''
    Collects expanded tasks from TaskGenerator and deduplicates them.

    Usage:
        dedup = TaskDeduplicator()
        for task_name in psconfig.task_names():
            tg = TaskGenerator(...)
            tg.start()
            while tg.next():
                dedup.add(tg)
            tg.stop()

        for psc_task in dedup.unique_tasks():
            task_manager.add_task(task=psc_task)
    '''

    def __init__(self, logger=None, logf=None):
        self._entries = {}      # dedup_key -> entry dict
        self._key_order = []    # preserve insertion order for deterministic output
        self._total_seen = 0
        self._duplicate_count = 0
        self._logger = logger or logging.getLogger(__name__)
        self._logf = logf

    @property
    def total_seen(self):
        return self._total_seen

    @property
    def duplicate_count(self):
        return self._duplicate_count

    def add(self, tg):
        '''
        Accept a TaskGenerator after a successful next() call.

        Deep-copies all expanded data from the TaskGenerator, builds a dedup key,
        and either stores a new entry or merges non-key fields into an existing one.
        Does NOT call tg.pscheduler_task() -- that is deferred to unique_tasks().

        Returns True on success, None if task is disabled or has no test data.
        '''
        # Skip disabled tasks
        if tg.task and tg.task.disabled():
            return None

        # Must have an expanded test
        if not tg.expanded_test:
            return None

        self._total_seen += 1

        # --- Deep-copy expanded data before any mutation ---
        pre_test = copy.deepcopy(tg.expanded_test)
        pre_archives = copy.deepcopy(tg.expanded_archives) if tg.expanded_archives else []
        pre_contexts = copy.deepcopy(tg.expanded_contexts) if tg.expanded_contexts else []
        pre_schedule = copy.deepcopy(tg.schedule.data) if tg.schedule else None

        # --- Build dedup key ---
        key = self._build_key(
            test=pre_test,
            archives=pre_archives,
            contexts=pre_contexts,
            schedule_data=pre_schedule,
            scheduled_by=tg.task.scheduled_by() if tg.task.scheduled_by() is not None else 0,
            tools=tg.tools
        )

        # --- Extract merge-field values ---
        priority = tg.priority
        reference = copy.deepcopy(tg.expanded_reference) if tg.expanded_reference else None
        subtask_refs = list(tg.task.subtask_refs()) if tg.task and tg.task.subtask_refs() else []
        task_meta = copy.deepcopy(tg.task.psconfig_meta()) if tg.task and tg.task.psconfig_meta() else None

        if key in self._entries:
            # Duplicate -- merge non-key fields
            self._merge(
                self._entries[key],
                priority=priority,
                reference=reference,
                subtask_refs=subtask_refs,
                task_meta=task_meta,
                archives=pre_archives
            )
            self._duplicate_count += 1
            self._log_debug('Deduplicated task (key={})'.format(key))
        else:
            # First occurrence -- create new entry
            self._entries[key] = self._new_entry(
                pre_test=pre_test,
                pre_archives=pre_archives,
                pre_contexts=pre_contexts,
                pre_schedule=pre_schedule,
                tools=tg.tools,
                pscheduler_url=tg.pscheduler_url,
                bind_map=tg.bind_map,
                addresses=tg.addresses,
                priority=priority,
                reference=reference,
                subtask_refs=subtask_refs,
                task_meta=task_meta
            )
            self._key_order.append(key)

        return True

    def unique_tasks(self):
        '''
        Yield pScheduler Task objects for each unique task, with merged fields applied.

        This is where the pscheduler_task() logic runs (mirroring
        TaskGenerator.pscheduler_task()), operating on merged data.
        '''
        for key in self._key_order:
            entry = self._entries[key]
            psc_task = self._build_pscheduler_task(entry)
            if psc_task:
                yield psc_task

    # --- Private helpers ---

    def _build_key(self, test, archives, contexts, schedule_data, scheduled_by, tools):
        '''Build a canonical dedup key from identity fields only.'''
        key_dict = {}

        # Test: type + spec, strip _meta
        test_copy = copy.deepcopy(test)
        test_copy.pop('_meta', None)
        key_dict['test'] = test_copy

        # Schedule: only identity subfields
        if schedule_data:
            key_dict['schedule'] = {
                f: schedule_data[f]
                for f in SCHEDULE_KEY_FIELDS
                if f in schedule_data
            }
        else:
            key_dict['schedule'] = None

        # Archives: strip _meta and schema, sort for order-independence
        arc_list = []
        for arc in archives:
            arc_identity = {
                f: copy.deepcopy(arc[f])
                for f in ARCHIVE_KEY_FIELDS
                if f in arc
            }
            arc_list.append(arc_identity)
        arc_list.sort(key=lambda a: json.dumps(a, sort_keys=True, separators=(',', ':')))
        key_dict['archives'] = arc_list

        # Scalar fields
        key_dict['scheduled-by'] = scheduled_by if scheduled_by is not None else 0
        key_dict['tools'] = tools if tools else None

        # Contexts: strip _meta from each context object
        ctx_list = []
        for participant in contexts:
            cleaned = []
            if isinstance(participant, list):
                for ctx in participant:
                    c = copy.deepcopy(ctx)
                    c.pop('_meta', None)
                    cleaned.append(c)
            else:
                c = copy.deepcopy(participant)
                if isinstance(c, dict):
                    c.pop('_meta', None)
                cleaned.append(c)
            ctx_list.append(cleaned)
        key_dict['contexts'] = ctx_list

        return _hash_obj(key_dict)

    def _new_entry(self, pre_test, pre_archives, pre_contexts, pre_schedule,
                   tools, pscheduler_url, bind_map, addresses,
                   priority, reference, subtask_refs, task_meta):
        '''Create a new storage entry for a first-seen unique task.'''
        # Build per-archive schema tracker: identity_key -> [schema values]
        archive_schemas = {}
        for arc in pre_archives:
            arc_key = _archive_identity_key(arc)
            schema_val = arc.get('schema')
            if schema_val is not None:
                archive_schemas.setdefault(arc_key, []).append(schema_val)

        return {
            # Data needed to build the final pScheduler task
            'pre_test': pre_test,
            'pre_archives': pre_archives,
            'pre_contexts': pre_contexts,
            'pre_schedule': pre_schedule,
            'tools': tools,
            'pscheduler_url': pscheduler_url,
            'bind_map': bind_map,
            'addresses': addresses,
            # Merged non-key fields
            'priority': priority,
            'merged_reference': reference,   # dict or None
            'subtask_refs': set(subtask_refs),
            'task_metas': [task_meta] if task_meta is not None else [],
            'archive_schemas': archive_schemas,  # identity_key -> [schema, ...]
        }

    def _merge(self, entry, priority, reference, subtask_refs, task_meta, archives):
        '''Apply merge rules for a duplicate task into an existing entry.'''
        # Priority: keep the highest (None < any integer)
        if priority is not None:
            if entry['priority'] is None or priority > entry['priority']:
                entry['priority'] = priority

        # Reference: merge dicts by key; colliding values become lists
        entry['merged_reference'] = _merge_references(entry['merged_reference'], reference)

        # Subtask refs: union
        entry['subtask_refs'].update(subtask_refs)

        # Task _meta: collect
        if task_meta is not None:
            entry['task_metas'].append(task_meta)

        # Archive schemas: collect per-archive
        for arc in archives:
            schema_val = arc.get('schema')
            if schema_val is not None:
                arc_key = _archive_identity_key(arc)
                entry['archive_schemas'].setdefault(arc_key, [])
                if schema_val not in entry['archive_schemas'][arc_key]:
                    entry['archive_schemas'][arc_key].append(schema_val)

    def _build_pscheduler_task(self, entry):
        '''
        Build a pScheduler Task object from a stored (and merged) entry.
        Mirrors TaskGenerator.pscheduler_task() logic.
        '''
        task_data = {}

        # Test
        test = copy.deepcopy(entry['pre_test'])
        task_data['test'] = _pscheduler_prep(test)

        # Archives: apply merged schema arrays, then strip _meta via prep
        if entry['pre_archives']:
            archives = copy.deepcopy(entry['pre_archives'])
            for arc in archives:
                arc_key = _archive_identity_key(arc)
                schemas = entry['archive_schemas'].get(arc_key)
                if schemas is not None:
                    if len(schemas) == 1:
                        arc['schema'] = schemas[0]
                    else:
                        arc['schema'] = schemas
                _pscheduler_prep(arc)
            task_data['archives'] = archives

        # Contexts
        if entry['pre_contexts']:
            contexts = copy.deepcopy(entry['pre_contexts'])
            has_context = False
            for participant in contexts:
                if isinstance(participant, list):
                    for ctx in participant:
                        _pscheduler_prep(ctx)
                        has_context = True
                else:
                    _pscheduler_prep(participant)
                    has_context = True
            if has_context:
                task_data['contexts'] = {'contexts': contexts}

        # Schedule
        if entry['pre_schedule'] is not None:
            schedule = copy.deepcopy(entry['pre_schedule'])
            task_data['schedule'] = _pscheduler_prep(schedule)

        # Reference: merged dict
        if entry['merged_reference'] is not None:
            task_data['reference'] = entry['merged_reference']

        # Tools
        if entry['tools']:
            task_data['tools'] = entry['tools']

        # Priority: highest from all duplicates
        if entry['priority'] is not None:
            task_data['priority'] = entry['priority']

        # Task _meta: array of all duplicate _meta dicts
        if entry['task_metas']:
            if len(entry['task_metas']) == 1:
                task_data['_meta'] = entry['task_metas'][0]
            else:
                task_data['_meta'] = entry['task_metas']

        # Build pScheduler Task object
        psc_task = Task(
            url=entry['pscheduler_url'],
            data=task_data
        )

        # Bind map
        psc_task.bind_map = entry['bind_map']

        # Lead bind addresses
        for addr in entry['addresses']:
            if addr.lead_bind_address():
                psc_task.add_lead_bind_map(addr.address(), addr.lead_bind_address())
                if addr.pscheduler_address():
                    psc_task.add_lead_bind_map(addr.pscheduler_address(), addr.lead_bind_address())

        return psc_task

    def _log_debug(self, msg):
        if self._logger:
            if self._logf:
                self._logger.debug(self._logf.format(msg))
            else:
                self._logger.debug(msg)
