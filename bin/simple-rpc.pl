#!perl
# ABSTRACT: Simple RPC server launcher
# PODNAME: simple-rpc.pl

BEGIN {
    $ENV{PERL_OBJECT_EVENT_DEBUG} = 2;
}

use utf8;
use strict;
use warnings;
use Getopt::Long::Descriptive;

use Simple::RPC;
use Simple::RPC::Util;

my ( $opt, $usage ) = describe_options(
    "%c %o ...",
    [ 'port|p=i', "notify server port"           ],
    [ 'ae-log=s', "anyevent log destination"     ],
    [],
    [ 'help|h',   'print usage message and exit' ],
);
print( $usage->text ), exit if $opt->help;

Simple::RPC::Util->set_ae_log( $opt->ae_log );

my %params;
$params{port}   = $opt->port   if $opt->port;
$params{ae_log} = $opt->ae_log if $opt->ae_log;

my $notify = Simple::RPC->new(%params);
$notify->start;
