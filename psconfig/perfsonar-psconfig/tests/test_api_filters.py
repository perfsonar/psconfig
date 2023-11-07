from unittest import TestCase
#from mock import patch

from psconfig.client.pscheduler.api_filters import ApiFilters

class TestApiFiltersTest(TestCase):
    def setUp(self) -> None:
        #self.task_filters = {}
        pass
    
    def test_parent_field_supplied_init_filter(self):
        api_filter = ApiFilters()
        api_filter._init_filter(api_filter.task_filters, 'test')
        self.assertEqual({'test':{}}, api_filter.task_filters)
    
    def test_field_exists_init_filter(self):
        api_filter = ApiFilters()
        api_filter.task_filters['test'] = {'test1': 1}
        api_filter._init_filter(api_filter.task_filters, 'test')
        self.assertEqual({'test':{'test1':1}}, api_filter.task_filters)
    
    def test_field_has_filter(self):
        api_filter = ApiFilters()
        api_filter.task_filters['test'] = {'test1': 1}
        result = api_filter._has_filter(api_filter.task_filters, 'test')
        self.assertEqual(True, result, 'Filter not found!')
        result = api_filter._has_filter(api_filter.task_filters, 'random')
        self.assertEqual(False, result, 'Filter found!')
    
    def test_parent_field_supplied_init_list_filter(self):
        api_filter = ApiFilters()
        api_filter._init_list_filter(api_filter.task_filters, 'test')
        self.assertEqual({'test':[]}, api_filter.task_filters, 'init_list_filter not found!')
        api_filter = ApiFilters()
        api_filter.task_filters['random'] = ['test1']
        api_filter._init_list_filter(api_filter.task_filters, 'random')
        self.assertEqual({'random':['test1']}, api_filter.task_filters, 'Already initialized init_list_filter not found!')
    
    def test_test_type(self):
        api_filter = ApiFilters()
        result = api_filter.test_type(None)
        self.assertEqual(None, result, 'test_type None not assigned!')
        result = api_filter.test_type('rtt')
        self.assertEqual('rtt', result, 'test_type rtt did not assigned!')
        result = api_filter.test_type(None)
        self.assertNotEqual(None, result, 'test_type None replaced rtt!')
        result = api_filter.test_type('throughput')
        self.assertEqual('throughput', result, 'test_type throughput did not replace rtt!')

    
    def test_test_spec(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.test_spec(None)
        self.assertEqual(None, result, 'test_spec None not assigned!')

        #proper spec
        result = api_filter.test_spec({"ip-version": 4})
        self.assertEqual({"ip-version": 4}, result, 'test_spec {"ip-version": 4} not assigned!')

        #val None after proper spec
        result = api_filter.test_spec(None)
        self.assertNotEqual(None, result, 'test_spec None replaced {"ip-version": 4}!')

        #replace value after already assigned
        result = api_filter.test_spec({"ip-version": 6})
        self.assertEqual({"ip-version": 6}, result, \
            'test_spec {"ip-version": 6} did not replace {"ip-version": 4}!')
    
    def test_test_spec_param(self):
        api_filter = ApiFilters()

        #field None
        result = api_filter.test_spec_param(None, 4)
        self.assertEqual(None, result, 'test_spec_parm parent(key) None failed')

        #value None
        result = api_filter.test_spec_param("ip-version", None)
        self.assertEqual(None, result, 'test_spec_parm val None failed')
        self.assertEqual(False, 'test' in api_filter.task_filters, \
            'test created before proper spec parameters are passed')

        #proper param
        result = api_filter.test_spec_param("ip-version", 4)
        self.assertEqual(4, result, 'ip-version not assigned to 4!')

        #Test None after param already assigned
        result = api_filter.test_spec_param(None, 4)
        self.assertEqual(4, api_filter.task_filters['test']['spec']['ip-version'], \
            'spec param replaced!')
        
        #replace value after already assigned
        result = api_filter.test_spec_param("ip-version", 6)
        self.assertEqual(6, api_filter.task_filters['test']['spec']['ip-version'], \
            'spec param not replaced!')

    def test_tool(self):
        api_filter = ApiFilters()

        #value is None
        result = api_filter.tool(None)
        self.assertEqual(None, result, 'None failed with initial test')

        #value valid
        result = api_filter.tool('iperf3')
        self.assertEqual('iperf3', result, 'value not assigned!')

        #None after valid value
        result = api_filter.tool(None)
        self.assertEqual('iperf3', result, 'returned value not assigned value!')
        self.assertEqual('iperf3', api_filter.task_filters['tool'], 'value not assigned!')

        #replace value after valid value
        result = api_filter.tool("twping")
        self.assertEqual("twping", result, 'returned value not valid!')
        self.assertEqual("twping", api_filter.task_filters['tool'], 'value not assigned!')
    
    def test_reference(self):
        api_filter = ApiFilters()

        #value is None
        result = api_filter.reference(None)
        self.assertEqual(None, result, 'None failed with initial test')

        #value valid
        result = api_filter.reference({"psconfig":{}})
        self.assertEqual({"psconfig":{}}, result, 'value not assigned!')

        #None after valid value
        result = api_filter.reference(None)
        self.assertEqual({"psconfig":{}}, result, 'returned value not from valid value assignment!')
        self.assertEqual({"psconfig":{}}, api_filter.task_filters['reference'], 'value not assigned!')

        #replace value after valid value
        result = api_filter.reference({"psconfig":{"created-by":{}}})
        self.assertEqual({"psconfig":{"created-by":{}}}, result, 'returned value not valid!')
        self.assertEqual({"psconfig":{"created-by":{}}}, api_filter.task_filters['reference'], 'value not assigned!')
    

    def test_reference_param(self):
        api_filter = ApiFilters()

        #field None
        result = api_filter.reference_param(None, "random")
        self.assertEqual(None, result, 'reference_param parent(key) None failed')

        #value None
        result = api_filter.reference_param("random", None)
        self.assertEqual(None, result, 'reference_param val None failed')
        self.assertEqual(False, 'reference' in api_filter.task_filters, \
            'test created before proper spec parameters are passed')

        #proper param
        result = api_filter.reference_param("psconfig", {"created-by":{"user-agent":"random"}})
        self.assertEqual({"created-by":{"user-agent":"random"}}, result, 'value not assigned to field')

        #Test None after param already assigned
        result = api_filter.reference_param(None, "random")
        self.assertEqual({"created-by":{"user-agent":"random"}}, api_filter.task_filters['reference']["psconfig"], \
            'reference param replaced!')
        
        #replace value after already assigned
        result = api_filter.reference_param("psconfig", {"created-by":{"user-agent":"random2"}})
        self.assertEqual({"created-by":{"user-agent":"random2"}}, result, 'returned result not valid!')
        self.assertEqual({"created-by":{"user-agent":"random2"}}, api_filter.task_filters['reference']["psconfig"], \
            'spec param not replaced!')

    
    def test_schedule(self):
        api_filter = ApiFilters()

        #value is None
        result = api_filter.schedule(None)
        self.assertEqual(None, result, 'None failed with initial test')

        #value valid
        result = api_filter.schedule({"sliprand":True})
        self.assertEqual({"sliprand":True}, result, 'value not assigned!')

        #None after valid value
        result = api_filter.schedule(None)
        self.assertEqual({"sliprand":True}, result, 'returned value not initial valid value assigned!')
        self.assertEqual({"sliprand":True}, api_filter.task_filters['schedule'], 'previous value not assigned!')

        #replace value after valid value
        result = api_filter.schedule({"sliprand":False})
        self.assertEqual({"sliprand":False}, result, 'returned value not valid!')
        self.assertEqual({"sliprand":False}, api_filter.task_filters['schedule'], 'value not assigned!')
    
    def test_schedule_maxruns(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.schedule_maxruns(None)
        self.assertEqual(None, result, 'schedule_maxruns None not assigned!')

        #proper maxruns
        result = api_filter.schedule_maxruns(4)
        self.assertEqual(4, result, 'schedule_maxruns 4 not assigned!')

        #val None after proper maxruns
        result = api_filter.schedule_maxruns(None)
        self.assertNotEqual(None, result, 'schedule_maxruns None replaced 4!')

        #replace value after already assigned
        result = api_filter.schedule_maxruns(10)
        self.assertEqual(10, result, \
            'schedule_maxruns 10 did not replace 4!')
    
    def test_schedule_repeat(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.schedule_repeat(None)
        self.assertEqual(None, result, 'schedule_repeat None not assigned!')

        #proper repeat
        result = api_filter.schedule_repeat('PT1H')
        self.assertEqual('PT1H', result, 'schedule_repeat PT1H not assigned!')

        #val None after proper repeat
        result = api_filter.schedule_repeat(None)
        self.assertNotEqual(None, result, 'schedule_repeat None replaced PT1H!')

        #replace value after already assigned
        result = api_filter.schedule_repeat('PT10H')
        self.assertEqual('PT10H', result, \
            'schedule_repeat PT10H did not replace PT1H!')
    
    def test_schedule_sliprand(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.schedule_sliprand(None)
        self.assertEqual(None, result, 'schedule_sliprand None not assigned!')

        #proper sliprand
        result = api_filter.schedule_sliprand(True)
        self.assertEqual(True, result, 'schedule_sliprand PT1H not assigned!')

        #val None after proper sliprand
        result = api_filter.schedule_sliprand(None)
        self.assertNotEqual(None, result, 'schedule_sliprand None replaced True!')

        #replace value after already assigned
        result = api_filter.schedule_sliprand(False)
        self.assertEqual(False, result, \
            'schedule_sliprand False did not replace True!')


    def test_schedule_slip(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.schedule_slip(None)
        self.assertEqual(None, result, 'schedule_slip None not assigned!')

        #proper slip
        result = api_filter.schedule_slip('PT1H')
        self.assertEqual('PT1H', result, 'schedule_slip PT1H not assigned!')

        #val None after proper slip
        result = api_filter.schedule_slip(None)
        self.assertNotEqual(None, result, 'schedule_slip None replaced PT1H!')

        #replace value after already assigned
        result = api_filter.schedule_slip('PT10H')
        self.assertEqual('PT10H', result, \
            'schedule_slip PT10H did not replace PT1H!')
    
    def test_schedule_start(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.schedule_start(None)
        self.assertEqual(None, result, 'schedule_start None not assigned!')

        #proper start
        result = api_filter.schedule_start('2022-08-04T12:07:22Z')
        self.assertEqual('2022-08-04T12:07:22Z', result, 'schedule_start PT1H not assigned!')

        #val None after proper start
        result = api_filter.schedule_start(None)
        self.assertNotEqual(None, result, 'schedule_start None replaced 2022-08-04T12:07:22Z!')

        #replace value after already assigned
        result = api_filter.schedule_start('2022-10-04T12:07:22Z')
        self.assertEqual('2022-10-04T12:07:22Z', result, \
            'schedule_start 2022-10-04T12:07:22Z did not replace 2022-08-04T12:07:22Z!')

    def test_schedule_until(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.schedule_until(None)
        self.assertEqual(None, result, 'schedule_until None not assigned!')

        #proper until
        result = api_filter.schedule_until('2022-08-04T12:07:22Z')
        self.assertEqual('2022-08-04T12:07:22Z', result, 'schedule_until PT1H not assigned!')

        #val None after proper until
        result = api_filter.schedule_until(None)
        self.assertNotEqual(None, result, 'schedule_until None replaced 2022-08-04T12:07:22Z!')

        #replace value after already assigned
        result = api_filter.schedule_until('2022-10-04T12:07:22Z')
        self.assertEqual('2022-10-04T12:07:22Z', result, \
            'schedule_until 2022-10-04T12:07:22Z did not replace 2022-08-04T12:07:22Z!')

    def test_detail(self):
        api_filter = ApiFilters()

        #value is None
        result = api_filter.detail(None)
        self.assertEqual(None, result, 'None failed with initial test')

        #value valid
        result = api_filter.detail({"anytime":True})
        self.assertEqual({"anytime":True}, result, 'value not assigned!')

        #None after valid value
        result = api_filter.detail(None)
        self.assertEqual({"anytime":True}, result, 'returned value not from valid value assignment!')
        self.assertEqual({"anytime":True}, api_filter.task_filters['detail'], 'previous value not assigned!')

        #replace value after valid value
        result = api_filter.detail({"anytime":False})
        self.assertEqual({"anytime":False}, result, 'returned value not valid!')
        self.assertEqual({"anytime":False}, api_filter.task_filters['detail'], 'value not assigned!')
    
    def test_detail_enabled(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_enabled(None)
        self.assertEqual(None, result, 'detail_enabled None not assigned!')

        #proper detail enabled
        result = api_filter.detail_enabled(1)
        self.assertEqual(True, result, 'detail_enabled 1 not assigned!')

        #val None after proper detail enabled
        result = api_filter.detail_enabled(None)
        self.assertNotEqual(None, result, 'detail_enabled None replaced 1!')

        #replace value after already assigned
        result = api_filter.detail_enabled(0)
        self.assertEqual(False, result, \
            'detail_enabled 0 did not replace 1!')
    
    def test_detail_enabled(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_enabled(None)
        self.assertEqual(None, result, 'detail_enabled None not assigned!')

        #proper detail enabled
        result = api_filter.detail_enabled(1)
        self.assertEqual(True, result, 'detail_enabled 1 not assigned!')

        #val None after proper detail enabled
        result = api_filter.detail_enabled(None)
        self.assertNotEqual(None, result, 'detail_enabled None replaced 1!')

        #replace value after already assigned
        result = api_filter.detail_enabled(0)
        self.assertEqual(False, result, \
            'detail_enabled 0 did not replace 1!')

    def test_detail_start(self): #Not actual values!
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_start(None)
        self.assertEqual(None, result, 'detail_start None not assigned!')

        #proper detail_start
        result = api_filter.detail_start(True)
        self.assertEqual(True, result, 'detail_start True not assigned!')

        #val None after proper detail_start
        result = api_filter.detail_start(None)
        self.assertNotEqual(None, result, 'detail_start None replaced True!')

        #replace value after already assigned
        result = api_filter.detail_start(False)
        self.assertEqual(False, result, \
            'detail_start False did not replace True!')

    def test_detail_runs(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_runs(None)
        self.assertEqual(None, result, 'detail_runs None not assigned!')

        #proper detail_runs
        result = api_filter.detail_runs(10)
        self.assertEqual(10, result, 'detail_runs 10 not assigned!')

        #val None after proper detail_runs
        result = api_filter.detail_runs(None)
        self.assertNotEqual(None, result, 'detail_runs None replaced 10!')

        #replace value after already assigned
        result = api_filter.detail_runs(5)
        self.assertEqual(5, result, \
            'detail_runs 5 did not replace 10!')

    def test_detail_added(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_added(None)
        self.assertEqual(None, result, 'detail_added None not assigned!')

        #proper detail_added
        result = api_filter.detail_added('2022-08-04T12:07:22-07:00')
        self.assertEqual('2022-08-04T12:07:22-07:00', result, 'detail_added 2022-08-04T12:07:22-07:00 not assigned!')

        #val None after proper detail_added
        result = api_filter.detail_added(None)
        self.assertNotEqual(None, result, 'detail_added None replaced 2022-08-04T12:07:22-07:00!')

        #replace value after already assigned
        result = api_filter.detail_added('2022-10-04T12:07:22-07:00')
        self.assertEqual('2022-10-04T12:07:22-07:00', result, \
            'detail_added 2022-10-04T12:07:22-07:00 did not replace 2022-08-04T12:07:22-07:00!')
    
    def test_detail_slip(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_slip(None)
        self.assertEqual(None, result, 'detail_slip None not assigned!')

        #proper detail_slip
        result = api_filter.detail_slip('PT1H11M11S')
        self.assertEqual('PT1H11M11S', result, 'detail_slip PT1H11M11S not assigned!')

        #val None after proper detail_slip
        result = api_filter.detail_slip(None)
        self.assertNotEqual(None, result, 'detail_slip None replaced PT1H11M11S!')

        #replace value after already assigned
        result = api_filter.detail_slip('PT2H22M22S')
        self.assertEqual('PT2H22M22S', result, \
            'detail_slip PT2H22M22S did not replace PT1H11M11S!')

    def test_detail_duration(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_duration(None)
        self.assertEqual(None, result, 'detail_duration None not assigned!')

        #proper detail_duration
        result = api_filter.detail_duration('PT11S')
        self.assertEqual('PT11S', result, 'detail_duration PT11S not assigned!')

        #val None after proper detail_duration
        result = api_filter.detail_duration(None)
        self.assertNotEqual(None, result, 'detail_duration None replaced PT11S!')

        #replace value after already assigned
        result = api_filter.detail_duration('PT22S')
        self.assertEqual('PT22S', result, \
            'detail_duration PT22S did not replace PT11S!')


    def test_detail_participants(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_participants(None)
        self.assertEqual(None, result, 'detail_participants None not assigned!')

        #proper detail_participants
        result = api_filter.detail_participants(['server1.net', 'server2.net'])
        self.assertEqual(['server1.net', 'server2.net'], result, 'detail_participants not assigned!')

        #val None after proper detail_participants
        result = api_filter.detail_participants(None)
        self.assertNotEqual(None, result, 'detail_participants None replaced original list!')

        #replace value after already assigned
        result = api_filter.detail_participants(['server3.net', 'server4.net'])
        self.assertEqual(['server3.net', 'server4.net'], result, \
            'detail_participants new value did not replace original!')

    def test_detail_exclusive(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_exclusive(None)
        self.assertEqual(None, result, 'detail_exclusive None not assigned!')

        #proper detail_exclusive
        result = api_filter.detail_exclusive(True)
        self.assertEqual(True, result, 'detail_exclusive True not assigned!')

        #val None after proper detail_exclusive
        result = api_filter.detail_exclusive(None)
        self.assertNotEqual(None, result, 'detail_exclusive None replaced True!')

        #replace value after already assigned
        result = api_filter.detail_exclusive(False)
        self.assertEqual(False, result, \
            'detail_exclusive False did not replace True!')

    def test_detail_multiresult(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_multiresult(None)
        self.assertEqual(None, result, 'detail_multiresult None not assigned!')

        #proper detail_multiresult
        result = api_filter.detail_multiresult(True)
        self.assertEqual(True, result, 'detail_multiresult True not assigned!')

        #val None after proper detail_multiresult
        result = api_filter.detail_multiresult(None)
        self.assertNotEqual(None, result, 'detail_multiresult None replaced True!')

        #replace value after already assigned
        result = api_filter.detail_multiresult(False)
        self.assertEqual(False, result, \
            'detail_multiresult False did not replace True!')

    def test_detail_anytime(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.detail_anytime(None)
        self.assertEqual(None, result, 'detail_anytime None not assigned!')

        #proper detail_anytime
        result = api_filter.detail_anytime(1)
        self.assertEqual(True, result, 'detail_anytime 1 not assigned!')

        #val None after proper detail_anytime
        result = api_filter.detail_anytime(None)
        self.assertNotEqual(None, result, 'detail_anytime None replaced True!')

        #replace value after already assigned
        result = api_filter.detail_anytime(0)
        self.assertEqual(False, result, \
            'detail_anytime 0 did not replace 1!')

    def test_archives(self):
        api_filter = ApiFilters()

        #val None
        result = api_filter.archives(None)
        self.assertEqual(None, result, 'archives None not assigned!')

        #proper archives
        result = api_filter.archives([{'data': {'_headers': None}}])
        self.assertEqual([{'data': {'_headers': None}}], result, 'archives not assigned!')

        #None after valid value
        result = api_filter.detail(None)
        self.assertEqual(None, result, 'returned value not None!')
        self.assertEqual([{'data': {'_headers': None}}], api_filter.task_filters['archives'], 'previous value not assigned!')

        #replace value after already assigned
        result = api_filter.archives([{'data': {'_headers': 'random'}}])
        self.assertEqual([{'data': {'_headers': 'random'}}], result, \
            'archives new value did not replace original!')

    def test_add_archive_name(self):
        api_filter = ApiFilters()

        #None for archive_name
        api_filter.add_archive_name(None)
        self.assertEqual(False, 'archives' in api_filter.task_filters, 'archives initialized!')

        #random for archive_name
        api_filter.add_archive_name('random')
        self.assertEqual([{'name': 'random'}], api_filter.task_filters['archives'], 'random value not assigned!')

        #None after valid archive_name
        api_filter.add_archive_name(None)
        self.assertEqual([{'name': 'random'}], api_filter.task_filters['archives'], 'None replaced existing archive!')

        #Another archive_name
        api_filter.add_archive_name('random2')
        self.assertEqual([{'name': 'random'}, {'name': 'random2'}], api_filter.task_filters['archives'], 'new name not added!')

    
    def test_add_archive_name(self):
        api_filter = ApiFilters()

        #None for archive_name
        api_filter.add_archive_name(None)
        self.assertEqual(False, 'archives' in api_filter.task_filters, 'archives initialized!')

        #random for archive_name
        api_filter.add_archive_name('random')
        self.assertEqual([{'name': 'random'}], api_filter.task_filters['archives'], 'random value not assigned!')

        #None after valid archive_name
        api_filter.add_archive_name(None)
        self.assertEqual([{'name': 'random'}], api_filter.task_filters['archives'], 'None replaced existing archive!')

        #Another archive_name
        api_filter.add_archive_name('random2')
        self.assertEqual([{'name': 'random'}, {'name': 'random2'}], api_filter.task_filters['archives'], 'new name not added!')

    
    def test_add_archive_data(self):
        api_filter = ApiFilters()

        #None for archive_name
        api_filter.add_archive_data(None)
        self.assertEqual(False, 'archives' in api_filter.task_filters, 'archives initialized!')

        #random for archive_name
        api_filter.add_archive_data({'_headers': None})
        self.assertEqual([{'data':{'_headers': None}}], api_filter.task_filters['archives'], 'data value not assigned!')

        #None after valid archive_name
        api_filter.add_archive_data(None)
        self.assertEqual([{'data':{'_headers': None}}], api_filter.task_filters['archives'], 'None replaced existing archive!')

        #Another archive_name
        api_filter.add_archive_data({'_headers': 'random'})
        self.assertEqual([{'data':{'_headers': None}}, {'data':{'_headers': 'random'}}], \
            api_filter.task_filters['archives'], 'new data not added!')

    
    def test_add_archive(self):
        api_filter = ApiFilters()

        #None for archive_name
        api_filter.add_archive(None)
        self.assertEqual(False, 'archives' in api_filter.task_filters, 'archives initialized!')

        #random for archive_name
        api_filter.add_archive({'name': 'random', 'data':{'_headers': None}})
        self.assertEqual([{'name': 'random', 'data':{'_headers': None}}], api_filter.task_filters['archives'], 'archive not assigned!')

        #None after valid archive_name
        api_filter.add_archive(None)
        self.assertEqual([{'name': 'random', 'data':{'_headers': None}}], api_filter.task_filters['archives'], 'None replaced existing archive!')

        #Another archive_name
        api_filter.add_archive({'name': 'random3', 'data':{'_headers': 'random2'}})
        self.assertEqual([{'name': 'random', 'data':{'_headers': None}}, {'name': 'random3', 'data':{'_headers': 'random2'}}], \
            api_filter.task_filters['archives'], 'new archive not added!')

