package Local::VirtualMachine::Test;
use base 'Test::Class';
use Test::More;
use Test::MockModule;
use Test::MockObject;
use Local::VirtualMachine;

my $mock_dbh = Test::MockModule->new('Local::DB');
my $fake_dbh = Test::MockObject->new();

sub startup : Tests(startup) {
    $mock_dbh->mock('get_handle', sub { $fake_dbh });
}

sub setup : Tests(setup) {
    $fake_dbh->mock($_, sub { 1 }) for qw(begin_work commit rollback do prepare execute selectrow_array selectrow_arrayref selectall_hashref fetchrow_hashref);
}

sub test_new_cast : Tests {
    my $vm = Local::VirtualMachine->new(name=>"VM", os=>"Ubuntu", storage_ids=>9);
    is(ref $vm->{storage_ids}, 'ARRAY');
    is($vm->{storage_ids}[0], 9);
}

sub test_os_check : Tests {
    my $vm = Local::VirtualMachine->new(name=>"B", os=>"Mac");
    eval { $vm->save };
    like($@, qr/Invalid OS/);
}

sub test_checksum : Tests {
    my $vm = Local::VirtualMachine->new(name=>"A", os=>"CentOS", storage_ids=>[1,2], storage_ids_csv=>"1,2");
    $fake_dbh->mock('selectrow_array', sub { return undef }); # no conflict
    $fake_dbh->mock('selectrow_arrayref', sub { [15, "2025"] });
    is($vm->save, 15);
    ok($vm->checksum, "checksum generated");
}

sub test_storage_conflict : Tests {
    my $vm = Local::VirtualMachine->new(name=>"A", os=>"CentOS", storage_ids=>[3], id=>5);
    $fake_dbh->mock('selectrow_array', sub { "DiskConflict" });
    eval { $vm->save };
    like($@, qr/已被其他虚拟机绑定/);
}

sub test_delete : Tests {
    my $vm = Local::VirtualMachine->new(id=>6,name=>"D",os=>"Debian");
    my @calls;
    $fake_dbh->mock('do', sub {
        my ($dbh,$sql,undef,@p)=@_;
        push @calls, $sql;
    });
    $vm->delete;
    ok(grep { /DELETE FROM virtual_machines/ } @calls);
    ok(grep { /UPDATE storages SET v_id=NULL/ } @calls);
}

1;
