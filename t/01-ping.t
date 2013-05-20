use strict;
use warnings;
use Test::More tests => 1;

use AnyEvent::HTTP;
use AnyEvent;
use JSON;
use UUID::Tiny;

use Simple::RPC;
use Simple::RPC::Util;

Simple::RPC::Util->set_ae_log( 'filter=info:log=file=/dev/null' );

my $rpcd = Simple::RPC->new;
my $url  = sprintf 'http://localhost:%d/ping', $rpcd->port;
$rpcd->reg_cb(
    'test.rpc.ping' => sub {
        http_get $url, sub {
            my ( $data, $headers ) = @_;

            is( $data, '{"ret":1}', 'successful test: rpc.ping without uuid' );

            $rpcd->event( 'stop' => 'test is completed' );
        };
    },
);

my $t; $t = AE::timer( 1, 0, sub {
    $rpcd->event('test.rpc.ping');
} );

$rpcd->start;
