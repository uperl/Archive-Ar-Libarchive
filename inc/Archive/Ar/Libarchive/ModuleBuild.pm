package Archive::Ar::Libarchive::ModuleBuild;

use strict;
use warnings;
use Alien::Libarchive;
use base qw( Module::Build );

my $alien;

sub new
{
  my($class, %args) = @_;
  
  $alien ||= Alien::Libarchive->new;

  my $cflags = $alien->cflags;
  my $libs   = $alien->libs;
  
  if($^O eq 'MSWin32')
  {
    $cflags .= ' -DLIBARCHIVE_STATIC';
    $libs =~ s/-larchive\b/-larchive_static/;
  }
  
  $args{extra_compiler_flags} = $cflags;
  $args{extra_linker_flags}   = $libs;
  $args{c_source}             = 'xs';
  
  $class->SUPER::new(%args);
}

1;
