package Simple::RPC;
# ABSTRACT: Simple RPC server

use Moo;
use MooX::Types::MooseLike::Base qw( ArrayRef CodeRef Int Str );
use namespace::clean -except => 'meta';

use AnyEvent::HTTPD;
use AnyEvent;
use JSON;
use Scalar::Util qw( weaken );
use UUID::Tiny;

use Simple::RPC::Patch::AnyEvent::HTTPD;
use Simple::RPC::Patch::Object::Event;

extends qw( Object::Event );

has port => (
    is      => 'ro',
    isa     => Int,
    builder => '_default_port',
);

has ping => (
    is      => 'ro',
    isa     => CodeRef,
    builder => '_default_ping',
);

has types => (
    is      => 'ro',
    isa     => ArrayRef[Str],
    builder => '_default_types',
);

has _httpd => (
    is => 'rw',
);

has _cv => (
    is      => 'rw',
    builder => '_default__cv',
);

sub _default_port  { 8080 }
sub _default_ping  { sub { +{ ret => 1 } } }
sub _default_types { [] }
sub _default__cv   { AnyEvent->condvar }

sub BUILD {
    my $self = shift;

    $self->reg_cb(
        'start' => sub {
            my $self = shift;

            my $httpd = AnyEvent::HTTPD->new( port => $self->port );
            weaken($self);
            $httpd->reg_cb(
                'auto' => sub {
                    my ( $httpd, $req ) = @_;

                    AE::log info => sprintf(
                        'HTTP-REQ [%s:%s]->[%s:%s] %s',
                        $req->client_host,
                        $req->client_port,
                        $httpd->host,
                        $httpd->port,
                        $req->url,
                    );

                    # do not check uuid if request is /ping
                    return if $req->url eq '/ping';

                    my $uuid = $req->parm('uuid');
                    unless ( $uuid && is_UUID_string($uuid) ) {
                        AE::log warn => "invalid uuid" . ( $uuid ? ": [$uuid]" : q{} );
                        $req->respond({
                            content => [
                                'application/json',
                                encode_json( { ret => 0 } ),
                            ],
                        });
                        $httpd->stop_request;
                    }
                },
                '/ping' => sub {
                    my ( $httpd, $req ) = @_;

                    my $ret = $self->ping->($self, $httpd);
                    if ( $ret->{code} ) {
                        $req->respond([
                            200,
                            'OK',
                            { 'Content-Type' => 'text/json' },
                            encode_json($ret),
                        ]);
                    }
                    else {
                        $req->respond([
                            400,
                            'Bad Request',
                            { 'Content-Type' => 'text/json' },
                            encode_json($ret),
                        ]);
                    }
                },
                '/' => sub {
                    my ( $httpd, $req ) = @_;

                    my $uuid = $req->parm('uuid');
                    my $hook = $req->parm('hook');
                    my $data = $req->parm('data');
                    my $type = $req->parm('type');

                    my @available_types = @{ $self->types };
                    unless ( $type ~~ @available_types ) {
                        AE::log warn => "not available type: [$type]";

                        my %ret = (
                            uuid => $req->parm('uuid'),
                            ret  => 0,
                        );

                        $req->respond({
                            content => [ 'application/json', encode_json( \%ret ) ],
                        });

                        return;
                    }

                    #
                    # Do what you want.
                    #
                    #   - send data into job-queue or blah, blah, ...
                    #   - ...?
                    #
                    # my $sub_ret = process();
                    my $sub_ret = 1;

                    my %ret = (
                        uuid => $req->parm('uuid'),
                        ret  => $sub_ret ? 1 : 0,
                    );

                    $req->respond({
                        content => [ 'application/json', encode_json( \%ret ) ],
                    });
                },
            );

            $self->_httpd($httpd);
            $self->_cv->recv;
        },
        'stop' => sub {
            my ( $self, $msg ) = @_;

            AE::log warn => $msg;

            $self->_cv->send;
        },
    );
}

sub start {
    my $self = shift;

    $self->event('start');
}

1;
__END__

=head1 SYNOPSIS

    use Simple::RPC;

    my $rpcd = Simple::RPC->new;
    $rpcd->start;


=head1 DESCRIPTION

This module serves simple HTTP request and return HTTP response as JSON string.


=attr port

Specify port number to process HTTP request. Read-only.
(default: 8080)

    my $rpcd = Simple::RPC->new(
        port => 8888,
    );

=attr types

Specify available type string. Read-only.

    my $rpcd = Simple::RPC->new(
        types => [qw/
            BackupDatabase
            SetDefaultConfig
            SendEmail
            SendSMS
            Reboot
        /],
    );


=method start

Start http server

    my $rpcd = Simple::RPC->new;
    $rpcd->start;
