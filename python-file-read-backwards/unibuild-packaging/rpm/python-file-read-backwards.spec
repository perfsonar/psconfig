#
# RPM Spec for Python file-read-backwards Module
#

%define short	file-read-backwards

Name:		python-%{short}
Version:	3.0.0
Release:	1%{?dist}
Summary:	Memory efficient way of reading files line-by-line from the end of file
BuildArch:	noarch
License:	MIT license
Group:		Development/Libraries

Provides:	%{short} = %{version}-%{release}
Prefix:		%{_prefix}

Url:		https://github.com/RobinNil/file_read_backwards

Source:		%{short}-%{version}.tar.gz

BuildRequires:	python3
BuildRequires:	python3-setuptools

Requires:	python3


%description
Memory efficient way of reading files line-by-line from the end of file



# Don't do automagic post-build things.
%global              __os_install_post %{nil}


%prep
%setup -q -n %{short}-%{version}


%build
%{python3} setup.py build


%install
%{python3} setup.py install \
    --root=$RPM_BUILD_ROOT \
    --single-version-externally-managed -O1 \
    --record=INSTALLED_FILES


%clean
rm -rf $RPM_BUILD_ROOT


%files -f INSTALLED_FILES
%defattr(-,root,root)