%define install_base        /usr/lib/perfsonar/
%define psconfig_base       %{install_base}/psconfig/
%define psconfig_bin_base   %{psconfig_base}/bin
%define psconfig_datadir    /var/lib/perfsonar/psconfig
%define command_base        %{psconfig_bin_base}/commands
%define template_base       %{psconfig_base}/templates
%define config_base         /etc/perfsonar/psconfig
%define doc_base            /usr/share/doc/perfsonar/psconfig
%define httpd_config_base   /etc/httpd/conf.d
%define publish_web_dir     /usr/lib/perfsonar/web-psconfig

# defining macros needed by SELinux
# SELinux policy type - Targeted policy is the default SELinux policy used in Red Hat Enterprise Linux.
%global selinuxtype targeted
# default boolean value needs to be changed to enable http proxy
%global selinuxbooleans httpd_can_network_connect=1

#Version variables set by automated scripts
%define perfsonar_auto_version 5.1.0
%define perfsonar_auto_relnum 0.a1.0

Name:			perfsonar-psconfig
Version:		%{perfsonar_auto_version}
Release:		%{perfsonar_auto_relnum}%{?dist}
Summary:		perfSONAR pSConfig
License:		ASL 2.0
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		perfsonar-psconfig-%{version}.tar.gz
BuildArch:		noarch

%description
The perfSONAR pSConfig tool for configuring tests and UI

%package -n python-perfsonar-psconfig
Summary:		perfSONAR pSConfig Python Libraries
Requires:       python3
Requires:       python-requests
Requires:       python-jsonschema >= 3.0
Requires:       python-pyjq >= 2.2.0
Requires:       python3-netifaces
Requires:       python-isodate
Requires:       python-dns
Requires:       python-file-read-backwards
BuildRequires:  python3
BuildRequires:  python3-setuptools
BuildArch:		noarch

%description -n python-perfsonar-psconfig
The perfSONAR pSConfig python libraries

%package pscheduler
Summary:		pSConfig pScheduler Agent
Requires:       python-perfsonar-psconfig
Requires:       python3-inotify
Requires:       perfsonar-common
%{?systemd_requires: %systemd_requires}
BuildRequires: systemd
BuildArch:		noarch

%description pscheduler
The pSConfig pScheduler Agent downloads a centralized JSON file
describing the tests to run, and uses it to generate appropriate pScheduler tasks.

%package grafana
Summary:		pSConfig pScheduler Agent
Requires:       python-perfsonar-psconfig
Requires:       python3-inotify
Requires:       perfsonar-common
%{?systemd_requires: %systemd_requires}
BuildRequires: systemd
BuildArch:		noarch

%description grafana
The pSConfig Grafana Agent downloads a centralized JSON file
describing the tests to run, and uses it to generate Grafana dashboards.

%package utils
Summary:		pSConfig Utilities
Requires:       python-perfsonar-psconfig
Requires:       python3-tqdm
BuildArch:		noarch

%description utils
This package is the set of common command-line tools used for pSConfig

%package publisher
Summary:		pSConfig pScheduler Publisher
Group:			Applications/Communications
Requires:		perfsonar-psconfig-utils = %{version}-%{release}
Requires:		httpd
Requires:		mod_ssl
Requires(post): httpd
%{?systemd_requires: %systemd_requires}
Requires:       selinux-policy-%{selinuxtype}
Requires(post): selinux-policy-%{selinuxtype}
BuildRequires:  selinux-policy-devel
%{?selinux_requires}

%description publisher
Environment for publishing pSConfig template files in standard way

%pre
/usr/sbin/groupadd -r perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfsonar-psconfig-%{version}

%build
make

