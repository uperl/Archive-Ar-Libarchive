use strict;
use warnings;
use FindBin ();
use Archive::Ar::Libarchive qw( AIX_BIG );
use File::Spec;
use Test::More tests => 9;

$Archive::Ar::Libarchive::enable_aix = 1;

my $ar = Archive::Ar::Libarchive->new;
my $fn = File::Spec->catfile($FindBin::Bin, 'foo.aixbig.ar');
ok $ar->read($fn), 'read okay';

is $ar->get_opt('type'), AIX_BIG, 'type detection';

is_deeply [$ar->list_files], [ qw( bar.txt baz.txt foo.txt )], 'filenames match';

foreach my $name (map { "$_.txt" } qw( foo bar baz ))
{
  subtest "values $name" => sub {
    my $h = $ar->get_content($name);
    is $h->{name}, $name, "name = $name";
    like $h->{date}, qr{^[0-9]+$}, "date = " . $h->{date};
    is $h->{uid}, 1000, "uid = 1000";
    is $h->{gid}, 1000, "gid = 1000";
    is $h->{mode}, 0100644, "mode = 0100644";
  };
}

is $ar->get_data('foo.txt'), "hi there\n";
is $ar->get_data('bar.txt'), "this is the content of bar.txt\n";
is $ar->get_data('baz.txt'), "and again.\n";
