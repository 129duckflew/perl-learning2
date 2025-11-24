package Local::DB;
use strict;
use warnings;
use DBI;

my $DBH;
# 请修改为你的数据库配置
my $DB_DSN  = "dbi:Pg:dbname=postgres;host=localhost;port=5432";
my $DB_USER = "postgres"; 
my $DB_PASS = "your_password";

sub get_handle {
    return $DBH if $DBH && $DBH->ping;
    $DBH = DBI->connect($DB_DSN, $DB_USER, $DB_PASS, {
        RaiseError => 1,
        AutoCommit => 1,
        PrintError => 0,
        pg_enable_utf8 => 1,
    }) or die $DBI::errstr;
    return $DBH;
}