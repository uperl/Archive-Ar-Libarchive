use strict;
use warnings;
use Test::More tests => 4;
use File::Temp qw( tempdir );
use File::Spec;
use Archive::Ar::Libarchive;

my $dir = tempdir( CLEANUP => 1 );
my $fn  = File::Spec->catfile($dir, 'foo.ar');

note "fn = $fn";

do { 
  open my $fh, '>', $fn;
  while(<DATA>) {
    chomp;
    print $fh unpack('u', $_);
  }
  close $fh;
};

my $ar = Archive::Ar::Libarchive->new($fn);
isa_ok $ar, 'Archive::Ar::Libarchive';

foreach my $name (qw( foo bar baz ))
{
  use YAML ();
  diag $name;
  diag YAML::Dump($ar->get_content("$name.txt"));
}

is $ar->get_content("foo.txt")->{data}, "hi there\n";
is $ar->get_content("bar.txt")->{data}, "this is the content of bar.txt\n";
is $ar->get_content("baz.txt")->{data}, "and again.\n";


__DATA__
M(3QA<F-H/@IF;V\N='AT("`@("`@("`@,3,X-#,T-#0R,R`@,3`P,"`@,3`P
M,"`@,3`P-C0T("`Y("`@("`@("`@8`IH:2!T:&5R90H*8F%R+G1X="`@("`@
M("`@(#$S.#0S-#0T,C,@(#$P,#`@(#$P,#`@(#$P,#8T-"`@,S$@("`@("`@
M(&`*=&AI<R!I<R!T:&4@8V]N=&5N="!O9B!B87(N='AT"@IB87HN='AT("`@
M("`@("`@,3,X-#,T-#0R,R`@,3`P,"`@,3`P,"`@,3`P-C0T("`Q,2`@("`@
1("`@8`IA;F0@86=A:6XN"@H`
