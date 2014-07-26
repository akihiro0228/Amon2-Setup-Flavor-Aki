package Amon2::Setup::Flavor::Aki;
use strict;
use warnings;
use utf8;
use parent qw/ Amon2::Setup::Flavor /;
use Amon2::Setup::Asset::jQuery;
our $VERSION = '0.01';

sub run {
    my $self = shift;

    $self->write_tmpl;

    $self->write_psgifile;

    $self->write_config;

    $self->write_cpanfile;

    $self->write_scriptfile;

    $self->write_sqlfile;

    $self->write_static;

    $self->write_t;

    $self->write_lib;

    $self->write_dotfiles;

    $self->write_assets('static/default');
}


sub write_tmpl {
    my $self = shift;

    $self->write_file("tmpl/wrapper/app/layout.tx", <<'...');
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title><: $title || '<%= $dist %>' :></title>
    <script src="<: uri_for('/static/default/js/jquery-2.1.0.min.js') :>"></script>
    <script src="<: uri_for('/static/default/bootstrap/js/bootstrap.js') :>"></script>
    <link href="<: uri_for('/static/default/bootstrap/css/bootstrap.css') :>" rel="stylesheet" type="text/css" />
    <script src="<: uri_for('/static/default/js/xsrf-token.js') :>"></script>
    <link href="<: static_file('/static/css/main.css') :>" rel="stylesheet" type="text/css" media="screen" />
    : if ($css_path) {
    <link href="<: static_file('/static/css/' ~ $css_path) :>" rel="stylesheet" type="text/css" media="screen" />
    :}
    : if ($js_path) {
    <script src="<: static_file('/static/js/' ~ $js_path) :>"></script>
    :}
    <!--[if lt IE 9]>
        <script src="http://html5shiv.googlecode.com/svn/trunk/html5.js"></script>
    <![endif]-->
</head>
<body>

<header>
    :include "wrapper/app/header.tx";
</header>

<div class="container">
    <div id="main">
        <: block content -> { } :>
    </div>
</div>

<footer>
    :include "wrapper/app/footer.tx";
</footer>

</body>
</html>
...

    $self->write_file("tmpl/wrapper/app/header.tx", '');
    $self->write_file("tmpl/wrapper/app/footer.tx", '');

    $self->write_file("tmpl/app/home/index.tx", <<'...');
: cascade "wrapper/app/layout.tx" { title => '<% $module %>' }

: override content -> {

<h1>Hello Aki-Flavor</h1>

: }
...
}

sub write_psgifile {
    my $self = shift;

    $self->write_file("app.psgi", <<'...');
#!perl
use strict;
use warnings;
use utf8;
use lib qw/lib/;
use Plack::Builder;

use <% $module %>::Web;

my $app = builder {
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/static/)};
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/robots\.txt|/favicon\.ico)$},
        root => 'static';
    enable 'Plack::Middleware::ReverseProxy';

    <% $module %>::Web->to_app();
};

return $app;
...
}

sub write_config {
    my $self = shift;

    $self->write_file("config/development.pl", <<'...');
use strict;
use warnings;
use Config::Pit;

my $config = pit_get('<% $module %>.com', require => {
    'database' => 'hoge',
    'username' => 'hoge',
    'password' => 'hoge',
});

return {
    DB   => [
        $config->{database},
        $config->{username},
        $config->{password},
    ],
};
...

    $self->write_file("config/production.pl", <<'...');
use strict;
use warnings;
use Config::Pit;

my $config = pit_get('<% $module %>.com', require => {
    'database' => 'hoge',
    'username' => 'hoge',
    'password' => 'hoge',
});

return {
    DB   => [
        $config->{database},
        $config->{username},
        $config->{password},
    ],
};
...

    $self->write_file("config/test.pl", <<'...');
use strict;
use warnings;
use Config::Pit;

my $config = pit_get('<% $module %>.com.test', require => {
    'database' => 'hoge',
    'username' => 'hoge',
    'password' => 'hoge',
});

return {
    DB   => [
        $config->{database},
        $config->{username},
        $config->{password},
    ],
};
...
}

sub write_cpanfile {
    my $self = shift;

    $self->create_cpanfile({
        'Time::Piece'                     => '1.20',
        'Plack::Middleware::ReverseProxy' => '0.09',
        'JSON'                            => '2.50',
        'Teng'                            => '0.18',
        'DBD::mysql'                      => 0,
        'Test::WWW::Mechanize::PSGI'      => 0,
        'Router::Boom'                    => '0.06',
        'HTTP::Session2'                  => '0.04',
        'Config::Pit'                     => 0,
        'Module::Find'                    => 0,
        'DateTimeX::Factory'              => 0,
        'Data::Validator'                 => 0,
    });
}

