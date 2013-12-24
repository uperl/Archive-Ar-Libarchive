package inc::Doco;

use Moose;

with 'Dist::Zilla::Role::FileMunger';

sub munge_files
{
  my($self) = @_;
  my($file) = grep { $_->name eq 'lib/Archive/Ar/Libarchive.pm' } @{ $self->zilla->files };
  
  my $content = $file->content;
  $content =~ s/L<#(.*?)>/L<$1|Archive::Ar::Libarchive#$1>/g;
  $file->content($content);
}

1;
