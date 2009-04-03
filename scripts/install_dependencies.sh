#!/bin/bash

MAKEROOT=""
if [[ $EUID -ne 0 ]];
then
    MAKEROOT="sudo "
fi

$MAKEROOT cpan Config::General
$MAKEROOT cpan Digest::MD5
$MAKEROOT cpan English
$MAKEROOT cpan Exporter
$MAKEROOT cpan Fcntl
$MAKEROOT cpan File::Basename
$MAKEROOT cpan Getopt::Long
$MAKEROOT cpan IO::File
$MAKEROOT cpan IO::Socket
$MAKEROOT cpan IO::Socket::INET
$MAKEROOT cpan IO::Socket::INET6
$MAKEROOT cpan LWP::Simple
$MAKEROOT cpan LWP::UserAgent
$MAKEROOT cpan Log::Log4perl
$MAKEROOT cpan Net::DNS
$MAKEROOT cpan Net::Ping
$MAKEROOT cpan Net::Ping::External
$MAKEROOT cpan NetAddr::IP
$MAKEROOT cpan POSIX
$MAKEROOT cpan Params::Validate
$MAKEROOT cpan Regexp::Common
$MAKEROOT cpan Time::HiRes
$MAKEROOT cpan XML::LibXML
$MAKEROOT cpan base
