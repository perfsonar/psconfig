%define install_base        /usr/lib/perfsonar/
%define psconfig_base       %{install_base}/psconfig/
%define psconfig_bin_base   %{install_base}/bin
%define command_base        %{psconfig_bin_base}/psconfig_commands
%define config_base         /etc/perfsonar/psconfig
%define doc_base            /usr/share/doc/perfsonar/psconfig
%define publish_web_dir            /usr/lib/perfsonar/web-psconfig

%define bin_pscheduler_agent        psconfig_pscheduler_agent
%define bin_maddash_agent           psconfig_maddash_agent
%define service_pscheduler_agent    psconfig-pscheduler-agent
%define service_maddash_agent       psconfig-maddash-agent

#Version variables set by automated scripts
%define perfsonar_auto_version 5.0.0
%define perfsonar_auto_relnum 0.a1.0

Name:			perfsonar-psconfig
Version:		%{perfsonar_auto_version}
Release:		%{perfsonar_auto_relnum}%{?dist}
Summary:		perfSONAR pSConfig Agents
License:		ASL 2.0
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		perfsonar-psconfig-%{version}.tar.gz
Requires:       python3
BuildRequires:  python3
BuildRequires:  python36-nose
BuildArch:		noarch


%description
A package that pulls in all the Mesh Configuration RPMs.

%package pscheduler
Summary:		pSConfig pScheduler Agent
Group:			Applications/Communications


%description pscheduler
The pSConfig pScheduler Agent downloads a centralized JSON file
describing the tests to run, and uses it to generate appropriate pScheduler tasks.

%pre pscheduler
/usr/sbin/groupadd -r perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfsonar-psconfig-%{version}

%build
make

%install
rm -rf %{buildroot}
make install INSTALL_ROOT=%{buildroot} 

%clean
rm -rf %{buildroot}

%post pscheduler
mkdir -p %{config_base}/pscheduler.d/

# %preun pscheduler
# %systemd_preun %{service_pscheduler_agent}.service

# %postun pscheduler
# %systemd_postun_with_restart %{service_pscheduler_agent}.service

%files pscheduler -f INSTALLED_FILES
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
#%config(noreplace) %{config_base}/pscheduler-agent.json
#%attr(0644,root,root) %{_unitdir}/%{service_pscheduler_agent}.service

%changelog
* Wed Feb 14 2018 andy@es.net 4.1-0.0.a1
- Initial spec file created
