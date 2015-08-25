%define install_base /opt/perfsonar_ps/mesh_config

%define crontab_1 cron-mesh_config_agent
%define crontab_2 cron-mesh_config_gui_agent

%define relnum 0.7.rc2 
%define disttag pSPS

Name:			perl-perfSONAR_PS-MeshConfig
Version:		3.5
Release:		%{relnum}.%{disttag}
Summary:		perfSONAR_PS Mesh Configuration Agent
License:		Distributable, see LICENSE
Group:			Development/Libraries
URL:			http://search.cpan.org/dist/perfSONAR_PS-MeshConfig/
Source0:		perfSONAR_PS-MeshConfig-%{version}.%{relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:		noarch

%description
A package that pulls in all the Mesh Configuration RPMs.

%package Shared
Summary:		perfSONAR_PS Mesh Configuration Shared Components
Group:			Applications/Communications
Requires:		perl
Requires:		perl(Config::General)
Requires:		perl(Data::Dumper)
Requires:		perl(Data::UUID)
Requires:		perl(Data::Validate::Domain)
Requires:		perl(Data::Validate::IP)
Requires:		perl(English)
Requires:		perl(Exporter)
Requires:		perl(File::Basename)
Requires:		perl(File::Path)
Requires:		perl(FindBin)
Requires:		perl(Getopt::Long)
Requires:		perl(HTTP::Response)
Requires:		perl(IO::File)
Requires:		perl(IO::Socket::SSL)
Requires:		perl(JSON)
Requires:		perl(Log::Log4perl)
Requires:		perl(Module::Load)
Requires:		perl(Moose)
Requires:		perl(Net::DNS)
Requires:		perl(Net::IP)
Requires:		perl(NetAddr::IP)
Requires:		perl(POSIX)
Requires:		perl(Params::Validate)
Requires:		perl(RPC::XML::Client)
Requires:		perl(Regexp::Common)
Requires:		perl(Storable)
Requires:		perl(Time::HiRes)
Requires:		perl(URI::Split)
Requires:		perl(base)
Requires:		perl(lib)
Requires:		perl(vars)
Requires:		perl(warnings)
Requires:		coreutils
Requires:		chkconfig
Requires:		shadow-utils
%description Shared
This package is the set of library files shared RPMs by the perfSONAR Mesh
Configuration agents.

%package Agent
Summary:		perfSONAR_PS Mesh Configuration Agent
Group:			Applications/Communications
Requires:		perl-perfSONAR_PS-MeshConfig-Shared
%description Agent
The perfSONAR-PS Mesh Configuration Agent downloads a centralized JSON file
describing the tests to run, and uses it to generate appropriate configuration
for the various services.

%package JSONBuilder
Summary:		perfSONAR_PS Mesh Configuration JSON Builder
Group:			Applications/Communications
Requires:		perl-perfSONAR_PS-MeshConfig-Shared
%description JSONBuilder
The perfSONAR-PS Mesh Configuration JSON Builder is used to convert the Mesh
.conf file format into a properly formed JSON file for agents to consume.


%package GUIAgent
Summary:		perfSONAR_PS Mesh Configuration GUI Agent
Group:			Applications/Communications
Requires:		perl-perfSONAR_PS-MeshConfig-Shared
Requires:		maddash-server
%description GUIAgent
The perfSONAR-PS Mesh Configuration Agent downloads a centralized JSON file
describing the tests a mesh is running, and generates a MaDDash configuration.

%pre Shared
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-MeshConfig-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} rpminstall

install -D -m 0600 scripts/%{crontab_1} %{buildroot}/etc/cron.d/%{crontab_1}
install -D -m 0600 scripts/%{crontab_2} %{buildroot}/etc/cron.d/%{crontab_2}

%clean
rm -rf %{buildroot}

%post
mkdir -p /var/lib/perfsonar/mesh_config
chown perfsonar:perfsonar /var/lib/perfsonar/mesh_config

%files Shared
%defattr(0644,perfsonar,perfsonar,0755)
%{install_base}/lib/perfSONAR_PS/MeshConfig/Utils.pm
%{install_base}/lib/perfSONAR_PS/MeshConfig/Config
%{install_base}/lib/perfSONAR_PS/NPToolkit
%{install_base}/lib/perfSONAR_PS/Utils
%{install_base}/lib/perfSONAR_PS/MeshConfig/Generators/Base.pm
%{install_base}/lib/Net/NTP.pm

