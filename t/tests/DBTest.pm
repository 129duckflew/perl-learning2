package Local::DB::Test;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use Test::MockObject;
use Local::DB;

my $mock_dbi = Test::MockModule->new('DBI');
my @connect_calls;
my $fake_dbh;

sub startup : Tests(startup) {
    $mock_dbi->mock('connect', sub {
        my ($dsn, $user, $pass, $attr) = @_;
        push @connect_calls, { dsn=>$dsn, user=>$user, pass=>$pass, attr=>$attr };

        $fake_dbh = bless { ping_ok => 1 }, 'DBI::db';
        *DBI::db::ping = sub { shift->{ping_ok} };
        return $fake_dbh;
    });
}

sub setup : Tests(setup) {
    @connect_calls = ();
    $fake_dbh->{ping_ok} = 1 if $fake_dbh;
    $Local::DB::DBH = undef;
}

sub test_first_connect : Tests {
    my $dbh = Local::DB::get_handle();
    isa_ok($dbh, 'DBI::db');
    is(@connect_calls, 1, "should connect once on first call");
}

sub test_cache_when_ping_ok : Tests {
    my $dbh1 = Local::DB::get_handle();
    ok($dbh1->ping);

    my $dbh2 = Local::DB::get_handle();
    is($dbh2, $dbh1, "cached handle returned when ping OK");
    is(@connect_calls, 1, "must NOT reconnect when cached is alive");
}

sub test_reconnect_on_ping_fail : Tests {
    my $dbh1 = Local::DB::get_handle();
    $dbh1->{ping_ok} = 0;
    ok(!$dbh1->ping);

    my $dbh2 = Local::DB::get_handle();
    is(@connect_calls, 2, "must reconnect when ping fails");
    isnt($dbh1, $dbh2, "reconnected handle must be new instance");
}

1;
