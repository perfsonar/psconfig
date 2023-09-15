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
%define perfsonar_auto_version 5.1.0
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
Requires:       python-requests
Requires:       python-jsonschema >= 3.0
Requires:       python-pyjq >= 2.2.0
Requires:       python-isodate
Requires:       python-dns
BuildRequires:  python3
BuildRequires:  python3-setuptools
BuildArch:		noarch


%description
A package that pulls in all the pSConfig python RPMS.

%pre
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

%post
mkdir -p %{config_base}/pscheduler.d/

%files -f INSTALLED_FILES
%defattr(-,root,root)
%license LICENSE

%changelog
* Thu Sep 14 2023 andy@es.net 5.1.0-0.0.a1
- Initial spec file created
