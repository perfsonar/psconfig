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

Name:			perfsonar-psconfig-utils
Version:		%{perfsonar_auto_version}
Release:		%{perfsonar_auto_relnum}%{?dist}
Summary:		pSConfig Utilities
License:		ASL 2.0
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		%{name}-%{version}.tar.gz
BuildArch:		noarch
Requires:		perl
Requires:       perl-CHI
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
Requires:		perl(Term::ProgressBar)
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

%description
This package is the set of library and common command-line tools used for pSConfig

%pre
/usr/sbin/groupadd -r perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :


%prep
%setup -q -n %{name}-%{version}

%build


%install
rm -rf %{buildroot}
make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install
mkdir -p %{buildroot}/%{command_base}
mkdir -p %{buildroot}/%{doc_base}
mkdir -p %{buildroot}/%{doc_base}/transforms
mkdir -p %{buildroot}/%{_bindir}

ln -fs %{psconfig_bin_base}/psconfig %{buildroot}/%{_bindir}/psconfig

install -D -m 0644 doc/*.json %{buildroot}/%{doc_base}/
install -D -m 0644 doc/transforms/*.json %{buildroot}/%{doc_base}/transforms/

rm -rf %{buildroot}/%{install_base}/plugins/
rm -rf %{buildroot}/%{install_base}/scripts/
rm -rf %{buildroot}/%{install_base}/doc


%clean
rm -rf %{buildroot}


%post
mkdir -p /var/lib/perfsonar/psconfig
chown perfsonar:perfsonar /var/lib/perfsonar/psconfig
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar
mkdir -p %{config_base}/transforms.d
chown perfsonar:perfsonar %{config_base}/transforms.d
mkdir -p %{config_base}/archives.d
chown perfsonar:perfsonar %{config_base}/archives.d

%files
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%attr(0755,perfsonar,perfsonar) %{psconfig_bin_base}/psconfig
%attr(0755,perfsonar,perfsonar) %{command_base}/agentctl
%attr(0755,perfsonar,perfsonar) %{command_base}/agents
%attr(0755,perfsonar,perfsonar) %{command_base}/remote
%attr(0755,perfsonar,perfsonar) %{command_base}/translate
%attr(0755,perfsonar,perfsonar) %{command_base}/validate
%{install_base}/lib/perfSONAR_PS/PSConfig/*.pm
%{install_base}/lib/perfSONAR_PS/PSConfig/CLI/Constants.pm
%{doc_base}/*
%{_bindir}/psconfig

%changelog
* Wed Feb 14 2018 andy@es.net 4.1-0.0.a1
- Initial spec file created
