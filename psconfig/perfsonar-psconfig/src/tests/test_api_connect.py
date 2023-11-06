from shared.client.psconfig.api_connect import ApiConnect
conn = ApiConnect(url='../../doc/example-2-testbed.json')
conn2 = ApiConnect(url='../../doc/example-4-snmp.json')

#empty conf obj. ###### check later
empty_config_obj = conn.config_obj()
#####check the translator  methods

#get config from file
psconf = conn._config_from_file()
print(psconf)
psconf2 = conn2._config_from_file()

#merge
conn._merge_configs(psconf, psconf2)
#test the merge
psconf.archives()


#########test _config_from_http

# _raw_config_to_psconfig 
a = conn._raw_config_to_psconfig('{"archives": {"archive-snmp": {"archiver": "snmptrap", "data": {"dest": "monitor.perfsonar.net", "security-name": "perfsonar", "trap-oid": "1.2.3.4.5.6.7.8"}}}, "addresses": {"host-a.perfsonar.net": {"address": "host-a.perfsonar.net"}, "host-b.perfsonar.net": {"address": "host-b.perfsonar.net"}, "host-c.perfsonar.net": {"address": "host-c.perfsonar.net"}}, "groups": {"group-snmp": {"type": "list", "addresses": [{"name": "host-a.perfsonar.net"}, {"name": "host-b.perfsonar.net"}, {"name": "host-c.perfsonar.net"}]}}, "tests": {"test-snmp": {"type": "snmpget", "spec": {"version": 3, "dest": "{%address[0]%}", "polls": 1, "oid": "1.3.6.1.2.1.2.2.1.14"}}}, "schedules": {"schedule-snmp": {"repeat": "PT10M"}}, "tasks": {"task-snmp": {"group": "group-snmp", "test": "test-snmp", "schedule": "schedule-snmp", "archives": ["archive-snmp"]}}}')
a.archives()

psconf = conn.get_config()

conn.save_filename = 'shared/client/tests/psconfig_test.json'
conn.save_config(psconf) ######verify this definition

###Verify base_meta_node


#base_node
psconf.checksum()
