#!/bin/bash

MAKEROOT=""
if [[ $EUID -ne 0 ]];
    MAKEROOT="sudo "
fi

$MAKEROOT cpan base
$MAKEROOT cpan Config::General
$MAKEROOT cpan constant
$MAKEROOT cpan Digest::MD5
$MAKEROOT cpan English
$MAKEROOT cpan Exporter
$MAKEROOT cpan Fcntl
$MAKEROOT cpan fields
$MAKEROOT cpan File::Basename
$MAKEROOT cpan Getopt::Long
$MAKEROOT cpan IO::File
$MAKEROOT cpan IO::Socket
$MAKEROOT cpan IO::Socket::INET
$MAKEROOT cpan IO::Socket::INET6
$MAKEROOT cpan lib
$MAKEROOT cpan Log::Log4perl
$MAKEROOT cpan LWP::Simple
$MAKEROOT cpan LWP::UserAgent
$MAKEROOT cpan NetAddr::IP
$MAKEROOT cpan Net::DNS
$MAKEROOT cpan Net::Ping
$MAKEROOT cpan Net::Ping::External
$MAKEROOT cpan Params::Validate
$MAKEROOT cpan POSIX
$MAKEROOT cpan Regexp::Common
$MAKEROOT cpan Socket
$MAKEROOT cpan Socket6
$MAKEROOT cpan strict
$MAKEROOT cpan Time::HiRes
$MAKEROOT cpan warnings
$MAKEROOT cpan XML::LibXML
