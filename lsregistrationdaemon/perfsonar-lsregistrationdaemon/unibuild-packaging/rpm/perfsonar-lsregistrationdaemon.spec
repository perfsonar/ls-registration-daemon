%define install_base /usr/lib/perfsonar/
%define config_base  /etc/perfsonar

# init scripts must be located in the 'scripts' directory
%define init_script_1  perfsonar-lsregistrationdaemon

%define perfsonar_auto_version 5.0.2
%define perfsonar_auto_relnum 0.a1.0

Name:			perfsonar-lsregistrationdaemon
Version:		%{perfsonar_auto_version}
Release:		%{perfsonar_auto_relnum}%{?dist}
Summary:		perfSONAR Lookup Service Registration Daemon
License:		ASL 2.0
Group:			Development/Libraries
URL:			http://www.perfsonar.net
Source0:		perfsonar-lsregistrationdaemon-%{version}.tar.gz
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
Requires:		perl(NetAddr::IP)
Requires:		perl(POSIX)
Requires:		perl(Params::Validate)
Requires:		perl(Regexp::Common)
Requires:		perl(Socket)
Requires:		perl(Time::HiRes)
Requires:		perl(XML::LibXML)
Requires:		perl(Crypt::OpenSSL::X509)
Requires:		perl(Crypt::OpenSSL::RSA)
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
BuildRequires: systemd, selinux-policy-devel
%{?systemd_requires: %systemd_requires}
# SELinux support
%if 0%{?el7}
Requires: policycoreutils-python, libselinux-utils
Requires(post): selinux-policy-targeted, policycoreutils-python
Requires(postun): policycoreutils-python
%else
#Requirements for > el7
Requires: python3-policycoreutils, libselinux-utils
Requires(post): selinux-policy-targeted, python3-policycoreutils
Requires(postun): python3-policycoreutils
%endif

%description
The LS Registration Daemon is used to register information about the perfSONAR host and
the services it runs to the global perfSONAR Lookup Service

%pre
/usr/sbin/groupadd -r perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -r -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfsonar-lsregistrationdaemon-%{version}

%build
make -f /usr/share/selinux/devel/Makefile -C selinux lsregistrationdaemon.pp

%install
rm -rf %{buildroot}

make ROOTPATH=%{buildroot}/%{install_base} CONFIGPATH=%{buildroot}/%{config_base} install

mkdir -p %{buildroot}/etc/init.d

install -D -m 0644 scripts/%{init_script_1}.service %{buildroot}/%{_unitdir}/%{init_script_1}.service
rm -rf %{buildroot}/%{install_base}/scripts/

mkdir -p %{buildroot}/usr/share/selinux/packages/
mv selinux/*.pp %{buildroot}/usr/share/selinux/packages/
rm -rf %{buildroot}/usr/lib/perfsonar/selinux

%clean
rm -rf %{buildroot}

%post
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

mkdir -p /var/lib/perfsonar/lsregistrationdaemon
chown -R perfsonar:perfsonar /var/lib/perfsonar

semodule -n -i %{_datadir}/selinux/packages/lsregistrationdaemon.pp
if /usr/sbin/selinuxenabled; then
    /usr/sbin/load_policy
    restorecon -iR /etc/perfsonar/lsregistrationdaemon-logger.conf \
                   /etc/perfsonar/lsregistrationdaemon.conf \
                   /usr/lib/perfsonar/bin/lsregistrationdaemon.pl \
                   /usr/lib/systemd/system/perfsonar-lsregistrationdaemon.service \
                   /var/lib/perfsonar/lsregistrationdaemon \
                   /var/run/lsregistrationdaemon.pid \
                   /var/log/perfsonar/lsregistrationdaemon.log*
fi

%systemd_post %{init_script_1}.service
if [ "$1" = "1" ]; then
    #if new install, then enable
    systemctl enable %{init_script_1}.service
    systemctl start %{init_script_1}.service
fi

%preun
%systemd_preun %{init_script_1}.service

%postun
%systemd_postun_with_restart %{init_script_1}.service

if [ $1 -eq 0 ]; then
    semodule -n -r lsregistrationdaemon
    if /usr/sbin/selinuxenabled; then
       /usr/sbin/load_policy
       restorecon -iR /etc/perfsonar/lsregistrationdaemon-logger.conf \
                      /etc/perfsonar/lsregistrationdaemon.conf \
                      /usr/lib/perfsonar/bin/lsregistrationdaemon.pl \
                      /usr/lib/systemd/system/perfsonar-lsregistrationdaemon.service \
                      /var/lib/perfsonar/lsregistrationdaemon \
                      /var/run/lsregistrationdaemon.pid \
                      /var/log/perfsonar/lsregistrationdaemon.log*
    fi
fi

%files
%defattr(0644,perfsonar,perfsonar,0755)
%license LICENSE
%config(noreplace) %{config_base}/*
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%{install_base}/lib/perfSONAR_PS/*
%attr(0644,root,root) %{_unitdir}/%{init_script_1}.service
%attr(0644,root,root) %{_datadir}/selinux/packages/lsregistrationdaemon.pp

%changelog
* Wed Jun 18 2014 andy@es.net 3.4-1
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

* Fri May 29 2009 aaron@internet2.edu 3.1-2
- Documentation updates

* Wed Dec 10 2008 aaron@internet2.edu 3.1-1
- Initial service oriented spec file
