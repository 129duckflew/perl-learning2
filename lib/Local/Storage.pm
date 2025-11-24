package Local::Storage;
use strict;
use warnings;
use Local::DB;

sub new {
    my ($class, %args) = @_;
    bless {
        id       => $args{id},
        name     => $args{name},
        capacity => $args{capacity},
    }, $class;
}

sub find_all {
    my ($class) = @_;
    my $dbh = Local::DB::get_handle();
    my $data = $dbh->selectall_arrayref("SELECT * FROM storages ORDER BY id DESC", { Slice => {} });
    return [ map { $class->new(%$_) } @$data ];
}

sub save {
    my ($self) = @_;
    my $dbh = Local::DB::get_handle();
    my $sql = "INSERT INTO storages (name, capacity) VALUES (?, ?) RETURNING id";
    my ($id) = $dbh->selectrow_array($sql, undef, $self->{name}, $self->{capacity});
    $self->{id} = $id;
}

# Getters
sub id { shift->{id} }
sub name { shift->{name} }
sub capacity { shift->{capacity} }
