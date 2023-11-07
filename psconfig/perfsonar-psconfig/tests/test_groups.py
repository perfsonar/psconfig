from psconfig.client.psconfig.api_connect import ApiConnect
conn = ApiConnect(url='../doc/example-2-testbed.json')

psconf = conn.get_config()
psconf.groups()
