package Archive::Ar::Libarchive;

use strict;
use warnings;
use Alien::Libarchive;
use Carp qw( carp );

# ABSTRACT: Interface for manipulating ar archives with libarchive
# VERSION

require XSLoader;
XSLoader::load('Archive::Ar::Libarchive', $VERSION);

=head1 SYNOPSIS

 use Archive::Ar::Libarchive;
 
 my $ar = Archive::Ar->new('libfoo.a');
 
 my @file_list = $ar->list_files;

=head1 DESCRIPTION

This module is a XS alternative to L<Archive::Ar> that uses libarchive to read and write ar BSD, GNU and common ar archives.

=head1 METHODS

=head2 new

 my $ar = Archive::Ar::Libarchive->new;
 my $ar = Archive::Ar::Libarchive->new($filename);
 my $ar = Archive::Ar::Libarchive->new($fh, $debug);

Returns a new L<Archive::AR::Libarchive> object.  Without a filename or glob, it returns an empty object.  If passed a filename as a scalar or a GLOB, it will attempt to populate from
either of those sources.  If it fails, you will receive undef, instead of an object reference.

This also can take a second optional debugging parameter.  This acts exactly as if L<#DEBUG> is called on the object before it is returned.  If you have a L<#new> that keeps failing, this
should help.

=cut

sub new
{
  my($class, $filename_or_handle, $debug) = @_;
  my $self = _new();
  $self->DEBUG if $debug;
  
  if($filename_or_handle)
  {
    unless($self->read($filename_or_handle))
    {
      $self->_dowarn("new() failed on filename for filehandle read");
      return;
    }
  }
  
  $self;
}

=head2 read

 $ar->read($filename);
 $ar->read($fh);

This reads a new file into the object, removing any ar archive already
represented in the object.

Returns the number of bytes read, undef on failure.

=cut

sub read
{
  my($self, $filename_or_handle) = @_;

  my $ret = 0;
  
  if(ref $filename_or_handle eq 'GLOB')
  {
    my $buffer;
    $ret = $self->_read_from_callback(sub {
      print "here\n";
      my $br = read $filename_or_handle, $buffer, 1024;
      print "br = $br\n";
      ((defined $br ? 0 : -30), \$buffer);
    });
  }
  else
  {
    $ret = $self->_read_from_filename($filename_or_handle);
  }

  return $ret || undef;
}

=head2 list_files

 my @list = $ar->list_files;
 my $list = $ar->list_files;

This lists the files contained inside of the archive by filename, as
an array. If called in a scalar context, returns a reference to an
array.

=cut

sub list_files
{
  my $list = shift->_list_files;
  wantarray ? @$list : $list;
}

=head2 DEBUG

 $ar->DEBUG;
 $ar->DEBUG(0);

This method turns on debugging.  To Turn off pass a false value in as the argument.

=cut

sub DEBUG
{
  my($self, $value) = @_;
  $value = 1 unless defined $value;
  $self->_set_debug($value);
  return;
}

sub _dowarn
{
  my($self, $warning) = @_;
  carp $warning if $self->_get_debug;
  return;
}

1;

=head1 SEE ALSO

=over 4

=item L<Alien::Libarchive>

=item L<Archive::Ar>

=back

=cut
