package perfSONAR_PS::PSConfig::MaDDash::DefaultReports;

use strict;
use warnings;

our $VERSION = 4.1;

use YAML qw(Load);

use base 'Exporter';

our @EXPORT_OK = qw( load_default_reports );


sub load_default_reports {
    my $yaml = <<REPORT;
reports:
    -
        id: "meshconfig_mesh_throughput"
        rule:
            type: matchFirst
            rules:
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 3
                    problem:
                        severity: 3
                        category: CONFIGURATION
                        message: "Grid is down" 
                        solutions:
                            - "If you just configured this grid in the mesh, you may just need to wait as it takes several hours for throughput data to populate (depending on the interval between tests)"
                            - "Verify maddash is configured properly. Look in the files under /var/log/maddash/ for any errors. Things to look for are incorrect paths to checks or connection errors."
                            - "Verify that perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"                            
                            - "Verify that your measurement archive(s) are running"
                            - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                            - "Verify your hosts are downloading the mesh configuration file and that there are tests defined in /etc/perfsonar/meshconfig-agent-tasks.conf"
                            - "Verify that perfsonar-meshconfig-agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                            - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log"                            
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 0
                    problem:
                        severity: 0
                        category: PERFORMANCE
                        message: "Entire grid has OK status."
                - 
                    type: forEachSite
                    rule:
                        type: matchFirst
                        rules:
                            - 
                                type: rule
                                selector:
                                    type: site
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Site is down"
                                    solutions:
                                        - "Verify the host is up"
                                        - "If recently added to the mesh, verify the mesh config file has been downloaded by the end-hosts since the update. It may also take several hours for the first throughput test to run on this host."
                                        - "If recently removed from the mesh, verify that the perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"
                                        - "Verify NTP is synced on this host" 
                                        - "Verify the local and remote sites allow access to TCP port 443 and TCP/UDP port 5201"                           
                            - 
                                type: rule
                                selector:
                                    type: row
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Unable to run and/or query any outgoing throughput tests."
                                    solutions:
                                        - "Verify you are not blocking any of the required outgoing throughput ports in your firewall"
                                        - "Verify the remote sites allow your host to access TCP port 443 and TCP/UDP port 5201"
                                        - "Verify the limits defined in /etc/pscheduler/limits.conf on each side are properly defined and not being exceeded by the tests"
                            - 
                                type: rule
                                selector:
                                    type: column
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Unable to run and/or query any incoming throughput tests."
                                    solutions:
                                        - "Verify your host and router firewalls are allowing TCP port 443 and TCP/UDP port 5201"
                                        - "Verify the limits defined in /etc/pscheduler/limits.conf are properly defined and not being exceeded by the tests"
                            - 
                                type: matchAll
                                rules:
                                    - 
                                        type: matchFirst
                                        rules: 
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 0
                                                    colIndex: 1
                                                match:
                                                    type: status
                                                    status: 3
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated at this site are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Verify that your measurement archive(s) are running"
                                                        - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                                                        - "Verify your hosts are downloading the mesh configuration file and that there are tests defined in /etc/perfsonar/meshconfig-agent-tasks.conf"
                                                        - "Verify that MeshConfig Agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                                                        - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log" 
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 0
                                                    colIndex: 1
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "A majority (but not all) of tests initiated by this site are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Check if the sites that are failing are blocking TCP port 443 or TCP/UDP port 5201."
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                                        
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 0
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated at this site are failing in the outgoing direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    colIndex: 1
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated at this site are failing in the incoming direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                    - 
                                        type: matchFirst
                                        rules: 
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 1
                                                    colIndex: 0
                                                match:
                                                    type: status
                                                    status: 3
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated by remote sites are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Verify that the local site has TCP port 443 is open on the host and router firewalls"
                                                        - "Verify that pscheduler is running on the host with '/etc/init.d/pscheduler status'"
                                                        - "Verify the limits defined in /etc/pscheduler/limits.conf are properly defined and not being exceeded by the tests"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 1
                                                    colIndex: 0
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "A majority (but not all) of tests initiated by remote sites are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Verify that the local site has TCP port 443 open on the host and router firewalls to all hosts in the mesh"
                                                        - "Verify the limits defined in /etc/pscheduler/limits.conf are properly defined and not being exceeded by the tests"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 1
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated by remote sites are failing in the outgoing direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    colIndex: 0
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated by remote sites are failing in the incoming direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                    -
                                        type: rule
                                        selector:
                                            type: row
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Outgoing throughput is below warning or critical thresholds to a majority of sites"
                                    - 
                                        type: rule
                                        selector:
                                            type: column
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Incoming throughput is below warning or critical thresholds to a majority of sites"
    -
        id: "meshconfig_disjoint_throughput"
        rule:
            type: matchFirst
            rules:
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 3
                    problem:
                        severity: 3
                        category: CONFIGURATION
                        message: "Grid is down" 
                        solutions:
                            - "If you just configured this grid in the mesh, you may just need to wait as it takes several hours for throughput data to populate (depending on the interval between tests)"
                            - "Verify maddash is configured properly. Look in the files under /var/log/maddash/ for any errors. Things to look for are incorrect paths to checks or connection errors."
                            - "Verify that the perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"                            
                            - "Verify that your measurement archive(s) are running"
                            - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                            - "Verify your hosts are downloading the mesh configuration file and that there are tests defined in /etc/perfsonar/meshconfig-agent-tasks.conf"
                            - "Verify that MeshConfig Agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                            - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log"                            
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 0
                    problem:
                        severity: 0
                        category: PERFORMANCE
                        message: "Entire grid has OK status."
                - 
                    type: forEachSite
                    rule:
                        type: matchFirst
                        rules:
                            - 
                                type: rule
                                selector:
                                    type: site
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Site is down"
                                    solutions:
                                        - "Verify the host is up"
                                        - "Verify the local and remote sites allow access to TCP port 443 and TCP/UDP port 5201" 
                                        - "If recently added to the mesh, verify the mesh config file has been downloaded by the end-hosts since the update. It may also take several hours for the first BWCTL test to run on this host."
                                        - "If recently removed from the mesh, verify that the perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"
                                        - "Verify NTP is synced on this host"                                                                   
                                        - "Verify that your measurement archive(s) are running"
                                        - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                                        - "Verify that MeshConfig Agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                                        - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log" 
                            - 
                                type: matchAll
                                rules:
                                    - 
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 0
                                            colIndex: 1
                                        match:
                                            type: statusThreshold
                                            status: 3
                                            threshold: .6
                                        problem:
                                            severity: 3
                                            category: CONFIGURATION
                                            message: "Tests are failing in the outgoing direction"
                                            solutions:
                                                - "Verify the local and remote sites allow access to TCP port 443 and TCP/UDP ports 5201 in their host and router firewalls"
                                    - 
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 1
                                            colIndex: 0
                                        match:
                                            type: statusThreshold
                                            status: 3
                                            threshold: .6
                                        problem:
                                            severity: 3
                                            category: CONFIGURATION
                                            message: "Tests are failing in the incoming direction"
                                            solutions:
                                                - "Verify the local and remote sites allow access to TCP port 443 and TCP/UDP ports 5201 in their host and router firewalls"
                                    -
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 0
                                            colIndex: 1
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Outgoing throughput is below warning or critical thresholds to a majority of sites"
                                    - 
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 1
                                            colIndex: 0
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Incoming throughput is below warning or critical thresholds to a majority of sites"
    -
        id: "meshconfig_mesh_loss"
        rule:
            type: matchFirst
            rules:
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 3
                    problem:
                        severity: 3
                        category: CONFIGURATION
                        message: "Grid is down" 
                        solutions:
                            - "If you just configured this grid in the mesh, you may just need to wait as it takes a few minutes for loss data to populate"
                            - "Verify maddash is configured properly. Look in the files under /var/log/maddash/ for any errors. Things to look for are incorrect paths to checks or connection errors."
                            - "Verify that the perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"                            
                            - "Verify that your measurement archive(s) are running"
                            - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                            - "Verify your hosts are downloading the mesh configuration file and that there are tests defined in /etc/perfsonar/meshconfig-agent-tasks.conf"
                            - "Verify that MeshConfig Agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                            - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log"                            
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 0
                    problem:
                        severity: 0
                        category: PERFORMANCE
                        message: "Entire grid has OK status"
                - 
                    type: forEachSite
                    rule:
                        type: matchFirst
                        rules:
                            - 
                                type: rule
                                selector:
                                    type: site
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Site is down"
                                    solutions:
                                        - "Verify the host is up"
                                        - "If recently added to the mesh, verify the mesh config file has been downloaded by the end-hosts since the update."
                                        - "If recently removed from the mesh, verify that the perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"
                                        - "Verify the local and remote sites allow access to TCP port 861 and UDP ports 8760-9960"                           
                            - 
                                type: rule
                                selector:
                                    type: row
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Unable to run and/or query any outgoing one-way delay tests."
                                    solutions:
                                        - "Verify you are not blocking any of the required outgoing OWAMP ports in your firewall"
                                        - "Verify the remote sites allow your host to access UDP ports 8760-9960"
                            - 
                                type: rule
                                selector:
                                    type: column
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Unable to run and/or query any incoming one-way delay tests."
                                    solutions:
                                        - "Verify your host and router firewalls are allowing UDP ports 8760-9960"
                            - 
                                type: matchAll
                                rules:
                                    - 
                                        type: matchFirst
                                        rules: 
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 0
                                                    colIndex: 1
                                                match:
                                                    type: status
                                                    status: 3
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated at this site are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Verify that your measurement archive(s) are running"
                                                        - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                                                        - "Verify your hosts are downloading the mesh configuration file and that there are tests defined in /etc/perfsonar/meshconfig-agent-tasks.conf"
                                                        - "Verify that MeshConfig Agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                                                        - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log" 
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 0
                                                    colIndex: 1
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "A majority (but not all) of tests initiated by this site are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Check if the sites that are failing are blocking TCP port 861."
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                                        
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 0
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated at this site are failing in the outgoing direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    colIndex: 1
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated at this site are failing in the incoming direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                    - 
                                        type: matchFirst
                                        rules: 
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 1
                                                    colIndex: 0
                                                match:
                                                    type: status
                                                    status: 3
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated by remote sites are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Verify that the local site has TCP port 861 open on the host and router firewalls"
                                                        - "Verify that owamp-server is running on the host with '/etc/init.d/owamp-server status' or 'systemctl status owamp-server'"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 1
                                                    colIndex: 0
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "A majority (but not all) of tests initiated by remote sites are failing in both incoming and outgoing directions"
                                                    solutions:
                                                        - "Verify that the local site has TCP port 861 open on the host and router firewalls to all hosts in the mesh"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    rowIndex: 1
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated by remote sites are failing in the outgoing direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                            - 
                                                type: rule
                                                selector:
                                                    type: check
                                                    colIndex: 0
                                                match:
                                                    type: statusThreshold
                                                    status: 3
                                                    threshold: .6
                                                problem:
                                                    severity: 3
                                                    category: CONFIGURATION
                                                    message: "Tests initiated by remote sites are failing in the incoming direction"
                                                    solutions:
                                                        - "Verify that /var/log/perfsonar/meshconfig-agent.log does not contain any errors."
                                                        - "Verify that /etc/perfsonar/meshconfig-agent-tasks.conf contains the proper tests"
                                                        - "Restart perfsonar-meshconfig-agent, it may not have picked-up configuration changes ('/etc/init.d/perfsonar-meshconfig-agent restart' or 'systemctl restart perfsonar-meshconfig-agent')"
                                    -
                                        type: rule
                                        selector:
                                            type: row
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Outgoing loss is above warning or critical thresholds to a majority of sites"
                                    - 
                                        type: rule
                                        selector:
                                            type: column
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Incoming loss is above warning or critical thresholds to a majority of sites"
    -
        id: "meshconfig_disjoint_loss"
        rule:
            type: matchFirst
            rules:
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 3
                    problem:
                        severity: 3
                        category: CONFIGURATION
                        message: "Grid is down" 
                        solutions:
                            - "If you just configured this grid in the mesh, you may just need to wait as it takes a few minutes for one-way delay data to populate"
                            - "Verify maddash is configured properly. Look in the files under /var/log/maddash/ for any errors. Things to look for are incorrect paths to checks or connection errors."
                            - "Verify that the perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"                            
                            - "Verify that your measurement archive(s) are running"
                            - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                            - "Verify your hosts are downloading the mesh configuration file and that there are tests defined in /etc/perfsonar/meshconfig-agent-tasks.conf"
                            - "Verify that MeshConfig Agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                            - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log"                            
                - 
                    type: rule
                    selector:
                        type: grid
                    match:
                        type: status
                        status: 0
                    problem:
                        severity: 0
                        category: PERFORMANCE
                        message: "Entire grid has OK status"
                - 
                    type: forEachSite
                    rule:
                        type: matchFirst
                        rules:
                            - 
                                type: rule
                                selector:
                                    type: site
                                match:
                                    type: status
                                    status: 3                        
                                problem:
                                    severity: 3
                                    category: CONFIGURATION
                                    message: "Site is down"
                                    solutions:
                                        - "Verify the host is up"
                                        - "Verify the local and remote sites allow access to TCP port 861 and UDP ports 8760-9960 through their host and router firewalls" 
                                        - "If recently added to the mesh, verify the mesh config file has been downloaded by the end-hosts since the update."
                                        - "If recently removed from the mesh, verify that the perfSONAR MeshConfig GUIAgent has run recently and you are looking at an accurate test mesh"
                                        - "Verify NTP is synced on this host"                                                                   
                                        - "Verify that your measurement archive(s) are running"
                                        - "Verify no firewall is blocking maddash from reaching your measurement archive(s)"
                                        - "Verify that MeshConfig Agent is running ('/etc/init.d/perfsonar-meshconfig-agent status' or 'systemctl status perfsonar-meshconfig-agent')"
                                        - "Verify your hosts are able to reach their configured measurement archive and that there are no errors in /var/log/perfsonar/meshconfig-agent.log" 
                            - 
                                type: matchAll
                                rules:                                    
                                    - 
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 0
                                            colIndex: 1
                                        match:
                                            type: statusThreshold
                                            status: 3
                                            threshold: .6
                                        problem:
                                            severity: 3
                                            category: CONFIGURATION
                                            message: "Tests are failing in the outgoing direction"
                                            solutions:
                                                - "Verify the local and remote sites allow access to TCP port 861 and UDP ports 8760-9960 in their host and router firewalls"
                                    - 
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 1
                                            colIndex: 0
                                        match:
                                            type: statusThreshold
                                            status: 3
                                            threshold: .6
                                        problem:
                                            severity: 3
                                            category: CONFIGURATION
                                            message: "Tests are failing in the incoming direction"
                                            solutions:
                                                - "Verify the local and remote sites allow access to TCP port 861 and UDP ports 8760-9960 in their host and router firewalls"
                                    -
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 0
                                            colIndex: 1
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Outgoing loss is above warning or critical thresholds to a majority of sites"
                                    - 
                                        type: rule
                                        selector:
                                            type: check
                                            rowIndex: 1
                                            colIndex: 0
                                        match:
                                            type: statusWeightedThreshold
                                            statuses: 
                                                - 0.0
                                                - .5
                                                - 1.0
                                                - -1.0
                                            threshold: .6
                                        problem:
                                            severity: 2
                                            category: PERFORMANCE
                                            message: "Incoming loss is above warning or critical thresholds to a majority of sites"

REPORT

    return Load($yaml)->{reports};
    
}