# Archive::Ar::Libarchive [![Build Status](https://secure.travis-ci.org/plicease/Archive-Ar-Libarchive.png)](http://travis-ci.org/plicease/Archive-Ar-Libarchive)

Interface for manipulating ar archives with libarchive

# SYNOPSIS

    use Archive::Ar::Libarchive;
    
    my $ar = Archive::Ar->new('libfoo.a');
    
    my @file_list = $ar->list_files;

# DESCRIPTION

This module is a XS alternative to [Archive::Ar](https://metacpan.org/pod/Archive::Ar) that uses libarchive to read and write ar BSD, GNU and common ar archives.

# METHODS

## new

    my $ar = Archive::Ar::Libarchive->new;
    my $ar = Archive::Ar::Libarchive->new($filename);
    my $ar = Archive::Ar::Libarchive->new($fh, $debug);

Returns a new [Archive::AR::Libarchive](https://metacpan.org/pod/Archive::AR::Libarchive) object.  Without a filename or glob, it returns an empty object.  If passed a filename as a scalar or a GLOB, it will attempt to populate from
either of those sources.  If it fails, you will receive undef, instead of an object reference.

This also can take a second optional debugging parameter.  This acts exactly as if [#DEBUG](https://metacpan.org/pod/#DEBUG) is called on the object before it is returned.  If you have a [#new](https://metacpan.org/pod/#new) that keeps failing, this
should help.

## read

    my $br = $ar->read($filename);
    my $br = $ar->read($fh);

This reads a new file into the object, removing any ar archive already
represented in the object.

Returns the number of bytes read, undef on failure.

## read\_memory

    my $br = $ar->read_memory($data);

This reads information from the first parameter, and attempts to parse and treat
it like an ar archive. Like [#read](https://metacpan.org/pod/#read), it will wipe out whatever you have in the
object and replace it with the contents of the new archive, even if it fails.
Returns the number of bytes read (processed) if successful, undef otherwise.

## list\_files

    my @list = $ar->list_files;
    my $list = $ar->list_files;

This lists the files contained inside of the archive by filename, as
an array. If called in a scalar context, returns a reference to an
array.

## remove

    my $count = $ar->remove(@pathnames);
    my $count = $ar->remove(\@pathnames);

The remove method takes a filenames as a list or as an arrayref, and removes
them, one at a time, from the Archive::Ar object.  This returns the number
of files successfully removed from the archive.

## DEBUG

    $ar->DEBUG;
    $ar->DEBUG(0);

This method turns on debugging.  To Turn off pass a false value in as the argument.

# SEE ALSO

- [Alien::Libarchive](https://metacpan.org/pod/Alien::Libarchive)
- [Archive::Ar](https://metacpan.org/pod/Archive::Ar)

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
