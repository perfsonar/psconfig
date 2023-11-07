from pscheduler.agent import Agent
from psconfig.remote import Remote

agent = Agent()
pscheduler_config = agent._load_config('/root/perfsonar/doc/pscheduler-agent.json')

agent.init('/root/perfsonar/doc/pscheduler-agent.json')
agent.run()

remote1 = Remote()
remote1.url = '/root/perfsonar/doc/example-2-testbed.json'
