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

  $args{extra_compiler_flags} = $alien->cflags;
  $args{extra_linker_flags}   = $alien->libs;
  $args{c_source}             = 'xs';
  
  my $cc = ExtUtils::CChecker->new( quiet => 1 );
  $cc->assert_compile_run( source => 'int main(int argc, char *argv[]) { return 0; }' );
  
  if($^O eq 'MSWin32')
  {
    $args{extra_compiler_flags} .= ' -DLIBARCHIVE_STATIC';
    $args{extra_linker_flags}    =~ s/-larchive\b/-larchive_static/;
    $args{extra_linker_flags}    =~ s/\barchive\.lib\b/archive_static.lib/;
    return $class->SUPER::new(%args);
  }
  
  my $ctest = "#include <archive.h>\n" .
              "int main(int argc, char *argv[]) {\n" .
              "  struct archive *a = archive_read_new();\n" .
              "  return 0;\n" .
              "}\n";
  my $ok = 0;

  if($alien->install_type eq 'share')
  {
    $ok = $cc->try_compile_run(
      extra_compiler_flags => [ shellwords($args{extra_compiler_flags}) ],
      extra_linker_flags   => [ '-Wl,-Bstatic', shellwords($args{extra_linker_flags}), '-Wl,-Bdynamic'],
      source               => $ctest,
    );
  
    if($ok)
    {
      $args{extra_linker_flags} = "-Wl,-Bstatic $args{extra_linker_flags} -Wl,-Bdynamic";
      return $class->SUPER::new(%args);
    }
  }

  $ok = $cc->try_compile_run(
    extra_compiler_flags => [ shellwords($args{extra_compiler_flags}) ],
    extra_linker_flags   => [ shellwords($args{extra_linker_flags}) ],
    source               => $ctest,
  );
  
  if($ok)
  {
    return $class->SUPER::new(%args);
  }

  die "unable to determine flags to compile / link against libarchive";
}

1;
