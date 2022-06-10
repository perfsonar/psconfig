%define install_base        /usr/lib/perfsonar/
%define config_base         /etc/perfsonar/psconfig

#Version variables set by automated scripts
%define perfsonar_auto_version 5.0.0
%define perfsonar_auto_relnum 0.a1.0

Name:			perfsonar-psconfig-pscheduler-devel
Version:		%{perfsonar_auto_version}
Release:		%{perfsonar_auto_relnum}%{?dist}
Summary:		Libraries for interacting with the pSConfig pScheduler Agent
License:		ASL 2.0
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		%{name}-%{version}.tar.gz
BuildArch:		noarch
Requires:		libperfsonar-pscheduler-perl

%description
Libraries for interacting with the pSConfig pScheduler Agent

%pre
/usr/sbin/groupadd -r perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n %{name}-%{version}

%build

%install
rm -rf %{buildroot}
make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install

%clean
rm -rf %{buildroot}

%files
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%{install_base}/lib/perfSONAR_PS/PSConfig/PScheduler/*

%changelog
* Wed Feb 14 2018 andy@es.net 4.1-0.0.a1
- Initial spec file created