%files JSONBuilder
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/build_json
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/validate_json
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/validate_configuration
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/lookup_hosts
%doc %{install_base}/doc/example.conf
%doc %{install_base}/doc/example.json
%doc %{install_base}/doc/cron-lookup_hosts
%{install_base}/etc/lookup_hosts.conf
%{install_base}/lib/SimpleLookupService
%{install_base}/lib/perfSONAR_PS/Client/LS


%files Agent
%defattr(0644,perfsonar,perfsonar,0755)
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/generate_configuration
%config(noreplace) %{install_base}/etc/agent_configuration.conf
%{install_base}/lib/perfSONAR_PS/MeshConfig/Agent.pm
%{install_base}/lib/perfSONAR_PS/MeshConfig/Generators/perfSONARRegularTesting.pm
%{install_base}/lib/perfSONAR_PS/RegularTesting
%{install_base}/scripts/cron-mesh_config_agent
%doc %{install_base}/doc/INSTALL
%doc %{install_base}/doc/cron-restart_services
%attr(0644,root,root) /etc/cron.d/%{crontab_1}

%files GUIAgent
%defattr(0644,perfsonar,perfsonar,0755)
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/generate_gui_configuration
%config(noreplace) %{install_base}/etc/gui_agent_configuration.conf
%{install_base}/lib/perfSONAR_PS/MeshConfig/GUIAgent.pm
%{install_base}/lib/perfSONAR_PS/MeshConfig/Generators/MaDDash.pm
%{install_base}/scripts/cron-mesh_config_gui_agent
%doc %{install_base}/doc/cron-restart_gui_services
%attr(0644,root,root) /etc/cron.d/%{crontab_2}

%changelog
* Thu Jun 19 2014 andy@es.net 3.4-5
- Support for regular testing and esmond MA added

* Wed Feb 20 2013 aaron@internet2.edu 3.3-3
- Provide an 'include' mechanism that allows meshes to include the contents of different JSON files

* Fri Feb 01 2013 aaron@internet2.edu 3.3-2
- Don't configure redudant tests (same source, same destination, same test parameters)
- Allow port numbers to be specified in addresses
- Fix a bug where the test ports weren't getting saved if defined at the top-level

* Fri Jan 11 2013 asides@es.net 3.3-1
- Bumped version and release for 3.3 Toolkit release

* Wed Dec 12 2012 aaron@internet2.edu 3.2.2-10
- Use the owamp test ports if it's configured by the Toolkit
- Fix a minor warning if 'address' isn't specified in generate_configuration

* Thu Nov 29 2012 aaron@internet2.edu 3.2.2-9
- Preserve CentralHost and traceroute collector variables if they aren't configured in the mesh(es)
- Fix for an issue where removed tests would leave a junk measurementset around

* Thu Nov 29 2012 aaron@internet2.edu 3.2.2-8
- Allow hosts to be defined at the mesh and organization level
- Fix for an issue when generating the JSON for disjoint tests
- Add support for new MaDDash options to display the description in place of IPs

* Mon Oct 08 2012 aaron@internet2.edu 3.2.2-7
- Fix for a bug where CONTACTADDR and NOAGENT weren't being preserved in non-mesh tests

* Fri Oct 05 2012 aaron@internet2.edu 3.2.2-6
- Cache the meshes the host is participating in, and only update if at least one of them changes
- Add support for an option to force each member of a pSB tests to run both the send side and the receive side

* Wed Oct 03 2012 aaron@internet2.edu 3.2.2-5
- Preserve tests that weren't configured by mesh(es)

* Wed Aug 30 2012 aaron@internet2.edu 3.2.2-4
- Documentation updates

* Tue Aug 07 2012 aaron@internet2.edu 3.2.2-3
- Allow for the agent to configure against multiple meshes

* Thu Aug 02 2012 aaron@internet2.edu 3.2.2-2
- Add a GUI agent

* Tue Jun 05 2012 aaron@internet2.edu 3.2.2-1
- Initial spec file created
