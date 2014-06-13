package My::ModuleBuild;

use strict;
use warnings;
use Alien::Libarchive;
use ExtUtils::CChecker;
use Text::ParseWords qw( shellwords );
use base qw( Module::Build );

my $alien;

sub _other_checks
{
  my($self, $cc, $args) = @_;
  
  my $has_archive_read_next_header2 = $cc->try_compile_run(
    extra_compiler_flags => [ shellwords($args->{extra_compiler_flags}) ],
    extra_linker_flags   => [ shellwords($args->{extra_linker_flags}) ],
    source               => 
      "#include <archive.h>\n" .
      "#include <archive_entry.h>\n" .
      "int main(int argc, char *argv[])\n" .
      "{\n" .
      "  struct archive *a;\n" .
      "  struct archive_entry *e;\n" .
      "  a = archive_read_new();\n" .
      "  archive_read_next_header2(a, e);\n" .
      "  return 0;\n" .
      "}\n",
  );
  
  if($has_archive_read_next_header2)
  {
    $args->{extra_compiler_flags} .= " -DHAS_has_archive_read_next_header2";
    print "Looks like you have archive_read_next_header2, I will be using it\n";
  }
  else
  {
    print "Looks like you don't have archive_read_next_header2, I will use has_archive_read_next_header instead\n";
  }  
}

sub new
{
  my($class, %args) = @_;
  
  $alien ||= Alien::Libarchive->new;

  $args{extra_compiler_flags} = $alien->cflags;
  $args{extra_linker_flags}   = $alien->libs;
  $args{c_source}             = 'xs';
  
  return $class->SUPER::new(%args) unless $alien->isa('Alien::Base');

  # The rest of this is only necessary if using the older broken
  # Alien::Base version of Alien::Libarchive
  
  my $cc = ExtUtils::CChecker->new( quiet => 1 );
  $cc->assert_compile_run( source => 'int main(int argc, char *argv[]) { return 0; }' );
  
  if($^O eq 'MSWin32')
  {
    if($alien->isa('Alien::Base'))
    {
      $args{extra_compiler_flags} .= ' -DLIBARCHIVE_STATIC';
      $args{extra_linker_flags}    =~ s/-larchive\b/-larchive_static/;
      $args{extra_linker_flags}    =~ s/\barchive\.lib\b/archive_static.lib/;
    }
    __PACKAGE__->_other_checks($cc, \%args);
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
      __PACKAGE__->_other_checks($cc, \%args);
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
    __PACKAGE__->_other_checks($cc, \%args);
    return $class->SUPER::new(%args);
  }

  die "unable to determine flags to compile / link against libarchive";
}

1;