sub write_scriptfile {
    my $self = shift;

    $self->write_file("script/pit.pl", <<'...');
use strict;
use warnings;
use Config::Pit;

Config::Pit::set('<% $module %>.com', data => {
    database => 'DBI:mysql:<%= $dist %>:localhost:3306',
    username => 'user_name',
    password => 'password',
});

Config::Pit::set('<% $module %>.com.test', data => {
    database => 'DBI:mysql:<%= $dist %>_test:localhost:3306',
    username => 'user_name',
    password => 'password',
});
...

    $self->write_file("script/db_setup.sh", <<'...');
#!/bin/zsh

cd $(dirname $0)/..

mysql -uroot -e 'CREATE DATABASE IF NOT EXISTS <%= $dist %>      DEFAULT CHARACTER SET utf8;'
mysql -uroot -e 'CREATE DATABASE IF NOT EXISTS <%= $dist %>_test DEFAULT CHARACTER SET utf8;'

cat db/schema.sql  | mysql -uroot <%= $dist %>
cat db/schema.sql  | mysql -uroot <%= $dist %>_test
cat db/trigger.sql | mysql -uroot <%= $dist %>
cat db/trigger.sql | mysql -uroot <%= $dist %>_test
...

    $self->write_file("script/test.sh", <<'...');
#!/bin/zsh

cd $(dirname $0)/..

if [ $1 ]
then
    carton exec prove -cl --timer $1
else
    carton exec prove -clr --timer t
fi
...
}

sub write_sqlfile {
    my $self = shift;

    $self->write_file("db/schema.sql", <<'...');
DROP TABLE IF EXISTS user;

CREATE TABLE IF NOT EXISTS user (
    id           INTEGER     NOT NULL AUTO_INCREMENT,  
    name         VARCHAR(32) NOT NULL                COMMENT "名前",  
    created_at   DATETIME             DEFAULT NULL,
    updated_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE      (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT "ユーザー管理";
...

    $self->write_file("db/trigger.sql", <<'...');
DROP TRIGGER IF EXISTS before_user;

DELIMITER |
CREATE TRIGGER before_user BEFORE INSERT ON user FOR EACH ROW
BEGIN
    SET NEW.created_at = NOW();
END;
|
DELIMITER ;
...
}

sub write_static {
    my $self = shift;

    $self->write_file("static/css/main.css", <<'...');
body {
    font-family: "Hiragino Maru Gothic ProN", Meiryo, fantasy;
}
...

    $self->write_file("static/css/app/home/index.css", '');
    $self->write_file("static/js/app/home/index.js", '');
    $self->write_file("static/robots.txt", '');
}

sub write_t {
    my $self = shift;

    $self->render_file('t/00_compile.t', 'Basic/t/00_compile.t');

    $self->write_file("t/01_setup.t", <<'...');
use strict;
use warnings;
use utf8;
use t::Util;
use Test::More;

subtest 'db_cleanup' => sub {
    db_cleanup();

    ok 1;
};

done_testing;
...

    $self->write_file("t/02_root.t", <<'...');
use strict;
use warnings;
use utf8;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;

my $app = Plack::Util::load_psgi 'app.psgi';
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => 'http://localhost/');
        my $res = $cb->($req);
        is $res->code, 200;
        diag $res->content if $res->code != 200;
    };

done_testing;
...

    $self->write_file("t/03_mech.t", <<'...');
use strict;
use warnings;
use utf8;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::Requires 'Test::WWW::Mechanize::PSGI';

my $app = Plack::Util::load_psgi 'app.psgi';

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
$mech->get_ok('/');

done_testing;
...

    $self->write_file("t/04_assets.t", <<'...');
use strict;
use warnings;
use utf8;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;

my $app = Plack::Util::load_psgi 'app.psgi';
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        for my $fname (qw(robots.txt)) {
            my $req = HTTP::Request->new(GET => "http://localhost/$fname");
            my $res = $cb->($req);
            is($res->code, 200, $fname) or diag $res->content;
        }
    };

done_testing;
...

    $self->write_file("t/Util.pm", <<'...');