%install
rm -rf %{buildroot}
make install PYTHON-ROOTPATH=%{buildroot} PERFSONAR-CONFIGPATH=%{buildroot}/%{config_base} PERFSONAR-ROOTPATH=%{buildroot}/%{psconfig_base} PERFSONAR-DATAPATH=%{buildroot}/%{psconfig_datadir} BINPATH=%{buildroot}/%{_bindir} HTTPD-CONFIGPATH=%{buildroot}/%{httpd_config_base}
mkdir -p %{buildroot}/%{_unitdir}/
install -m 644 systemd/* %{buildroot}/%{_unitdir}/

%clean
rm -rf %{buildroot}

%post pscheduler
mkdir -p %{config_base}/pscheduler.d/
chown perfsonar:perfsonar %{config_base}/pscheduler.d/
%systemd_post psconfig-pscheduler-agent.service
if [ "$1" = "1" ]; then
    systemctl enable --now psconfig-pscheduler-agent.service
fi

%post grafana
mkdir -p %{config_base}/grafana.d/
chown perfsonar:perfsonar %{config_base}/grafana.d/
%systemd_post psconfig-grafana-agent.service
if [ "$1" = "1" ]; then
    systemctl enable --now psconfig-grafana-agent.service
fi

%post utils
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar
mkdir -p %{config_base}/transforms.d
chown perfsonar:perfsonar %{config_base}/transforms.d
mkdir -p %{config_base}/archives.d
chown perfsonar:perfsonar %{config_base}/archives.d

%post publisher
# create publish directory
mkdir -p %{publish_web_dir}
chown -R perfsonar:perfsonar %{publish_web_dir}
chmod 755 %{publish_web_dir}

#enable httpd on fresh install
if [ "$1" = "1" ]; then
    #set SELinux booleans to allow httpd proxy to work
    %selinux_set_booleans -s %{selinuxtype} %{selinuxbooleans}
    systemctl enable httpd
fi
#reload httpd
systemctl restart httpd &>/dev/null || :

%preun pscheduler
%systemd_preun psconfig-pscheduler-agent.service

%preun grafana
%systemd_preun psconfig-grafana-agent.service

%postun pscheduler
%systemd_postun_with_restart psconfig-pscheduler-agent.service

%postun grafana
%systemd_postun_with_restart psconfig-grafana-agent.service

%files -n python-perfsonar-psconfig -f INSTALLED_FILES
%defattr(-,root,root)
%license LICENSE

%files pscheduler
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%dir /var/lib/perfsonar/psconfig
%attr(0755, perfsonar, perfsonar) %{psconfig_bin_base}/psconfig_pscheduler_agent 
%config(noreplace) %{config_base}/pscheduler-agent.json
%config(noreplace) %{config_base}/pscheduler-agent-logger.conf
%{_unitdir}/psconfig-pscheduler-agent.service
%attr(0755, perfsonar, perfsonar) %{command_base}/pscheduler-stats
%attr(0755, perfsonar, perfsonar) %{command_base}/pscheduler-tasks

%files grafana
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%attr(0755, perfsonar, perfsonar) %{psconfig_bin_base}/psconfig_grafana_agent 
%config(noreplace) %{config_base}/grafana-agent.json
%config(noreplace) %{config_base}/grafana-agent-logger.conf
%{template_base}/grafana.json.j2
%{_unitdir}/psconfig-grafana-agent.service
# %attr(0755, perfsonar, perfsonar) %{command_base}/grafana
# %attr(0755, perfsonar, perfsonar) %{command_base}/grafana-stats
# %attr(0755, perfsonar, perfsonar) %{command_base}/grafana-tasks

%files utils
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%attr(0755, perfsonar, perfsonar) %{psconfig_bin_base}/psconfig
%attr(0755, perfsonar, perfsonar) %{command_base}/agents
%attr(0755, perfsonar, perfsonar) %{command_base}/agentctl
%attr(0755, perfsonar, perfsonar) %{command_base}/remote
%attr(0755, perfsonar, perfsonar) %{command_base}/validate
%{_bindir}/psconfig

%files publisher
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%attr(0644, perfsonar, perfsonar) %{httpd_config_base}/apache-psconfig-publisher.conf
%attr(0755,perfsonar,perfsonar) %{command_base}/publish
%attr(0755,perfsonar,perfsonar) %{command_base}/published

%changelog
* Thu Sep 14 2023 andy@es.net 5.1.0-0.0.a1
- Initial spec file created