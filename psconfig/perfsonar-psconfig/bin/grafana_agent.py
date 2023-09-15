#!/usr/bin/env python3
import json
import re
import requests
import uuid
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from jinja2 import Environment, FileSystemLoader

from psconfig.lib.shared.client.psconfig.api_connect import ApiConnect
from psconfig.lib.shared.client.psconfig.parsers.task_generator import TaskGenerator

def slugify(s):
  s = s.lower().strip()
  s = re.sub(r'[^\w\s-]', '', s)
  s = re.sub(r'[\s_-]+', '-', s)
  s = re.sub(r'^-+|-+$', '', s)
  return s

#contstants that should be config
#PSCONFIG_JSON_URL = "https://34.171.24.112/psconfig/grafana-workshop.json"
PSCONFIG_JSON_URL = "https://ps-west.es.net/psconfig/esnet-psconfig.json"
TEMPLATE_DIR="etc/"
OUTPUT_DIR="output"
TEMPLATE_FILE="grafana.json.j2"
UUID_NAMESPACE_PS=uuid.UUID(hex='8caa5877-053a-42ae-9fc7-2681c3d02511')
TEST_TYPE_MAP = {
    "latencybg": {
        "stat_field": "result.packets.loss",
        "stat_type": "max",
        "row_field": "meta.source.hostname.keyword",
        "col_field": "meta.destination.hostname.keyword",
        "value_field": "Max",
        "value_text": "Loss",
        "unit": "percentunit",
        "thresholds": [
            {
                "color": "green",
                "value": None
            },
            {
                "color": "super-light-yellow",
                "value": 0.01
            },
            {
                "color": "red",
                "value": 0.1
            }
        ]
    },
    "rtt": {
        "stat_field": "result.rtt.min",
        "stat_type": "min",
        "row_field": "meta.source.hostname.keyword",
        "col_field": "meta.destination.hostname.keyword",
        "value_field": "Min",
        "value_text": "RTT",
        "unit": "s",
        "thresholds": [
            {
                "color": "green",
                "value": None
            },
            {
                "color": "red",
                "value": 1
            }
        ]
    },
    "throughput": {
        "stat_field": "result.throughput",
        "stat_type": "avg",
        "row_field": "meta.source.hostname.keyword",
        "col_field": "meta.destination.hostname.keyword",
        "value_field": "Average",
        "value_text": "Throughput",
        "unit": "bps",
        "thresholds": [
            {
                "color": "red",
                "value": None
            },
            {
                "color": "super-light-yellow",
                "value": 2000000000
            },
            {
                "color": "green",
                "value": 5000000000
            }
        ]
    },
    "trace": {
        "stat_field": "result.hop.count",
        "stat_type": "extended_stats",
        "stat_meta": {
            "std_deviation": True,
            "std_deviation_bounds_lower": False,
            "std_deviation_bounds_upper": False
        },
        "row_field": "meta.source.hostname.keyword",
        "col_field": "meta.destination.hostname.keyword",
        "value_field": "Std Dev",
        "value_text": "Hop Count Standard Deviation",
        "unit": "none",
        "thresholds": [
            {
                "color": "green",
                "value": None
            },
            {
                "color": "red",
                "value": .001
            }
        ]
    },
    "dns": {
        "stat_field": "result.time",
        "stat_type": "max",
        "row_field": "test.spec.host.keyword",
        "col_field": "test.spec.query.keyword",
        "value_field": "Max",
        "value_text": "Time",
        "unit": "s",
        "thresholds": [
            {
                "color": "green",
                "value": None
            },
            {
                "color": "red",
                "value": 1
            }
        ]
    }
}

