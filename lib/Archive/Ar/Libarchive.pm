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

 my $br = $ar->read($filename);
 my $br = $ar->read($fh);

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
      my $br = read $filename_or_handle, $buffer, 1024;
      ((defined $br ? 0 : -30), \$buffer);
    });
    close $filename_or_handle;
  }
  else
  {
    $ret = $self->_read_from_filename($filename_or_handle);
  }

  $ret || undef;
}

=head2 read_memory

 my $br = $ar->read_memory($data);

This reads information from the first parameter, and attempts to parse and treat
it like an ar archive. Like L<#read>, it will wipe out whatever you have in the
object and replace it with the contents of the new archive, even if it fails.
Returns the number of bytes read (processed) if successful, undef otherwise.

=cut

sub read_memory
{
  my($self, $data) = @_;
  
  open my $fh, '<', \$data;
  my $ret = $self->read($fh);
  
  $ret;
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

=head2 add_data

 my $size = $ar->add_data($filename, $filedata);

Takes an filename and a set of data to represent it. Unlike L<#add_files>, L<#add_data>
is a virtual add, and does not require data on disk to be present. The
data is a hash that looks like:

 $filedata = {
   data => $data,
   uid  => $uid,   #defaults to zero
   gid  => $gid,   #defaults to zero
   date => $date,  #date in epoch seconds. Defaults to now.
   mode => $mode,  #defaults to 0100644;
 };

You cannot add_data over another file however.  This returns the file length in
bytes if it is successful, undef otherwise.

=cut

sub add_data
{
  my($self, $filename, $data) = @_;
  $self->_add_data($filename, $data->{data}, $data->{uid} || 0, $data->{gid} || 0, $data->{date} || time, $data->{mode} || 0100644);
  use bytes;
  length $data->{data};
}

=head2 get_content

 my $hash = get_content($filename);

This returns a hash with the file content in it, including the data that the
file would naturally contain.  If the file does not exist or no filename is
given, this returns undef. On success, a hash is returned with the following
keys:

=over 4

=item name

The file name

=item date

The file date (in epoch seconds)

=item uid

The uid of the file

=item gid

The gid of the file

=item mode

The mode permissions

=item size

The size (in bytes) of the file

=item data

The contained data

=back

=head2 remove

 my $count = $ar->remove(@pathnames);
 my $count = $ar->remove(\@pathnames);

The remove method takes a filenames as a list or as an arrayref, and removes
them, one at a time, from the Archive::Ar object.  This returns the number
of files successfully removed from the archive.

=cut

sub remove
{
  my $self = shift;
  my $count = 0;
  foreach my $pathname (@{ ref $_[0] ? $_[0] : \@_ })
  {
    $count += $self->_remove($pathname);
  }
  $count;
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