package t::Util;
BEGIN {
    unless ($ENV{PLACK_ENV}) {
        $ENV{PLACK_ENV} = 'test';
    }
    if ($ENV{PLACK_ENV} eq 'production') {
        die "Do not run a test script on deployment environment";
    }
}
use File::Spec;
use File::Basename;
use lib File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'lib'));
use parent qw/Exporter/;
use Test::More 0.98;
use <% $module %>;

our @EXPORT = qw(
    slurp
    db_cleanup
    c
);

{
    # utf8 hack.
    binmode Test::More->builder->$_, ":utf8" for qw/output failure_output todo_output/;
    no warnings 'redefine';
    my $code = \&Test::Builder::child;
    *Test::Builder::child = sub {
        my $builder = $code->(@_);
        binmode $builder->output,         ":utf8";
        binmode $builder->failure_output, ":utf8";
        binmode $builder->todo_output,    ":utf8";
        return $builder;
    };
}


sub slurp {
    my $fname = shift;
    open my $fh, '<:encoding(UTF-8)', $fname or die "$fname: $!";
    scalar do { local $/; <$fh> };
}

# initialize database
sub db_cleanup {
    system("cat db/schema.sql  | mysql -uroot <%= $dist %>_test");
    system("cat db/trigger.sql | mysql -uroot <%= $dist %>_test");
}

sub c {
    <%= $dist %>->bootstrap;
}

1;
...

    my $path = lc "<<PATH>>";
    $self->write_file("t/$path/model/user.t", <<'...');
use strict;
use warnings;
use utf8;
use t::Util;
use Test::More;

db_cleanup;

my $user1 = c->db->insert('user' => +{ name => "ユーザー1" });


subtest 'lookup_by_id' => sub {

    my $user = c->model('User')->lookup_by_id($user1->id);

    is_deeply
        $user->get_columns,
        $user1->get_columns,
        "指定IDのユーザーが取得出来ている"
    ;
};

subtest 'lookup_by_name' => sub {

    my $user = c->model('User')->lookup_by_name($user1->name);

    is_deeply
        $user->get_columns,
        $user1->get_columns,
        "指定名のユーザーが取得出来ている"
    ;
};


done_testing;
...
}

