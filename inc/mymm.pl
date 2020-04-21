package mymm;

use strict;
use warnings;
use Alien::Base::Wrapper qw( !export Alien::Libarchive3 );
use ExtUtils::MakeMaker ();

sub myWriteMakefile
{
  my %args = @_;

  my %alien = Alien::Base::Wrapper->mm_args;
  $alien{INC} = defined $alien{INC} ? "$alien{INC} -Ixs" : "-Ixs";

  delete $args{PM};
  $args{XSMULTI} = 1;
  $args{XSBUILD} = {
    xs => {
      'lib/Archive/Ar/Libarchive' => {
        OBJECT => 'lib/Archive/Ar/Libarchive$(OBJ_EXT) xs/perl_math_int64$(OBJ_EXT)',
        %alien,
      },
    },
  };

  %args = (%args, %alien);

  ExtUtils::MakeMaker::WriteMakefile(%args);
}

1;
