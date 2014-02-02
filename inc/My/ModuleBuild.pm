package My::ModuleBuild;

use strict;
use warnings;
use Alien::Libarchive;
use ExtUtils::CChecker;
use Text::ParseWords qw( shellwords );
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

  my $cc = ExtUtils::CChecker->new;
  $cc->push_extra_compiler_flags(shellwords $cflags);
  $cc->push_extra_linker_flags(shellwords $libs);
  
  my $ctest = "#include <archive.h>\n" .
              "int main(int argc, char *argv[]) {\n" .
              "  struct archive *a = archive_read_new();\n" .
              "  return 0;\n" .
              "}\n";
  
  my $ok = $cc->try_compile_run(
    source => $ctest,
  );
  
  unless($ok)
  {
    $libs = "-Wl,-Bstatic $libs -Wl,-Bdynamic"
      if $alien->install_type eq 'share';
    my $cc = ExtUtils::CChecker->new;
    $cc->push_extra_compiler_flags(shellwords $cflags);
    $cc->push_extra_linker_flags(shellwords($libs));
    $cc->assert_compile_run(
      diag => 'unable to link against libarchive',
      source => $ctest,
    );
  }
  
  $args{extra_compiler_flags} = $cflags;
  $args{extra_linker_flags}   = $libs;
  $args{c_source}             = 'xs';
  
  $class->SUPER::new(%args);
}

1;
