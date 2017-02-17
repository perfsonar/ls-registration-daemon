%define install_base /usr/lib/perfsonar/
%define config_base  /etc/perfsonar

# init scripts must be located in the 'scripts' directory
%define init_script_1  perfsonar-lsregistrationdaemon

%define relnum 0.4.rc3 

Name:			perfsonar-lsregistrationdaemon
Version:		4.0
Release:		%{relnum}%{?dist}
Summary:		perfSONAR Lookup Service Registration Daemon
License:		Distributable, see LICENSE
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		perfsonar-lsregistrationdaemon-%{version}.%{relnum}.tar.gz
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
Requires:		perl(Linux::Inotify2)
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
Requires:		perl(Time::HiRes)
Requires:		perl(XML::LibXML)
Requires:		perl(Net::Interface)
Requires:		perl(base)
Requires:		coreutils
Requires:		shadow-utils
Requires:       libperfsonar-perl
Requires:       libperfsonar-esmond-perl
Requires:       libperfsonar-pscheduler-perl
Requires:       libperfsonar-sls-perl
Requires:       libperfsonar-toolkit-perl
Obsoletes:		perl-perfSONAR_PS-LSRegistrationDaemon
Provides:		perl-perfSONAR_PS-LSRegistrationDaemon
%if 0%{?el7}
BuildRequires: systemd
%{?systemd_requires: %systemd_requires}
%else
Requires:		chkconfig
%endif

%description
The LS Registration Daemon is used to register service instances for services
like bwctl, owamp, etc. that don't currently support registering
themselves.

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfsonar-lsregistrationdaemon-%{version}.%{relnum}

%build

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install

mkdir -p %{buildroot}/etc/init.d

%if 0%{?el7}
install -D -m 0644 scripts/%{init_script_1}.service %{buildroot}/%{_unitdir}/%{init_script_1}.service
%else
install -D -m 0755 scripts/%{init_script_1} %{buildroot}/etc/init.d/%{init_script_1}
%endif
rm -rf %{buildroot}/%{install_base}/scripts/

%clean
rm -rf %{buildroot}

%post
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/lib/perfsonar/lsregistrationdaemon
chown -R perfsonar:perfsonar /var/lib/perfsonar

%if 0%{?el7}
%systemd_post %{init_script_1}.service
if [ "$1" = "1" ]; then
    #if new install, then enable
    systemctl enable %{init_script_1}.service
    systemctl start %{init_script_1}.service
fi
%else
/sbin/chkconfig --add %{init_script_1}
if [ "$1" = "1" ]; then
    # clean install, check for pre 3.5.1 files
    if [ -e "/opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf" ]; then
        mv %{config_base}/lsregistrationdaemon.conf %{config_base}/lsregistrationdaemon.conf.default
        mv /opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon.conf %{config_base}/lsregistrationdaemon.conf
        sed -i "s:/var/lib/perfsonar/ls_registration_daemon:/var/lib/perfsonar/lsregistrationdaemon:g" %{config_base}/lsregistrationdaemon.conf
    fi
    
    if [ -e "/opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon-logger.conf" ]; then
        mv %{config_base}/lsregistrationdaemon-logger.conf %{config_base}/lsregistrationdaemon-logger.conf.default
        mv /opt/perfsonar_ps/ls_registration_daemon/etc/ls_registration_daemon-logger.conf %{config_base}/lsregistrationdaemon-logger.conf
        sed -i "s:ls_registration_daemon.log:lsregistrationdaemon.log:g" %{config_base}/lsregistrationdaemon-logger.conf
    fi
    
    if [ -e /var/lib/perfsonar/ls_registration_daemon/client_uuid ]; then
        mv -f /var/lib/perfsonar/ls_registration_daemon/client_uuid /var/lib/perfsonar/lsregistrationdaemon/client_uuid
    fi
    
    if [ -e /var/lib/perfsonar/ls_registration_daemon/lsKey.db ]; then
        mv -f /var/lib/perfsonar/ls_registration_daemon/lsKey.db /var/lib/perfsonar/lsregistrationdaemon/lsKey.db
    fi
    /etc/init.d/%{init_script_1} start &>/dev/null || :
fi

%endif

%preun
%if 0%{?el7}
%systemd_preun %{init_script_1}.service
%else
if [ "$1" = "0" ]; then
	# Totally removing the service
	/etc/init.d/%{init_script_1} stop
	/sbin/chkconfig --del %{init_script_1}
fi
%endif

%postun
%if 0%{?el7}
%systemd_postun_with_restart %{init_script_1}.service
%else
if [ "$1" != "0" ]; then
	# An RPM upgrade
	/etc/init.d/%{init_script_1} restart
fi
%endif

%files
%defattr(0644,perfsonar,perfsonar,0755)
%config(noreplace) %{config_base}/*
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%{install_base}/lib/perfSONAR_PS/*
%if 0%{?el7}
%attr(0644,root,root) %{_unitdir}/%{init_script_1}.service
%else
%attr(0755,perfsonar,perfsonar) /etc/init.d/*
%endif

%changelog
* Thu Jun 18 2014 andy@es.net 3.4-1
- Reorganization to better handled dual-homed hosts
- Support for new MA record format

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
