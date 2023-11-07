'''
Utilities for running JQ.
'''

import pyjq

def jq(jq, json_obj, formatting_params=None, timeout=None):

    #initialize formatting params
    try:
        value = pyjq.one(jq, json_obj)
        return value
    except Exception as e:
        raise Exception('jq error: {}'.format(e))
