%define install_base        /usr/lib/perfsonar/
%define psconfig_base       %{install_base}/psconfig/
%define psconfig_bin_base   %{install_base}/bin
%define command_base        %{psconfig_bin_base}/psconfig_commands
%define config_base         /etc/perfsonar/psconfig
%define doc_base            /usr/share/doc/perfsonar/psconfig

%define bin_pscheduler_agent        psconfig_pscheduler_agent
%define bin_maddash_agent           psconfig_maddash_agent
%define service_pscheduler_agent    psconfig-pscheduler-agent
%define service_maddash_agent       psconfig-maddash-agent


%define relnum 0.1.a1 


Name:			perfsonar-psconfig
Version:		4.1
Release:		%{relnum}%{?dist}
Summary:		perfSONAR pSConfig Agents
License:		Distributable, see LICENSE
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		perfsonar-psconfig-%{version}.%{relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:		noarch


%description
A package that pulls in all the Mesh Configuration RPMs.


%package utils
Summary:		pSConfig Utilities
Group:			Applications/Communications
Requires:		perl
Requires:		perl(Data::Dumper)
Requires:		perl(Data::Validate::Domain)
Requires:		perl(Data::Validate::IP)
Requires:		perl(English)
Requires:		perl(Exporter)
Requires:		perl(File::Basename)
Requires:		perl(FindBin)
Requires:		perl(Getopt::Long)
Requires:		perl(JSON)
Requires:		perl(JSON::Validator)
Requires:		perl(Log::Log4perl)
Requires:		perl(Module::Load)
Requires:		perl(Mouse)
Requires:		perl(POSIX)
Requires:		perl(Params::Validate)
Requires:		perl(Pod::Usage)
Requires:		perl(Regexp::Common)
Requires:		perl(URI)
Requires:		perl(base)
Requires:		perl(lib)
Requires:		perl(vars)
Requires:		perl(warnings)
Requires:		coreutils
Requires:		shadow-utils
Requires:       libperfsonar-psconfig-perl
%{?systemd_requires: %systemd_requires}
BuildRequires: systemd


%description utils
This package is the set of library and common command-line tools used for pSConfig


%package pscheduler
Summary:		pSConfig pScheduler Agent
Group:			Applications/Communications
Requires:		perfsonar-psconfig-utils = %{version}-%{release}
Requires(post):	perfsonar-psconfig-utils = %{version}-%{release}
Requires:       libperfsonar-pscheduler-perl
Requires:       perl(Linux::Inotify2)
Obsoletes:      perfsonar-meshconfig-agent
Provides:       perfsonar-meshconfig-agent

%description pscheduler
The pSConfig pScheduler Agent downloads a centralized JSON file
describing the tests to run, and uses it to generate appropriate pScheduler tasks.


%package maddash
Summary:		pSConfig MaDDash Agent
Group:			Applications/Communications
Requires:		perfsonar-psconfig-utils = %{version}-%{release}
Requires(post):	perfsonar-psconfig-utils = %{version}-%{release}
Requires:		maddash-server
Requires:       perfsonar-graphs
Requires:       nagios-plugins-perfsonar
Requires:       perfsonar-traceroute-viewer
Requires:       perl(Mo)
Requires:       perl(YAML)
Requires:       perl(Linux::Inotify2)
Obsoletes:      perfsonar-meshconfig-guiagent
Provides:       perfsonar-meshconfig-guiagent

%description maddash
The pSConfig MaDDash Agent downloads a centralized JSON file
describing the tests a mesh is running, and generates a MaDDash configuration.


%pre utils
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :


%pre pscheduler
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :


%pre maddash
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :
/usr/sbin/groupadd maddash 2> /dev/null || :
/usr/sbin/useradd -g maddash -r -s /sbin/nologin -c "MaDDash User" -d /tmp maddash 2> /dev/null || :


%prep
%setup -q -n perfsonar-psconfig-%{version}.%{relnum}


%build


%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install
mkdir -p %{buildroot}/%{psconfig_base}/checks
mkdir -p %{buildroot}/%{psconfig_base}/reports
mkdir -p %{buildroot}/%{psconfig_base}/visualization
mkdir -p %{buildroot}/%{command_base}
mkdir -p %{buildroot}/%{doc_base}
mkdir -p %{buildroot}/%{doc_base}/transforms
mkdir -p %{buildroot}/%{_bindir}

install -D -m 0644 scripts/%{service_pscheduler_agent}.service %{buildroot}/%{_unitdir}/%{service_pscheduler_agent}.service
install -D -m 0644 scripts/%{service_maddash_agent}.service %{buildroot}/%{_unitdir}/%{service_maddash_agent}.service

install -D -m 0644 plugins/checks/* %{buildroot}/%{psconfig_base}/checks/
install -D -m 0644 plugins/reports/* %{buildroot}/%{psconfig_base}/reports/
install -D -m 0644 plugins/visualization/* %{buildroot}/%{psconfig_base}/visualization/

ln -fs %{psconfig_bin_base}/psconfig %{buildroot}/%{_bindir}/psconfig

install -D -m 0644 doc/*.json %{buildroot}/%{doc_base}/
install -D -m 0644 doc/transforms/*.json %{buildroot}/%{doc_base}/transforms/

rm -rf %{buildroot}/%{install_base}/plugins/
rm -rf %{buildroot}/%{install_base}/scripts/
rm -rf %{buildroot}/%{install_base}/doc


%clean
rm -rf %{buildroot}


%post utils
mkdir -p /var/lib/perfsonar/psconfig
chown perfsonar:perfsonar /var/lib/perfsonar/psconfig

mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar
mkdir -p %{config_base}/transforms.d
chown perfsonar:perfsonar %{config_base}/transforms.d
mkdir -p %{config_base}/archives.d
chown perfsonar:perfsonar %{config_base}/archives.d


%post pscheduler
mkdir -p %{config_base}/pscheduler.d/
chown perfsonar:perfsonar %{config_base}/pscheduler.d/
%systemd_post %{service_pscheduler_agent}.service
if [ "$1" = "1" ]; then
    #migrate meshconfig
    psconfig pscheduler-migrate
    #if new install, then enable
    systemctl enable %{service_pscheduler_agent}.service
    systemctl start %{service_pscheduler_agent}.service
fi


%post maddash
mkdir -p %{config_base}/maddash.d
chown perfsonar:perfsonar %{config_base}/maddash.d
mkdir -p %{psconfig_base}/checks
chown perfsonar:perfsonar %{psconfig_base}/checks
mkdir -p %{psconfig_base}/reports
chown perfsonar:perfsonar %{psconfig_base}/reports
mkdir -p %{psconfig_base}/visualization
chown perfsonar:perfsonar %{psconfig_base}/visualization
%systemd_post %{service_maddash_agent}.service
if [ "$1" = "1" ]; then
    #migrate meshconfig
    psconfig maddash-migrate
    #if new install, then enable
    systemctl enable %{service_maddash_agent}.service
    systemctl start %{service_maddash_agent}.service
fi


#symlink for convenience
ln -s /var/log/maddash/psconfig-maddash-agent.log /var/log/perfsonar/psconfig-maddash-agent.log &>/dev/null || :


%preun pscheduler
%systemd_preun %{service_pscheduler_agent}.service


%postun pscheduler
%systemd_postun_with_restart %{service_pscheduler_agent}.service


%preun maddash
%systemd_preun %{service_maddash_agent}.service


%postun maddash
%systemd_postun_with_restart %{service_maddash_agent}.service


%files utils
%defattr(0644,perfsonar,perfsonar,0755)
%attr(0755,perfsonar,perfsonar) %{psconfig_bin_base}/psconfig
%attr(0755,perfsonar,perfsonar) %{command_base}/agents
%attr(0755,perfsonar,perfsonar) %{command_base}/remote
%attr(0755,perfsonar,perfsonar) %{command_base}/translate
%attr(0755,perfsonar,perfsonar) %{command_base}/validate
%{install_base}/lib/perfSONAR_PS/PSConfig/*.pm
%{install_base}/lib/perfSONAR_PS/PSConfig/CLI/Constants.pm
%{doc_base}/*
%{_bindir}/psconfig


%files pscheduler
%defattr(0644,perfsonar,perfsonar,0755)
%config(noreplace) %{config_base}/pscheduler-agent.json
%config(noreplace) %{config_base}/pscheduler-agent-logger.conf
%attr(0755,perfsonar,perfsonar) %{psconfig_bin_base}/%{bin_pscheduler_agent}
%attr(0755,perfsonar,perfsonar) %{command_base}/pscheduler-*
%attr(0644,root,root) %{_unitdir}/%{service_pscheduler_agent}.service
%{install_base}/lib/perfSONAR_PS/PSConfig/PScheduler/*


%files maddash
%defattr(0644,perfsonar,perfsonar,0755)
%config(noreplace) %{config_base}/maddash-agent.json
%config(noreplace) %{config_base}/maddash-agent-logger.conf
%attr(0755,perfsonar,perfsonar) %{psconfig_bin_base}/%{bin_maddash_agent}
%attr(0755,perfsonar,perfsonar) %{command_base}/maddash-*
%attr(0644,root,root) %{_unitdir}/%{service_maddash_agent}.service
%{install_base}/lib/perfSONAR_PS/PSConfig/MaDDash/*
%{install_base}/lib/perfSONAR_PS/PSConfig/CLI/MaDDash.pm
%{psconfig_base}/checks/*
%{psconfig_base}/reports/*
%{psconfig_base}/visualization/*


%changelog
* Wed Feb 14 2018 andy@es.net 4.1-0.0.a1
- Initial spec file created
