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
  
  $args{extra_compiler_flags} = $alien->cflags;
  $args{extra_linker_flags}   = $alien->libs;
  $args{c_source}             = 'xs';
  
  $class->SUPER::new(%args);
}

1;
