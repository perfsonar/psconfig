# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # Build up to 10 el7 machines. psconfig-el7-0 is the default that will be the primary and 
  # autostart. Subsequent machines will not autostart. Each will have a full pscheduler 
  # install and maddash-server. The souce will live under /vagrant. You can access 
  # /etc/perfsonar in the shared directory /vagrant-data/vagrant/{hostname}/etc/perfsonar. 
  # Port forwarding is setup and hosts are on a private network with static IPv4 and IPv6 
  # addresses
  (0..9).each do |i|
      config.vm.define "psconfig-el7-#{i}", primary: (i == 0), autostart: (i == 0) do |psconfig|
        # set box to official CentOS 7 image
        psconfig.vm.box = "centos/7"
        # explcitly set shared folder to virtualbox type. If not set will choose rsync 
        # which is just a one-way share that is less useful in this context
        psconfig.vm.synced_folder ".", "/vagrant", type: "virtualbox"
        # Set hostname
        psconfig.vm.hostname = "psconfig-el7-#{i}"
        
        # Enable IPv4. Cannot be directly before or after line that sets IPv6 address. Looks
        # to be a strange bug where IPv6 and IPv4 mixed-up by vagrant otherwise and one 
        #interface will appear not to have an address. If you look at network-scripts file
        # you will see a mangled result where IPv4 is set for IPv6 or vice versa
        psconfig.vm.network "private_network", ip: "10.0.0.1#{i}"
        
        # Setup port forwarding to apache
        psconfig.vm.network "forwarded_port", guest: 443, host: "1#{i}443", host_ip: "127.0.0.1"
        
        # Enable IPv6. Currently only supports setting via static IP. Address below in the
        # reserved local address range for IPv6
        psconfig.vm.network "private_network", ip: "fdac:218a:75e5:69c8::1#{i}"
        
        #Disable selinux
        psconfig.vm.provision "shell", inline: <<-SHELL
            sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
        SHELL
    
        #Install all requirements and perform initial setup
        psconfig.vm.provision "shell", inline: <<-SHELL
            # Create users
            /usr/sbin/groupadd perfsonar 2> /dev/null || :
            /usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :
            /usr/sbin/groupadd maddash 2> /dev/null || :
            /usr/sbin/useradd -g maddash -r -s /sbin/nologin -c "MaDDash User" -d /tmp maddash 2> /dev/null || :

            #setup directories first so don't conflict with rpms
            if ! [ -d /vagrant/vagrant-data/psconfig-el7-#{i}/etc/perfsonar ]; then
                rm -rf /vagrant/vagrant-data/psconfig-el7-#{i}/etc/perfsonar
            fi
            if ! [ -L /etc/perfsonar ]; then
                rm -rf /etc/perfsonar
            fi
            if ! [ -d /vagrant/vagrant-data/psconfig-el7-#{i}/usr/lib/perfsonar ]; then
                rm -rf /vagrant/vagrant-data/psconfig-el7-#{i}/usr/lib/perfsonar
            fi
            if ! [ -L /usr/lib/perfsonar ]; then
                rm -rf /usr/lib/perfsonar
            fi
            mkdir -p /vagrant/vagrant-data/psconfig-el7-#{i}/etc/perfsonar
            ln -fs /vagrant/vagrant-data/psconfig-el7-#{i}/etc/perfsonar /etc/perfsonar
            mkdir -p /vagrant/vagrant-data/psconfig-el7-#{i}/usr/lib/perfsonar
            ln -fs /vagrant/vagrant-data/psconfig-el7-#{i}/usr/lib/perfsonar /usr/lib/perfsonar
            
            # Create config directory - copy so changes are not in git
            mkdir -p /etc/perfsonar/psconfig
            cp /vagrant/etc/* /etc/perfsonar/psconfig/
            mkdir -p /etc/perfsonar/psconfig/pscheduler.d
            mkdir -p /etc/perfsonar/psconfig/maddash.d
            mkdir -p /etc/perfsonar/psconfig/transforms.d
            mkdir -p /etc/perfsonar/psconfig/archives.d
            
            yum install -y epel-release
            yum install -y  http://software.internet2.edu/rpms/el7/x86_64/RPMS.main/perfSONAR-repo-0.8-1.noarch.rpm
            yum clean all
            yum install -y perfSONAR-repo-staging perfSONAR-repo-nightly
            yum clean all
            yum install -y gcc\
                kernel-devel\
                kernel-headers\
                dkms\
                make\
                bzip2\
                nagios-plugins-perfsonar\
                perl\
                perl-devel\
                perl-ExtUtils-MakeMaker\
                pscheduler-bundle-full\
                pscheduler-test-snmpget\
                pscheduler-tool-pysnmp\
                perfsonar-graphs\
                GeoIP-data\
                perl-AppConfig\
                perl-B-Hooks-EndOfScope\
                perl-Business-ISBN\
                perl-Business-ISBN-Data\
                perl-CGI\
                perl-CGI-Ajax\
                perl-CGI-Session\
                perl-Class-Accessor\
                perl-Class-Factory-Util\
                perl-Class-Load\
                perl-Class-Singleton\
                perl-Clone\
                perl-Compress-Raw-Bzip2\
                perl-Compress-Raw-Zlib\
                perl-Config-General\
                perl-Curses\
                perl-Devel-Cover\
                perl-DBD-Pg\
                perl-DBI\
                perl-DB_File\
                perl-Data-OptList\
                perl-Data-UUID\
                perl-Data-Validate-Domain\
                perl-Data-Validate-IP\
                perl-Date-Manip\
                perl-DateTime\
                perl-DateTime-Format-Builder\
                perl-DateTime-Format-ISO8601\
                perl-DateTime-Format-Strptime\
                perl-DateTime-Locale\
                perl-DateTime-TimeZone\
                perl-Devel-GlobalDestruction\
                perl-Devel-PartialDump\
                perl-Digest\
                perl-Digest-HMAC\
                perl-Digest-MD5\
                perl-Digest-SHA\
                perl-Dist-CheckConflicts\
                perl-Email-Date-Format\
                perl-Encode-Locale\
                perl-Eval-Closure\
                perl-FCGI\
                perl-File-Listing\
                perl-FreezeThaw\
                perl-Geo-IP\
                perl-HTML-Parser\
                perl-HTML-Tagset\
                perl-HTTP-Cookies\
                perl-HTTP-Daemon\
                perl-HTTP-Date\
                perl-HTTP-Message\
                perl-HTTP-Negotiate\
                perl-Hash-Merge\
                perl-IO-Compress\
                perl-IO-HTML\
                perl-IO-Interface\
                perl-IO-Multiplex\
                perl-IO-Pipely\
                perl-IO-Socket-INET6\
                perl-IO-Socket-IP\
                perl-IO-Socket-SSL\
                perl-IO-Tty\
                perl-IPC-DirQueue\
                perl-IPC-Run\
                perl-Image-Base\
                perl-Image-Info\
                perl-Image-Xbm\
                perl-Image-Xpm\
                perl-JSON\
                perl-JSON-Validator\
                perl-JSON-XS\
                perl-LWP-MediaTypes\
                perl-LWP-Protocol-https\
                perl-Linux-Inotify2\
                perl-List-MoreUtils\
                perl-Log-Dispatch\
                perl-Log-Dispatch-FileRotate\
                perl-Log-Log4perl\
                perl-MIME-Lite\
                perl-MIME-Types\
                perl-MRO-Compat\
                perl-Mail-Sender\
                perl-Mail-Sendmail\
                perl-MailTools\
                perl-Math-Int64\
                perl-Module-Implementation\
                perl-Module-Load\
                perl-Module-Runtime\
                perl-Moose\
                perl-Mouse\
                perl-Mozilla-CA\
                perl-Net-CIDR\
                perl-Net-DNS\
                perl-Net-Daemon\
                perl-Net-Domain-TLD\
                perl-Net-HTTP\
                perl-Net-INET6Glue\
                perl-Net-IP\
                perl-Net-LibIDN\
                perl-Net-Netmask\
                perl-Net-SMTP-SSL\
                perl-Net-SSLeay\
                perl-Net-Server\
                perl-Net-Traceroute\
                perl-NetAddr-IP\
                perl-POE\
                perl-Package-DeprecationManager\
                perl-Package-Generator\
                perl-Package-Stash\
                perl-Package-Stash-XS\
                perl-Params-Util\
                perl-Params-Validate\
                perl-PlRPC\
                perl-Pod-POM\
                perl-RPC-XML\
                perl-RPM2\
                perl-Regexp-Common\
                perl-Socket6\
                perl-Statistics-Descriptive\
                perl-Sub-Exporter\
                perl-Sub-Exporter-Progressive\
                perl-Sub-Install\
                perl-Sub-Name\
                perl-Sys-Statistics-Linux\
                perl-Template-Toolkit\
                perl-TermReadKey\
                perl-Test-Harness\
                perl-Test-Simple\
                perl-TimeDate\
                perl-Try-Tiny\
                perl-Types-Serialiser\
                perl-URI\
                perl-Variable-Magic\
                perl-WWW-RobotRules\
                perl-XML-DOM\
                perl-XML-LibXML\
                perl-XML-NamespaceSupport\
                perl-XML-Parser\
                perl-XML-RegExp\
                perl-XML-SAX\
                perl-XML-SAX-Base\
                perl-XML-Simple\
                perl-YAML-Syck\
                perl-common-sense\
                perl-libwww-perl\
                perl-namespace-clean\
                perl-version\
                perltidy\
                maddash\
                perl-Cache-Memcached\
                perl-Class-XSAccessor\
                perl-Config-Tiny\
                perl-File-BaseDir\
                perl-File-DesktopEntry\
                perl-File-MimeInfo\
                perl-File-ReadBackwards\
                perl-IO-All\
                perl-IO-String\
                perl-Math-Calc-Units\
                perl-Mo\
                perl-Nagios-Plugin\
                perl-PPI\
                perl-String-CRC32\
                perl-Task-Weaken\
                perl-YAML
                
            # Create bin directory
            mkdir -p /usr/lib/perfsonar/bin
            ln -fs /vagrant/bin/psconfig_maddash_agent /usr/lib/perfsonar/bin/psconfig_maddash_agent
            ln -fs /vagrant/bin/psconfig_pscheduler_agent /usr/lib/perfsonar/bin/psconfig_pscheduler_agent
            ln -fs /vagrant/bin/psconfig /usr/lib/perfsonar/bin/psconfig
            if ! [ -L /usr/lib/perfsonar/bin/psconfig_commands ]; then
                mv /usr/lib/perfsonar/bin/psconfig_commands /usr/lib/perfsonar/bin/psconfig_commands.bak
                ln -fs /vagrant/bin/psconfig_commands /usr/lib/perfsonar/bin/psconfig_commands
            fi
            ln -fs /vagrant/bin/psconfig /usr/bin/psconfig
            chown -R perfsonar:perfsonar /usr/lib/perfsonar/

            # Create plugin directory
            if ! [ -L /usr/lib/perfsonar/psconfig ]; then
                mv /usr/lib/perfsonar/psconfig /usr/lib/perfsonar/psconfig.bak
                ln -fs /vagrant/plugins /usr/lib/perfsonar/psconfig
            fi
            
            # Create doc directory
            mkdir -p /usr/share/doc/perfsonar
            ln -fs /vagrant/doc /usr/share/doc/perfsonar/psconfig

            # Create log directories
            mkdir -p /var/log/perfsonar/
            mkdir -p /var/log/maddash/
            ln -fs /var/log/maddash/psconfig-maddash.log /var/log/perfsonar/psconfig-maddash.log
            chown -R perfsonar:perfsonar /var/log/perfsonar/
            chown -R maddash:maddash /var/log/maddash/

            # Create data directory
            mkdir -p /var/lib/perfsonar/psconfig
            chown -R perfsonar:perfsonar /var/lib/perfsonar/
            
        SHELL
      end
  end
end
