#
# RPM Spec for Python file-read-backwards Module
#
#
# Python
#

# This is the version we like.
%define _python_version_major 3

%if 0%{?el7}
%error EL7 is no longer supported.  Try something newer.
%endif

%if 0%{?el8}%{?ol8}
# EL8 standardized on just the major version, as did EPEL.
%define _python python%{_python_version_major}

%else

# EL9+ has everyting as just plain python
%define _python python

%endif

%define short	file-read-backwards

Name:		%{_python}-%{short}
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


BuildRequires:	%{_python}
BuildRequires:	%{_python}-setuptools

Requires:	%{_python}


%description
Memory efficient way of reading files line-by-line from the end of file



# Don't do automagic post-build things.
%global              __os_install_post %{nil}


%prep
%setup -q -n %{short}-%{version}


%build
%{_python} setup.py build


%install
%{_python} setup.py install \
    --root=$RPM_BUILD_ROOT \
    --single-version-externally-managed -O1 \
    --record=INSTALLED_FILES


%clean
rm -rf $RPM_BUILD_ROOT


%files -f INSTALLED_FILES
%defattr(-,root,root)