JINJA_GLOBAL_SETTINGS = {
    "test_type_map": TEST_TYPE_MAP,
    #NOTE: I think we want ability to statically set datasource name or to lookup in Grafana
    # "datasource": {
    #     "type": "grafana-opensearch-datasource",
    #     "uid": "dfb3209f-c91f-4c3c-8cff-4ce831045f1b"
    # },
    # "url": "/d/ef95442a-d999-4879-9c78-a53e934a4c92/perfsonar-endpoint-stats?orgId=1",
    # "urlVar1": "source",
    # "urlVar2": "target"
    # "datasource": {
    #     "type": "elasticsearch",
    #     "uid": "cd77b069-20be-466e-8ffe-6b73552b7311"
    # },
    "url": "/grafana/d/c5ce2fcb-e7f9-4aaf-b16d-0bc008a6e6f9/esnet-endpoint-pair-explorer?orgId=1",
    "urlVar1": "source",
    "urlVar2": "target",
    "grafana_url": "https://FOO/grafana/",
    "grafana_api_token": "BAR",
    "folder_name": "External Dashboards",
    "datasource_name": "perfSONAR-ESDev-All"
}

def gf_build_header():
    return {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer {}".format(JINJA_GLOBAL_SETTINGS["grafana_api_token"])
    }

def gf_build_url(path):
    return "{}{}".format(JINJA_GLOBAL_SETTINGS["grafana_url"].strip().rstrip('/'), path)

def gf_find_datasource(name):
    url = gf_build_url(f'/api/datasources/name/{name}')
    r = requests.get(url, headers=gf_build_header(), verify=False)
    r.raise_for_status()
    uid = r.json().get("uid", None)
    type = r.json().get("type", None)
    if type is None or uid is None:
        return
    
    return { "type": type, "uid": uid}

def gf_find_folder(name):
    url = gf_build_url("/api/folders")
    r = requests.get(url, headers=gf_build_header(), verify=False)
    r.raise_for_status()
    for folder in r.json():
        if name == folder.get("title", None):
            return folder.get("uid", None)
        
    return

def gf_create_dash(dash, folderUid):
    
    url = gf_build_url("/api/dashboards/db")
    body = {
        "dashboard": json.loads(dash),
        "overwrite": True,
        "folderUid": folderUid
    }
    r = requests.post(url, json=body, headers=gf_build_header(), verify=False)
    r.raise_for_status()

#Read config
psconfig_client = ApiConnect(url=PSCONFIG_JSON_URL)
psconfig = psconfig_client.get_config()