sub write_lib {
    my $self = shift;

    $self->write_file("lib/<<PATH>>.pm", <<'...');
package <% $module %>;
use strict;
use warnings;
use utf8;
our $VERSION='0.01';
use 5.008001;
use <% $module %>::DB::Schema;
use <% $module %>::DB;
use DateTimeX::Factory;
use Class::Load;

use parent qw/Amon2/;

my $schema = <% $module %>::DB::Schema->instance;

sub dt {
    my $c = shift;

    if (!exists $c->{dt}) {
        $c->{dt} = DateTimeX::Factory->new(
            time_zone => 'Asia/Tokyo',
        );
    }

    return $c->{dt};
}

sub model {
    my ($c, $model_name) = @_;

    my $model = __PACKAGE__ . "::Model::" . $model_name;
    Class::Load::load_class($model);

    return $model->new;
}

sub db {
    my $c = shift;
    if (!exists $c->{db}) {
        my $conf = $c->config->{DB}
            or die "Missing configuration about DB";
        $c->{db} = Teng->new(
            connect_info => $conf,
            schema_class => "<% $module %>::DB::Schema",
        );
    }
    $c->{db};
}

1;
__END__

=head1 NAME

<% $module %> - <% $module %>

=head1 DESCRIPTION

This is a main context class for <% $module %>

=head1 AUTHOR

<% $module %> authors.

...

    $self->render_file('lib/<<PATH>>/DB.pm', 'Basic/lib/__PATH__/DB.pm' );

    $self->render_file("lib/<<PATH>>/DB/Row.pm", 'Basic/lib/__PATH__/DB/Row.pm');

    $self->write_file("lib/<<PATH>>/DB/Schema.pm", <<'...');
package <% $module %>::DB::Schema;
use strict;
use warnings;
use utf8;

use Teng::Schema::Declare;

base_row_class '<% $module %>::DB::Row';

table {
    name 'user';
    pk 'id';
    columns qw(id name created_at updated_at);
};

1;
...

    $self->write_file("lib/<<PATH>>/Model.pm", <<'...');
package <% $module %>::Model;
use strict;
use warnings;
use utf8;
use Amon2::Declare;
use Data::Validator;

sub new {
    shift;
}

1;
...

    $self->write_file("lib/<<PATH>>/Model/User.pm", <<'...');
package <% $module %>::Model::User;
use strict;
use warnings;
use utf8;
use 5.16.2;
use parent qw/<% $module %>::Model/;

sub lookup_by_id {
    my ($class, $id) = @_;

    return $class->c->db->single('user', +{ id => $id });
}

sub lookup_by_name {
    my ($class, $name) = @_;

    return $class->c->db->single('user', +{ name => $name });
}

1;
...

    $self->write_file("lib/<<PATH>>/Web.pm", <<'...');
package <% $module %>::Web;
use strict;
use warnings;
use utf8;
use parent qw/<% $module %> Amon2::Web/;
use File::Spec;

# dispatcher
use <% $module %>::Web::Dispatcher;
sub dispatch {
    return (<% $module %>::Web::Dispatcher->dispatch($_[0]) or die "response is not generated");
}

# load plugins
__PACKAGE__->load_plugins(
    'Web::FillInFormLite',
    'Web::JSON',
    '+<% $module %>::Web::Plugin::Session',
);

# setup view
use <% $module %>::Web::View;
{
    sub create_view {
        my $view = <% $module %>::Web::View->make_instance(__PACKAGE__);
        no warnings 'redefine';
        *<% $module %>::Web::create_view = sub { $view }; # Class cache.
        $view
    }

    sub auto_render {
        my $self = shift;
        my @args;

        (caller 1)[3] =~ /^<% $module %>::Web::([^:]+)::C::(.+)/;
        
        my @path = (lc $1, lc $2);

        $path[1] =~ s!::!/!g;
        my $file_path = join '/', @path;
        my @arg = @_;
        $arg[0]->{js_path}  = $file_path . '.js';
        $arg[0]->{css_path} = $file_path . '.css';
        @args = ($file_path . '.tx', @arg);
        $self->render(@args);
    }
}

# for your security
__PACKAGE__->add_trigger(
    AFTER_DISPATCH => sub {
        my ( $c, $res ) = @_;

        # http://blogs.msdn.com/b/ie/archive/2008/07/02/ie8-security-part-v-comprehensive-protection.aspx
        $res->header( 'X-Content-Type-Options' => 'nosniff' );

        # http://blog.mozilla.com/security/2010/09/08/x-frame-options/
        $res->header( 'X-Frame-Options' => 'DENY' );

        # Cache control.
        $res->header( 'Cache-Control' => 'private' );
    },
);

1;
...

    $self->write_file("lib/<<PATH>>/Web/Dispatcher.pm", <<'...');
package <% $module %>::Web::Dispatcher;
use strict;
use warnings;
use utf8;
use Module::Find;
use Amon2::Web::Dispatcher::RouterBoom;

useall qw/ <% $module %>::Web::App::C /;

base '<% $module %>::Web::App::C';
get '/' => 'Home#index';

1;
...

    $self->write_file("lib/<<PATH>>/Web/App/C/Home.pm", <<'...');
package <% $module %>::Web::App::C::Home;
use strict;
use warnings;
use utf8;

sub index {
    my ($class, $c) = @_;

    return $c->auto_render;
}

1;
...

    $self->render_file("lib/<<PATH>>/Web/View.pm", "Minimum/lib/__PATH__/Web/View.pm");

    $self->render_file("lib/<<PATH>>/Web/ViewFunctions.pm", "Minimum/lib/__PATH__/Web/ViewFunctions.pm");

    $self->render_file("lib/<<PATH>>/Web/Plugin/Session.pm", "Basic/lib/__PATH__/Web/Plugin/Session.pm");
}

sub write_dotfiles {
    my $self = shift;

    $self->render_file('.gitignore', 'Basic/dot.gitignore');
}

sub show_banner {
    my $self = shift;

    printf <<'...', $self->write_dotfiles;
--------------------------------------------------------------

Setup script was done! You are ready to run the skelton.

Installing the module:

    > carton install

Database connection settings:

    > vi script/pit.pl
    > carton exec perl script/pit.pl

Setup database:

    > sh script/setup.sh

And then, run your application server:

    > carton exec plackup

--------------------------------------------------------------
...
}

1;
__END__

=head1 NAME

Amon2::Setup::Flavor::Aki -

=head1 SYNOPSIS

  use Amon2::Setup::Flavor::Aki;

=head1 DESCRIPTION

Amon2::Setup::Flavor::Aki is

=head1 AUTHOR

akihiro_0228 E<lt>nano.universe.0228@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
