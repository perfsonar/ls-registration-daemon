%define install_base /opt/perfsonar_ps/ls_registration_daemon

# init scripts must be located in the 'scripts' directory
%define init_script_1 ls_registration_daemon
# %define init_script_2 ls_registration_daemon

%define relnum 1
%define disttag pSPS

Name:			perl-perfSONAR_PS-LSRegistrationDaemon
Version:		3.3.2
Release:		%{relnum}.%{disttag}
Summary:		perfSONAR_PS Lookup Service Registration Daemon
License:		Distributable, see LICENSE
Group:			Development/Libraries
URL:			http://psps.perfsonar.net/lsregistration/
Source0:		perfSONAR_PS-LSRegistrationDaemon-%{version}.%{relnum}.tar.gz
BuildRoot:		%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:		noarch
Requires:		perl
Requires:		perl(Config::General)
Requires:		perl(DateTime::Format::ISO8601)
Requires:		perl(DBD::SQLite)
Requires:		perl(English)
Requires:		perl(Exporter)
Requires:		perl(Fcntl)
Requires:		perl(File::Basename)
Requires:		perl(Getopt::Long)
Requires:		perl(IO::File)
Requires:		perl(IO::Socket)
Requires:		perl(IO::Socket::INET)
Requires:		perl(IO::Socket::INET6)
Requires:		perl(LWP::UserAgent)
Requires:		perl(Log::Log4perl)
Requires:		perl(Log::Dispatch::FileRotate)
Requires:		perl(Net::DNS)
Requires:		perl(Net::Ping)
Requires:		perl(Net::Ping::External)
Requires:		perl(NetAddr::IP)
Requires:		perl(POSIX)
Requires:		perl(Params::Validate)
Requires:		perl(Regexp::Common)
Requires:		perl(Socket)
Requires:		perl(Sys::MemInfo)
Requires:		perl(Time::HiRes)
Requires:		perl(XML::LibXML)
Requires:		perl-perfSONAR_PS-SimpleLS-BootStrap-client
Requires:		perl(base)
Requires:		chkconfig
Requires:		coreutils
Requires:		shadow-utils

%description
The LS Registration Daemon is used to register service instances for services
like bwctl, NDT, NPAD, etc. that don't currently support registering
themselves.

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-LSRegistrationDaemon-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} rpminstall

mkdir -p %{buildroot}/etc/init.d

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_1} > scripts/%{init_script_1}.new
install -D -m 0755 scripts/%{init_script_1}.new %{buildroot}/etc/init.d/%{init_script_1}

#awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_2} > scripts/%{init_script_2}.new
#install -D -m 0755 scripts/%{init_script_2}.new %{buildroot}/etc/init.d/%{init_script_2}

%clean
rm -rf %{buildroot}

%post
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/lib/perfsonar/ls_registration_daemon
chown -R perfsonar:perfsonar /var/lib/perfsonar

/sbin/chkconfig --add %{init_script_1}
#/sbin/chkconfig --add %{init_script_2}

%preun
if [ "$1" = "0" ]; then
	# Totally removing the service
	/etc/init.d/%{init_script_1} stop
	/sbin/chkconfig --del %{init_script_1}
#	/etc/init.d/%{init_script_2} stop
#	/sbin/chkconfig --del %{init_script_2}
fi

%postun
if [ "$1" != "0" ]; then
	# An RPM upgrade
	/etc/init.d/%{init_script_1} restart
#	/etc/init.d/%{init_script_2} restart
fi

%files
%defattr(0644,perfsonar,perfsonar,0755)
%doc %{install_base}/doc/*
%config(noreplace) %{install_base}/etc/*
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/*
%{install_base}/lib/*
%attr(0755,perfsonar,perfsonar) /etc/init.d/*
%{install_base}/dependencies

%changelog
* Fri Jan 11 2013 asides@es.net 3.3-1
- 3.3 beta release

* Thu Feb 25 2010 zurawski@internet2.edu 3.1-5
- Support for REDDnet depots
- Increase time between when keepalives are sent
- Minor bugfixes

* Tue Jan 12 2010 aaron@internet2.edu 3.1-4
- Packaging update

* Tue Sep 22 2009 zurawski@internet2.edu 3.1-3
- useradd option change
- Improved sanity checking of the specified ls instance
- Improved logging
- Add option to require 'site_name' and 'site_location' before starting

* Thu May 29 2009 aaron@internet2.edu 3.1-2
- Documentation updates

* Wed Dec 10 2008 aaron@internet2.edu 3.1-1
- Initial service oriented spec file