#iterate through tasks
jinja_vars = {}
for task_name in psconfig.task_names():
    print(task_name)
    print("-------------------")

    task = psconfig.task(task_name)
    if not task or task.disabled(): continue

    #expand task
    #get test spec
    tg = TaskGenerator(
        psconfig=psconfig,
        pscheduler_url="",
        task_name=task_name,
        use_psconfig_archives=0
    )
    tg.start()
    tg.next()
    print("ERROR: {}".format(tg.error))
    if tg.expanded_test is None:
        print("WARN: Task {} does not have a valid test definition".format(task_name))
        continue
    print(tg.expanded_test)
    #check if we have a recognized test
    if tg.expanded_test.get("type", "") not in TEST_TYPE_MAP.keys():
        #TODO: LOGGING
        print("WARN: Unsupported test type {}".format(tg.expanded_test.type()))
        continue
    task.reference(tg.expanded_reference)
    print("tg.expanded_reference={}".format(tg.expanded_reference))
    print()
    tg.stop()

    #find display groups
    display_task_groups = [ "All Dashboards" ]
    meta_dtg = task.reference_param("display-task-group")
    if meta_dtg and isinstance(meta_dtg, list):
        display_task_groups += meta_dtg

    #init groups
    group = psconfig.group(task.group_ref())
    if not group:
        #TODO: LOGGING
        print("Invalid group name {}. Check for typos in your pSConfig template file.".format(task.group_ref()))
        continue
    #TODO: Support single dimension?
    if group.dimension_count() != 2:
        #TODO: LOGGING
        print("WARN: Only support groups with 2 dimensions")
        continue

    #init variable object
    display_task_name = task.reference_param("display-task-name")
    if not display_task_name:
        print("WARN: Skipping {}, no reference.display-task-name".format(task_name))
        continue
    var_obj = {
        "task_name": task_name,
        "display_task_name": display_task_name,
        "task": task.data,
        "group": group.data,
        "test": tg.expanded_test,
        "reverse": False,
        "archives": []
    }
    if task.schedule_ref():
         var_obj["schedule"] = psconfig.schedule(task.schedule_ref()).data

    #parse groups    
    d_keys = ["rows", "cols"]
    for d in range(0,2):
        addresses = []
        for addr_sel in group.dimension(d):
            for nla in addr_sel.select(psconfig):
                if nla.get("label", None) and nla.get("address", None):
                    addresses.append(nla["address"].label(nla["label"]))
                elif nla.get("address", None):
                    addresses.append(nla["address"].address())
        var_obj[d_keys[d]] = addresses

    #get test spec
    tg = TaskGenerator(
        psconfig=psconfig,
        pscheduler_url="",
        task_name=task_name,
        use_psconfig_archives=0
    )
    tg.start()
    tg.next()
    print("ERROR: {}".format(tg.error))
    if tg.expanded_test is None:
        print("WARN: Task {} does not have a valid test definition".format(task_name))
        continue
    print(tg.expanded_test)
    var_obj["test"] = tg.expanded_test
    #check if we have a recognized test
    if tg.expanded_test.get("type", "") not in TEST_TYPE_MAP.keys():
        #TODO: LOGGING
        print("WARN: Unsupported test type {}".format(tg.expanded_test.type()))
        continue
    print()
    tg.stop()

    #lookup data source
    if "datasource" not in JINJA_GLOBAL_SETTINGS.keys() and "datasource_name" in JINJA_GLOBAL_SETTINGS.keys():
        JINJA_GLOBAL_SETTINGS["datasource"] = gf_find_datasource(JINJA_GLOBAL_SETTINGS['datasource_name'])
        if JINJA_GLOBAL_SETTINGS["datasource"] is None:
            #TODO: LOGGING
            print("ERROR: Unable to find datasource ()".format(JINJA_GLOBAL_SETTINGS['datasource_name']))
            exit(1)

    #add to template variables organized by display task group
    for dtg in display_task_groups:
        if dtg not in jinja_vars.keys():
            uuid.uuid5(UUID_NAMESPACE_PS, dtg)
            jinja_vars[dtg] = {
                "display_task_group": dtg, 
                "grafana_uuid": str(uuid.uuid5(UUID_NAMESPACE_PS, dtg)),
                "settings": JINJA_GLOBAL_SETTINGS,
                "tasks": []
            }
        jinja_vars[dtg]['tasks'].append(var_obj)
        #add a reverse dashboard for disjoint
        if sorted(var_obj[d_keys[0]]) != sorted(var_obj[d_keys[1]]):
            rev_var_obj = var_obj.copy()
            rev_var_obj["reverse"] = True
            jinja_vars[dtg]['tasks'].append(rev_var_obj)

#Load jinja template
environment = Environment(loader=FileSystemLoader(TEMPLATE_DIR))            
template = environment.get_template(TEMPLATE_FILE)
#determine folder
#TODO: Grafana only
folderUid = gf_find_folder(JINJA_GLOBAL_SETTINGS["folder_name"])
for jv in jinja_vars.values():
    #print(jv)
    rendered_content = template.render(jv)
    #print(rendered_content)
    filename = "{}/{}.json".format(slugify(OUTPUT_DIR, jv["display_task_group"]))
    with open(filename, mode="w", encoding="utf-8") as message:
        message.write(rendered_content)
        print(f"... wrote {filename}")

    #####Grafana START
    if folderUid is None:
        #TODO: logging
        print("ERROR: Unable to find Grafana folder with name {}".format(JINJA_GLOBAL_SETTINGS["folder_name"]))
        continue 
    gf_create_dash(rendered_content, folderUid)
    #####Grafana END