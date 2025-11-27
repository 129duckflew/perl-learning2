package Local::Storage::Test;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use Test::MockObject;
use Local::Storage;

my $mock_db  = Test::MockModule->new('Local::DB');
my $fake_dbh = Test::MockObject->new();

sub startup : Tests(startup) {
    $mock_db->mock('get_handle', sub { $fake_dbh });
}

sub setup : Tests(setup) {
    $fake_dbh->mock($_, sub { 1 }) for qw(prepare execute do selectrow_hashref selectrow_arrayref selectrow_array);
}

sub test_new : Tests {
    my $obj = Local::Storage->new(name=>"A", capacity=>10, v_id=>2);
    isa_ok($obj, 'Local::Storage');
    is($obj->name, "A");
    is($obj->capacity, 10);
    is($obj->{v_id}, 2);
}

sub test_find_null : Tests {
    $fake_dbh->mock('selectrow_hashref', sub { undef });
    my $obj = Local::Storage->find(123);
    ok(!$obj, "find() returns undef when not exists");
}

sub test_save_create : Tests {
    $fake_dbh->mock('selectrow_arrayref', sub { [5,"t1","t2"] });
    my $obj = Local::Storage->new(name=>"X", capacity=>100);
    my $id  = $obj->save();
    is($id, 5);
    is($obj->id, 5);
}

sub test_save_update : Tests {
    $fake_dbh->mock('do', sub { 1 });
    my $obj = Local::Storage->new(id=>8, name=>"U", capacity=>200);
    my $id  = $obj->save();
    is($id, 8, "update returns same id");
}

1;
