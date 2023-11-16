###
# Packages:
#   - python-perfsonar-psconfig
#   - perfsonar-psconfig-pscheduler
#   - perfsonar-psconfig-grafana
#   - perfsonar-psconfig-publisher (maybe merge with utils?)
#   - perfsonar-psconfig-utils
###

%define install_base        /usr/lib/perfsonar/
%define psconfig_base       %{install_base}/psconfig/
%define psconfig_bin_base   %{psconfig_base}/bin
%define psconfig_datadir    /var/lib/perfsonar/psconfig
%define command_base        %{psconfig_bin_base}/commands
%define config_base         /etc/perfsonar/psconfig
%define doc_base            /usr/share/doc/perfsonar/psconfig
%define publish_web_dir     /usr/lib/perfsonar/web-psconfig

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

%package utils
Summary:		pSConfig Utilities
Requires:       python-perfsonar-psconfig
BuildArch:		noarch

%description utils
This package is the set of common command-line tools used for pSConfig

%pre
/usr/sbin/groupadd -r perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfsonar-psconfig-%{version}

%build
make

%install
rm -rf %{buildroot}
make install PYTHON-ROOTPATH=%{buildroot} PERFSONAR-CONFIGPATH=%{buildroot}/%{config_base} PERFSONAR-ROOTPATH=%{buildroot}/%{psconfig_base} PERFSONAR-DATAPATH=%{buildroot}/%{psconfig_datadir} BINPATH=%{buildroot}/%{_bindir}
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

%preun pscheduler
%systemd_preun psconfig-pscheduler-agent.service

%postun pscheduler
%systemd_postun_with_restart psconfig-pscheduler-agent.service

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

%files utils
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%attr(0755, perfsonar, perfsonar) %{psconfig_bin_base}/psconfig
%attr(0755, perfsonar, perfsonar) %{psconfig_bin_base}/commands/agents
%attr(0755, perfsonar, perfsonar) %{psconfig_bin_base}/commands/agentctl
%attr(0755, perfsonar, perfsonar) %{psconfig_bin_base}/commands/remote
%{_bindir}/psconfig

%changelog
* Thu Sep 14 2023 andy@es.net 5.1.0-0.0.a1
- Initial spec file created
