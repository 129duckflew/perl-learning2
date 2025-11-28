package Local::Storage;
use strict;
use warnings;
use Local::DB;

sub new {
    my ($class, %args) = @_;
    my $self = {
        id         => $args{id},
        name       => $args{name},
        capacity   => $args{capacity},
        v_id => $args{v_id}, # 关联的虚拟机ID，可为空
        created_at => $args{created_at},
        updated_at => $args{updated_at},
    };
    bless $self, $class;
    return $self;
}

# 获取所有存储列表 (用于下拉菜单)
sub find_all {
    my ($class) = @_;
    my $dbh = Local::DB::get_handle();
    my $sth = $dbh->prepare("SELECT * FROM storages WHERE v_id IS NULL ORDER BY id DESC");
    $sth->execute();
    
    my @list;
    while (my $row = $sth->fetchrow_hashref) {
        push @list, $class->new(%$row);
    }
    return \@list;
}

sub find {
    my ($class, $id) = @_;
    my $dbh = Local::DB::get_handle();
    my $row = $dbh->selectrow_hashref("SELECT * FROM storages WHERE id = ?", undef, $id);
    return $row ? $class->new(%$row) : undef;
}

sub save {
    my ($self) = @_;
    my $dbh = Local::DB::get_handle();

    if ($self->{id}) {
        # Update
        my $sql = "UPDATE storages SET name=?, capacity=?, updated_at=NOW() WHERE id=?";
        $dbh->do($sql, undef, $self->{name}, $self->{capacity}, $self->{id});
    } else {
        # Create
        my $sql = "INSERT INTO storages (name, capacity) VALUES (?, ?) RETURNING id, created_at, updated_at";
        my $row = $dbh->selectrow_arrayref($sql, undef, $self->{name}, $self->{capacity});
        ($self->{id}, $self->{created_at}, $self->{updated_at}) = @$row;
    }
    return $self->{id};
}

# 列出所有存储（包含已绑定和未绑定）——供管理界面显示使用
sub list_all {
    my ($class) = @_;
    my $dbh = Local::DB::get_handle();
    my $rows = $dbh->selectall_arrayref("SELECT * FROM storages ORDER BY id DESC", { Slice => {} });
    my @out;
    foreach my $r (@$rows) {
        push @out, $class->new(%$r);
    }
    return \@out;
}

# 删除存储（仅允许未被 VM 绑定的存储删除）
sub delete {
    my ($self) = @_;
    my $dbh = Local::DB::get_handle();
    die "Missing id" unless $self->{id};

    # 检查是否被绑定
    my $row = $dbh->selectrow_hashref("SELECT v_id FROM storages WHERE id = ?", undef, $self->{id});
    if ($row && defined $row->{v_id} && $row->{v_id} ne '') {
        die "Storage is attached to VM (v_id=$row->{v_id}), cannot delete";
    }

    $dbh->do("DELETE FROM storages WHERE id = ?", undef, $self->{id});
    return 1;
}

# Getter needed for Template Toolkit
sub id { shift->{id} }
sub name { shift->{name} }
sub capacity { shift->{capacity} }
sub created_at { shift->{created_at} }
sub v_id { shift->{v_id} }
1;