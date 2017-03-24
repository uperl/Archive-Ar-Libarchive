use strict;
use warnings;
use FindBin ();
use Archive::Ar::Libarchive qw( AIX_BIG );
use File::Spec;
use Test::More tests => 3;

my $ar = Archive::Ar::Libarchive->new;
my $fn = File::Spec->catfile($FindBin::Bin, 'foo.aixbig.ar');
ok $ar->read($fn), 'read okay';

is $ar->get_opt('type'), AIX_BIG, 'type detection';

is_deeply [$ar->list_files], [ qw( bar.txt baz.txt foo.txt )], 'filenames match';
