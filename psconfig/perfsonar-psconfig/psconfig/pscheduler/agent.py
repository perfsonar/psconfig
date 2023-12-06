'''Agent that loads config, grabs meshes and submits to pscheduler
'''

from ..client.pscheduler.task_manager import TaskManager
from ..client.psconfig.parsers.task_generator import TaskGenerator
from .config_connect import ConfigConnect
from ..utilities.iso8601 import duration_to_seconds
from ..base_agent import BaseAgent
import time
import logging
from ..utilities.logging_utils import LoggingUtils
import os

class Agent(BaseAgent):
    '''Agent that loads config, grabs meshes and submits to pscheduler'''

    def __init__(self, **kwargs):
        super(Agent, self).__init__(**kwargs)
        self.match_addresses = kwargs.get('match_addresses', [])
        self.pscheduler_fails = kwargs.get('pscheduler_fails', 0)
        self.max_pscheduler_attempts = kwargs.get('max_pscheduler_attempts', 5)
        self.task_min_ttl_seconds = kwargs.get('task_min_ttl_seconds', 86400)
        self.task_manager = kwargs.get('task_manager', None)
        self.logf = kwargs.get('logf', LoggingUtils())

        self.logger = logging.getLogger(__name__)
        self.task_logger = logging.getLogger('TaskLogger')
        self.transaction_logger = logging.getLogger('TransactionLogger')
    
    def _agent_name(self):
        return 'pscheduler'
    
    def _config_client(self):
        return ConfigConnect()
    
    def _init(self, agent_conf):
        ##
        # pscheduler_fail_attempts goes in max_pscheduler_attempts if set
        if agent_conf.pscheduler_fail_attempts():
            self.max_pscheduler_attempts = agent_conf.pscheduler_fail_attempts()
        
    def _run_start(self, agent_conf):
        ##
        # Set defaults for config values

        if not agent_conf.client_uuid_file():
            default = '/var/lib/perfsonar/psconfig/client_uuid'
            self.logger.debug(self.logf.format("No client-uuid-file specified. Defaulting to {}".format(default)))
            agent_conf.client_uuid_file(default)
        
        if not agent_conf.pscheduler_tracker_file():
            default = '/var/lib/perfsonar/psconfig/psc_tracker'
            self.logger.debug(self.logf.format("No pscheduler-tracker-file specified. Defaulting to {}".format(default)))
            agent_conf.pscheduler_tracker_file(default)
        
        if agent_conf.task_min_ttl():
            task_min_ttl_seconds = None

            try:
                task_min_ttl_seconds = duration_to_seconds(agent_conf.task_min_ttl())
            except Exception as e:
                self.logger.error(self.logf.format("Error parsing task-min-ttl. Defaulting to " + str(self.task_min_ttl_seconds) + " seconds: {}".format(e)))
            
            if not task_min_ttl_seconds:
                self.logger.error(self.logf.format("task_min_ttl has no value, sticking with default " + str(self.task_min_ttl_seconds) + " seconds"))
            else:
                self.task_min_ttl_seconds = task_min_ttl_seconds
            
            self.logger.debug(self.logf.format("task_min_ttl is " + str(self.task_min_ttl_seconds) + " seconds"))
        
        if not agent_conf.task_min_runs():
            default = 2
            self.logger.debug(self.logf.format( "No task-min-runs specified. Defaulting to {}".format(default) ))
            agent_conf.task_min_runs(default)
        
        if not agent_conf.task_renewal_fudge_factor():
            default = .25
            self.logger.debug(self.logf.format( "No task-renewal-fudge-factor specified. Defaulting to {}".format(default) ))
            agent_conf.task_renewal_fudge_factor(default)
        
        # Set cache directory per agent. Will not work to share since agents may
        #  have different permissions
        if not agent_conf.cache_directory():
            default = "/var/lib/perfsonar/psconfig/template_cache"
            self.logger.debug(self.logf.format("No cache-dir specified. Defaulting to {}".format(default)))
            agent_conf.cache_directory(default)
        
        ##
        # Set defaults for pscheduler binding addresses
        if not agent_conf.pscheduler_bind_map():
            agent_conf.pscheduler_bind_map({})
        
        ###
        #Determine match addresses
        auto_detected_addresses = None #for efficiency so we don't do twice
        match_addresses = agent_conf.match_addresses()
        if not match_addresses:
            auto_detected_addresses = self._get_addresses()
            match_addresses = auto_detected_addresses
            if not match_addresses:
                self.logger.error(self.logf.format("Unable to detect any match addresses. This may signify a problem with your /etc/hosts or DNS configuration. You can also try setting the match_addresses property directly.", {"match_addresses" : match_addresses}))
                return
            
            self.logger.debug(self.logf.format("Auto-detected match addresses", {"match_addresses" : match_addresses}))
        else:
            self.logger.debug(self.logf.format("Loaded match addresses from config file", {"match_addresses" : match_addresses}))
        
        self.match_addresses = match_addresses

        ##
        #Init the TaskManager
        old_task_deadline = int(time.time()) + self.check_interval_seconds ####oldtask deadline from current time?
        task_manager = None

        
        try:
            task_manager = TaskManager(
                pscheduler_url=self.pscheduler_url,
                tracker_file=agent_conf.pscheduler_tracker_file(),
                client_uuid_file=agent_conf.client_uuid_file(),
                reference_label='psconfig',
                user_agent='psconfig-pscheduler-agent',
                new_task_min_ttl=self.task_min_ttl_seconds,
                new_task_min_runs=agent_conf.task_min_runs(),
                old_task_deadline=old_task_deadline,
                task_renewal_fudge_factor=agent_conf.task_renewal_fudge_factor(),
                bind_map=agent_conf.pscheduler_bind_map(),
                lead_address_map={}, #\%pscheduler_addr_map,
                debug=self.debug,
                logger=self.transaction_logger,
                agent_hostname=os.uname().nodename
            )
            task_manager.logf.guid = self.logf.guid # make logging guids consistent'''
        except Exception as e:
            self.logger.error(self.logf.format("Problem initializing task_manager: {}".format(e)))
            return

        if not task_manager.check_assist_server():
            self.logger.error(self.logf.format("Problem contacting pScheduler, will try again later."))
            self.pscheduler_fails += 1
            return

        if(self.pscheduler_fails):
            self.logger.info(self.logf.format("pScheduler is back up, resuming normal operation"))
        self.pscheduler_fails = 0
        self.task_manager = task_manager

        return True
    
    def _run_handle_psconfig(self, psconfig, agent_conf, remote=None):
        #Init variables
        configure_archives = True
        if remote:
            #configure archives if from a remote source and not an include, then use remote setting
            configure_archives = remote.configure_archives()
        
        self.logger.debug(self.logf.format("configure_archives is {}".format(configure_archives)))

        #walk through tasks
        for task_name in psconfig.task_names():
            task = psconfig.task(task_name)
            if (not task) or task.disabled():
                continue
            
            self.logf.global_context['task_name'] = task_name

            tg = TaskGenerator(
                psconfig=psconfig,
                pscheduler_url=self.pscheduler_url,
                task_name=task_name,
                match_addresses=self.match_addresses,
                default_archives=self.default_archives,
                use_psconfig_archives=configure_archives,
                bind_map=agent_conf.pscheduler_bind_map()
            )

            if not tg.start():
                self.logger.error(self.logf.format("Error initializing task iterator: " + str(tg.error)))
                return

            #pair = []
            #while pair := tg.next(): ########################needs python>=3.8
            while tg.next():

                #check for errors expanding task
                if tg.error:
                    self.logger.error(tg.error)
                    continue
                #build pscheduler
                psc_task = tg.pscheduler_task()

                if not psc_task:
                    self.logger.error(self.logf.format("Error converting task to pscheduler: " + str(tg.error)))
                    continue

                self.task_manager.add_task(task=psc_task)
                #log task to task log. Do here because even if was not added, want record that
                # it is a task that this host manages
                self.task_logger.info(self.logf.format_task(psc_task))
            tg.stop()
            
        
        self.logger.debug(self.logf.format('Successfully processed task.'))
    
    def _run_end(self, agent_conf):
        task_manager = self.task_manager

        ##
        #commit tasks
        task_manager.commit()

        ##
        #Log results
        for error in task_manager.errors:
            self.logger.warn(self.logf.format(error))
        
        for deleted_task in task_manager.deleted_tasks:
            self.logger.debug(self.logf.format("Deleted task " + str(deleted_task.uuid) + " on server " + str(deleted_task.url)))
        
        for added_task in task_manager.added_tasks:
            self.logger.debug(self.logf.format("Created task " + str(added_task.uuid) + " on server " + str(added_task.url)))
        
        if task_manager.added_tasks or task_manager.deleted_tasks:
            self.logger.info(self.logf.format("Added " + str(len(task_manager.added_tasks)) + " new tasks, and deleted " + str(len(task_manager.deleted_tasks)) + " old tasks"))

    
    def will_retry_pscheduler(self):

        if self.pscheduler_fails > 0 and self.pscheduler_fails < self.max_pscheduler_attempts:
            return True
        
        return False
        

