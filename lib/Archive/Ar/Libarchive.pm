package Archive::Ar::Libarchive;

use strict;
use warnings;
use Alien::Libarchive;
use Carp qw( carp );
use File::Basename qw( basename );

# ABSTRACT: Interface for manipulating ar archives with libarchive
# VERSION

require XSLoader;
XSLoader::load('Archive::Ar::Libarchive', $VERSION);

=head1 SYNOPSIS

 use Archive::Ar::Libarchive;
 
 my $ar = Archive::Ar->new('libfoo.a');
 
 $ar->add_data('newfile.txt', 'some contents', { uid => 101, gid => 102 });
 
 $ar->add_files('./bar.tar.gz', 'bat.pl');
  
 $ar->remove('file1', 'file2');
 
 my $content = $ar->get_content('file3')->{data};
 
 my @files = $ar->list_files;
 
 $ar->write('libbar.a');
 
 my @file_list = $ar->list_files;

=head1 DESCRIPTION

This module is a XS alternative to L<Archive::Ar> that uses libarchive to read and write ar BSD, GNU and common ar archives.

There is no standard for the ar format.  Most modern archives are based on a common format with two extension variants, BSD and GNU.  Other
esoteric variants (such as AIX (small), AIX (big) and Coherent) vary significantly from the common format and are not supported.  Debian's
package format (.deb files) use the common format.

The interface attempts to be identical (with a couple of minor extensions) to L<Archive::Ar> and the documentation presented here is based on that module.
The diagnostic messages issued on error mostly come directly from libarchive, so they will likely not match exactly what L<Archive::Ar> would produce,
but it should issue a warning (when L<#DEBUG> is turned on) under similar circumstances.

The main advantage of L<Archive::Ar> over this module is that it is written in pure perl, and thus does not require a compiler or libarchive.  The advantage of this module
(at least as of this writing) is that it supports GNU and BSD extensions for longer member filenames.

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
      return $self->_warn("new() failed on filename for filehandle read");
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

=head2 add_files

 $ar->add_files(@filenames);
 $ar->add_files(\@filenames);

Takes an array or an arrayref of filenames to add to the ar archive,
in order. The filenames can be paths to files, in which case the path
information is stripped off. Filenames longer than 16 characters are
truncated when written to disk in the format, so keep that in mind
when adding files.

Due to the nature of the ar archive format, L<#add_files> will store
the uid, gid, mode, size, and creation date of the file as returned by
L<stat|perlfunc#stat>.

returns the number of files successfully added, or undef on failure.

=cut

sub add_files
{
  my $self = shift;
  my $count = 0;
  foreach my $filename (@{ ref $_[0] ? $_[0] : \@_ })
  {
    unless(-r $filename)
    {
      $self->_warn("No such file: $filename");
      next;
    }
    my @props = stat($filename);
    unless(@props)
    {
      $self->_warn("Could not stat $filename.");
      next;
    }
    
    open(my $fh, '<', $filename) || do {
      $self->_warn("Unable to open $filename $!");
      next;
    };
    binmode $fh;
    # TODO: we don't check for error on the actual
    # read operation (but then nethier does
    # Archive::Ar).
    my $data = do { local $/; <$fh> };
    close $fh;
    
    $self->add_data(basename($filename), $data, {
      date => $props[9],
      uid  => $props[4],
      gid  => $props[5],
      mode => $props[2],
      size => length $data,
    });
    $count++;
  }
  
  return unless $count;
  $count;
}

=head2 add_data

 my $size = $ar->add_data($filename, $data, $filedata);

Takes an filename and a set of data to represent it. Unlike L<#add_files>, L<#add_data>
is a virtual add, and does not require data on disk to be present. The
data is a hash that looks like:

 $filedata = {
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
  my($self, $filename, $data, $filedata) = @_;
  $filedata ||= {};
  $self->_add_data($filename, $data, $filedata->{uid} || 0, $filedata->{gid} || 0, $filedata->{date} || time, $filedata->{mode} || 0100644);
  use bytes;
  length $data;
}

=head2 write

 my $content = $ar->write;
 my $size = $ar->write($filename);

This method will return the data as an .ar archive, or will write to
the filename present if specified. If given a filename, L<#write> will
return the length of the file written, in bytes, or undef on failure.
If the filename already exists, it will overwrite that file.

=cut

sub write
{
  my($self, $filename) = @_;
  if(defined $filename)
  {
    my $status = $self->_write_to_filename($filename);
    return unless $status;
    return $status;
  }
  else
  {
    #my $content = '';
    ## TODO: doesn't work
    #my $status = $self->_write_to_callback(sub {
    #  my($archive, $buffer) = @_;
    #  $content .= $buffer;
    #  length $buffer;
    #});
    
    use File::Temp qw( tempdir );
    use File::Spec;
    my $dir = tempdir( CLEANUP => 1 );
    my $fn = File::Spec->catfile($dir, 'archive.ar');
    my $status = $self->_write_to_filename($fn);
    return unless $status;
    
    open my $fh, '<', $fn;
    my $data = do { local $/; <$fh> };
    close $fh;
    unlink $fn;
    
    return $data;
  }
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

=head2 set_output_format_bsd

 $ar->set_output_format_bsd;

Sets the output format produced by L<#write> to use BSD format.
Note: this method is not available in l<Archive::Ar>.

=head2 set_output_format_svr4

 $ar->set_output_format_svr4;

Sets the output format produced by L<#write> to System VR4 format.
Note: this method is not available in l<Archive::Ar>.

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

sub _warn
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
