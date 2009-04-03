%define install_base /opt/perfsonar_ps/ls_registration_daemon

# init scripts must be located in the 'scripts' directory
%define init_script_1 ls_registration_daemon
# %define init_script_2 ls_registration_daemon

%define disttag pSPS

Name:           perl-perfSONAR_PS-LSRegistrationDaemon
Version:        0.10
Release:        1.%{disttag}
Summary:        perfSONAR_PS Lookup Service Registration Daemon
License:        distributable, see LICENSE
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/perfSONAR_PS-LSRegistrationDaemon/
Source0:        perfSONAR_PS-LSRegistrationDaemon.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
# XXX Add your perl requirements here. e.g.
# Requires:		perl(Config::General)
Requires:       perl
Requires: 		perl(Config::General)
Requires: 		perl(English)
Requires: 		perl(Exporter)
Requires: 		perl(Fcntl)
Requires: 		perl(File::Basename)
Requires: 		perl(Getopt::Long)
Requires: 		perl(IO::File)
Requires: 		perl(IO::Socket)
Requires: 		perl(IO::Socket::INET)
Requires: 		perl(IO::Socket::INET6)
Requires: 		perl(LWP::UserAgent)
Requires: 		perl(Log::Log4perl)
Requires: 		perl(Net::DNS)
Requires: 		perl(Net::Ping)
Requires: 		perl(Net::Ping::External)
Requires: 		perl(NetAddr::IP)
Requires: 		perl(POSIX)
Requires: 		perl(Params::Validate)
Requires: 		perl(Regexp::Common)
Requires: 		perl(Socket)
Requires: 		perl(Time::HiRes)
Requires: 		perl(XML::LibXML)
Requires: 		perl(base)

%description
The LS Registration Daemon is used to register service instances for services
like bwctl, NDT, NPAD, etc. that don't currently support registering
themselves.

%pre
/usr/sbin/groupadd perfsonar 2> /dev/null || :
/usr/sbin/useradd -g perfsonar -s /sbin/nologin -c "perfSONAR User" -d /tmp perfsonar 2> /dev/null || :

%prep
%setup -q -n perfSONAR_PS-LSRegistrationDaemon

%build

%install
rm -rf $RPM_BUILD_ROOT

make ROOTPATH=$RPM_BUILD_ROOT/%{install_base} install

mkdir -p $RPM_BUILD_ROOT/etc/init.d

awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_1} > scripts/%{init_script_1}.new
install -c -m 755 scripts/%{init_script_1}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_1}

#awk "{gsub(/^PREFIX=.*/,\"PREFIX=%{install_base}\"); print}" scripts/%{init_script_2} > scripts/%{init_script_2}.new
#install -c -m 755 scripts/%{init_script_2}.new $RPM_BUILD_ROOT/etc/init.d/%{init_script_2}

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(0644,perfsonar,perfsonar,0755)
%doc %{install_base}/doc/*
%config %{install_base}/etc/*
%attr(0755,perfsonar,perfsonar) %{install_base}/bin/*
%attr(0755,perfsonar,perfsonar) %{install_base}/scripts/*
%{install_base}/lib/*
%attr(0755,perfsonar,perfsonar) /etc/init.d/*

%post
mkdir -p /var/log/perfsonar
chown perfsonar:perfsonar /var/log/perfsonar

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

%changelog
* Wed Dec 10 2008 aaron@internet2.edu 0.10-1
- Initial service oriented spec file
