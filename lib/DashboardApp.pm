package DashboardApp;
use Mojo::Base 'Mojolicious';

use DashboardApp::Model::Config;
use DashboardApp::Model::Ticket;
use JSON qw/encode_json/;
use Mojolicious::Sessions::Storable;
use Plack::Session::Store::File;

sub startup {
    my $self = shift;

    $self->secrets(['eeQu6ighiegh6zaizoh6eithuiphoo']);

    $self->plugin( 'Config' );
    $self->plugin( 'tt_renderer' );
    $self->plugin( 'DashboardApp::Plugin::Memcached' => {
        memcached => {
            namespace => 'bws-dashboard',
            servers => [ 'localhost:11211' ],
        },
    } );

    $self->helper( tickets_model => sub { state $tickets_model = DashboardApp::Model::Ticket->new( $self->app->memcached ) } );

    my $sessions = Mojolicious::Sessions::Storable->new(
        session_store => Plack::Session::Store::File->new( dir => './sessions' )
    );

    $self->sessions($sessions);

    my $r = $self->routes;
    $r->get("/")->to("main#index");
    $r->post("/json/login")->to("main#login");

    my $auth = $r->under( sub {
        my ( $c ) = @_;

        unless ( $c->session->{user_id} ) {
            $c->render( json => { error => "Not authorized." }, status => 401 );
            return 0;
        }

        return 1;
    } );

    $auth->get("/json/employee/tickets")->to("employee#show_dashboard");
    $auth->post("/json/employee/save_columns")->to("employee#save_columns");

    $auth->get("/json/get_roles")->to("main#get_roles");
    $auth->post("/json/update_ticket")->to("main#update_ticket");
    $auth->post("/json/ticket_details")->to("main#ticket_details");
    $auth->post("/json/ticket_history")->to("main#ticket_history");

    my $lead = $auth->under( sub {
        my ( $c ) = @_;

        unless ( grep { $_ eq 'lead' } @{ $c->session->{roles} } ) {
            $c->render( json => { error => "Operation not permitted." }, status => 403 );
            return 0;
        }

        return 1;
    } );

    $lead->get("/json/lead/tickets")->to("lead#show_dashboard");
    $lead->post("/json/lead/save_columns")->to("lead#save_columns");

    $r->get("/logout")->to("main#logout");

    my $config = DashboardApp::Model::Config::get_config();

    if ( $config->{debug_frontend} ) {
        $self->hook( after_static => sub {
            my $self = shift;

            $self->res->headers->cache_control('must-revalidate, no-store, no-cache, private');
        } );
    }
}


1;
