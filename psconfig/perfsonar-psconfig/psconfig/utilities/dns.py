'''A module that provides utility methods for interacting with DNS servers.  This
module provides a set of methods for interacting with DNS servers. This module
IS NOT an object, and the methods can be invoked directly. The methods need to
be explicitly imported to use them.'''

import socket
import dns.resolver
from ipaddress import ip_address

def read_etc_hosts():
    ip_hosts = {}
    host_ips = {}
    try:
        with open('/etc/hosts', 'r') as file:
            for line in file:
                if not line.startswith('#'): # Ignore comments
                    line_entry = line.split()
                    if not line_entry or len(line_entry) < 2:
                        continue
                    for entry in line_entry[1:]:
                        if entry.startswith('#'): # Comment encountered
                            break
                        else:
                            ip_hosts[line_entry[0]] = ip_hosts.get(line_entry[0], []) + [entry]
                    for host in line_entry[1:]:
                        if host.startswith('#'): # Comment encountered
                            break
                        else:
                            host_ips[host] = host_ips.get(host, []) + [line_entry[0]]
    except FileNotFoundError:
        pass
    
    return ip_hosts, host_ips

def resolve_address(name, timeout=None):
    '''Resolve an ip address to a DNS name.'''
    if not timeout:
        timeout = 2

    resolved_hostnames = resolve_address_multi(addresses=[name], timeout=timeout)
    addresses = []

    if resolved_hostnames and resolved_hostnames.get(name):
        for hostname in resolved_hostnames[name]:
            addresses.append(hostname)
    
    return addresses

def reverse_dns(ip, timeout=None):
    '''Does a reverse DNS lookup on the given ip address. The ip must be in IPv4
        dotted decimal or IPv6 colon-separated decimal form.'''
    
    try:
        ip_address(ip)
    except ValueError:
        return

    if not timeout:
        timeout = 2
    
    resolved_host_names = reverse_dns_multi(addresses=[ip], timeout=timeout)
    if resolved_host_names and resolved_host_names.get(ip):
        host_names = resolved_host_names.get(ip)
    else:
        host_names = []
        
    return host_names



def resolve_address_multi(addresses, timeout=60):
    '''Performs a dns lookup of all the addresses specified. timeout defaults to 60.'''
    res = dns.resolver.Resolver()
    res.timeout = timeout
    res.lifetime = timeout

    results = {}
    
    for address in addresses:
        #try /etc/hosts first
        ip_hosts, host_ips = read_etc_hosts()
        if address in host_ips:
            results[address] = results.get(address, [])
            results[address] += host_ips[address]
    
        #v4 lookup
        try:
            v4_result = res.resolve(address, 'A')
            if v4_result:
                results[address] = results.get(address, [])
                for result in v4_result:
                    results[address].append(result.to_text())
        except Exception as e:
            #can not resolve #####add logging
            pass

        #v6 lookup
        try:
            v6_result = res.resolve(address, 'AAAA')
            if v6_result:
                results[address] = results.get(address, [])
                for result in v6_result:
                    results[address].append(result.to_text())
        except Exception as e:
            #can not resolve #####add logging
            pass

    return results

def reverse_dns_multi(addresses, timeout=60):
    '''Performs a reverse dns lookup of all the addresses specified. timeout defaults to 60.'''
    res = dns.resolver.Resolver()
    res.timeout = timeout
    res.lifetime = timeout
    results = {}
    for address in addresses:
        #try /etc/hosts first
        ip_hosts, host_ips = read_etc_hosts()

        if address in ip_hosts:
            results[address] = results.get(address, [])
            results[address] += ip_hosts[address]
        
        #dns reverse lookup
        try:
            resolver_result = res.query(dns.reversename.from_address(address), 'PTR')
            if resolver_result:
                results[address] = results.get(address, [])
                for result in resolver_result:
                    results[address].append(str(result).rstrip('.'))
        except Exception as e:
            #can not resolve #####add logging
            pass
    return results
    

def query_location(address):
    '''Returns the latitude and longitude of the specified address if it has a DNS LOC
        record. The return value is an array of the form
        (status, { latitude : latitude, longitude : longitude }). Where status is
        True on success, and False on error. Note: latitude and longitude may be None if
        the address has no LOC record.'''

    res = dns.resolver.Resolver()
    try:
        ans = res.resolve(address, 'LOC')
    except Exception as e:
        return (False, "Couldn't find location")
    
    #only one lat long
    if ans:
        latitude = ans[0].latitude
        longitude = ans[0].longitude
        return (True, {'latitude':latitude, 'longitude':longitude})
    
    return (True, {'latitude':None, 'longitude':None})

def discover_source_address(address, local_address=None, force_ipv4=None, force_ipv6=None):
    # Create a UDP socket destined for the specified address
    sock = None
    if not force_ipv4:
        sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    if not (sock or force_ipv6):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    
    ######port for local_address bind? default bind to 80?
    if local_address:
        sock.bind((local_address, 80))
    sock.connect((address, 80))

    #Grab the local end of the newly-created socket
    if not sock.getsockname():
        return

    #return only ip
    return sock.getsockname()[0]

