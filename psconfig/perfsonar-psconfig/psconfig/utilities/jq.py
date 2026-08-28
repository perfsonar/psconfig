'''
Utilities for running JQ.
'''

# This dodges a name collision
import jq as _jq

def jq(script, input_data):
    '''
    Run a jq script with input and return the first result
    '''

    # On failure, this raises ValueError('jq: ...')
    return _jq.compile(script).input_value(input_data).first()
