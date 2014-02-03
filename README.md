# Archive::Ar::Libarchive [![Build Status](https://secure.travis-ci.org/plicease/Archive-Ar-Libarchive.png)](http://travis-ci.org/plicease/Archive-Ar-Libarchive)

Interface for manipulating ar archives with libarchive

# SYNOPSIS

    use Archive::Ar::Libarchive;
    
    my $ar = Archive::Ar->new('libfoo.a');
    
    $ar->add_data('newfile.txt', 'some contents', { uid => 101, gid => 102 });
    
    $ar->add_files('./bar.tar.gz', 'bat.pl');
     
    $ar->remove('file1', 'file2');
    
    my $content = $ar->get_content('file3')->{data};
    
    my @files = $ar->list_files;
    
    $ar->write('libbar.a');
    
    my @file_list = $ar->list_files;

# DESCRIPTION

This module is a XS alternative to [Archive::Ar](https://metacpan.org/pod/Archive::Ar) that uses libarchive 
to read and write ar BSD, GNU and common ar archives.

There is no standard for the ar format.  Most modern archives are based 
on a common format with two extension variants, BSD and GNU.  Other 
esoteric variants (such as AIX (small), AIX (big) and Coherent) vary 
significantly from the common format and are not supported.  Debian's 
package format (.deb files) use the common format.

The interface attempts to be identical (with a couple of minor 
extensions) to [Archive::Ar](https://metacpan.org/pod/Archive::Ar) and the documentation presented here is 
based on that module. The diagnostic messages issued on error mostly 
come directly from libarchive, so they will likely not match exactly 
what [Archive::Ar](https://metacpan.org/pod/Archive::Ar) would produce, but it should issue a warning (when 
[Archive::Ar::Libarchive#DEBUG](https://metacpan.org/pod/Archive::Ar::Libarchive#DEBUG) is turned on) under similar 
circumstances.

The main advantage of [Archive::Ar](https://metacpan.org/pod/Archive::Ar) over this module is that it is 
written in pure perl, and thus does not require a compiler or 
libarchive.  The advantage of this module (at least as of this writing) 
is that it supports GNU (read) and BSD (read and write) extensions for 
longer member filenames.  As an XS module using libarchive it may also
be faster.

# METHODS

## new

    my $ar = Archive::Ar::Libarchive->new;
    my $ar = Archive::Ar::Libarchive->new($filename);
    my $ar = Archive::Ar::Libarchive->new($fh, $debug);

Returns a new [Archive::AR::Libarchive](https://metacpan.org/pod/Archive::AR::Libarchive) object.  Without a filename or 
glob, it returns an empty object.  If passed a filename as a scalar or a 
GLOB, it will attempt to populate from either of those sources.  If it 
fails, you will receive undef, instead of an object reference.

This also can take a second optional debugging parameter.  This acts 
exactly as if [Archive::Ar::Libarchive#DEBUG](https://metacpan.org/pod/Archive::Ar::Libarchive#DEBUG) is called on the object 
before it is returned.  If you have a [Archive::Ar::Libarchive#new](https://metacpan.org/pod/Archive::Ar::Libarchive#new) 
that keeps failing, this should help.

## read

    my $br = $ar->read($filename);
    my $br = $ar->read($fh);

This reads a new file into the object, removing any ar archive already
represented in the object.

Returns the number of bytes read, undef on failure.

## read\_memory

    my $br = $ar->read_memory($data);

This reads information from the first parameter, and attempts to parse 
and treat it like an ar archive. Like [Archive::Ar::Libarchive#read](https://metacpan.org/pod/Archive::Ar::Libarchive#read), 
it will wipe out whatever you have in the object and replace it with the 
contents of the new archive, even if it fails. Returns the number of 
bytes read (processed) if successful, undef otherwise.

## list\_files

    my @list = $ar->list_files;
    my $list = $ar->list_files;

This lists the files contained inside of the archive by filename, as
an array. If called in a scalar context, returns a reference to an
array.

## add\_files

    $ar->add_files(@filenames);
    $ar->add_files(\@filenames);

Takes an array or an arrayref of filenames to add to the ar archive,
in order. The filenames can be paths to files, in which case the path
information is stripped off. Filenames longer than 16 characters are
truncated when written to disk in the format, so keep that in mind
when adding files.

Due to the nature of the ar archive format, 
[Archive::Ar::Libarchive#add\_files](https://metacpan.org/pod/Archive::Ar::Libarchive#add_files) will store the uid, gid, mode, 
size, and creation date of the file as returned by 
[stat](https://metacpan.org/pod/perlfunc#stat).

returns the number of files successfully added, or undef on failure.

## add\_data

    my $size = $ar->add_data($filename, $data, $filedata);

Takes an filename and a set of data to represent it. Unlike 
[Archive::Ar::Libarchive#add\_files](https://metacpan.org/pod/Archive::Ar::Libarchive#add_files), 
[Archive::Ar::Libarchive#add\_data](https://metacpan.org/pod/Archive::Ar::Libarchive#add_data) is a virtual add, and does not 
require data on disk to be present. The data is a hash that looks like:

    $filedata = {
      uid  => $uid,   #defaults to zero
      gid  => $gid,   #defaults to zero
      date => $date,  #date in epoch seconds. Defaults to now.
      mode => $mode,  #defaults to 0100644;
    };

You cannot add\_data over another file however.  This returns the file 
length in bytes if it is successful, undef otherwise.

## write

    my $content = $ar->write;
    my $size = $ar->write($filename);

This method will return the data as an .ar archive, or will write to the 
filename present if specified. If given a filename, 
[Archive::Ar::Libarchive#write](https://metacpan.org/pod/Archive::Ar::Libarchive#write) will return the length of the file 
written, in bytes, or undef on failure. If the filename already exists, 
it will overwrite that file.

## get\_content

    my $hash = get_content($filename);

This returns a hash with the file content in it, including the data that the
file would naturally contain.  If the file does not exist or no filename is
given, this returns undef. On success, a hash is returned with the following
keys:

- name

    The file name

- date

    The file date (in epoch seconds)

- uid

    The uid of the file

- gid

    The gid of the file

- mode

    The mode permissions

- size

    The size (in bytes) of the file

- data

    The contained data

## remove

    my $count = $ar->remove(@pathnames);
    my $count = $ar->remove(\@pathnames);

The remove method takes a filenames as a list or as an arrayref, and removes
them, one at a time, from the Archive::Ar object.  This returns the number
of files successfully removed from the archive.

## set\_output\_format\_bsd

    $ar->set_output_format_bsd;

Sets the output format produced by [Archive::Ar::Libarchive#write](https://metacpan.org/pod/Archive::Ar::Libarchive#write) to 
use BSD format. Note: this method is not available in [Archive::Ar](https://metacpan.org/pod/Archive::Ar).

## set\_output\_format\_svr4

    $ar->set_output_format_svr4;

Sets the output format produced by [Archive::Ar::Libarchive#write](https://metacpan.org/pod/Archive::Ar::Libarchive#write) to 
System VR4 format. Note: this method is not available in [Archive::Ar](https://metacpan.org/pod/Archive::Ar).

## DEBUG

    $ar->DEBUG;
    $ar->DEBUG(0);

This method turns on debugging.  To Turn off pass a false value in as 
the argument.

# SEE ALSO

- [Alien::Libarchive](https://metacpan.org/pod/Alien::Libarchive)
- [Archive::Ar](https://metacpan.org/pod/Archive::Ar)

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
