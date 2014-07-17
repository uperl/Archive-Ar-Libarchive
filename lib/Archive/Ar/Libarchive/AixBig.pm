package Archive::Ar::Libarchive::AixBig;

use strict;
use warnings;

# ABSTRACT: Machinery for dealing with ar files of the AIX (big) format
# VERSION

=head1 SYNOPSIS

 use Archive::Ar::Libarchive;

=head1 DESCRIPTION

This module contains the machinery for dealing with ar archive files
that are in the AIX (big) format for L<Archive::Ar::Libarchive>.  It
doesn't provide any public interfaces.

=head1 SEE ALSO

=over 4

=item

L<Archive::Ar::Libarchive>

=item

L<Archive::Ar>

=back

=cut

sub read
{
  my($ar, $sig, $fh) = @_;
  my $data = $sig . do { local $/; <$fh> };
  my $fl_hdr = get_fl_hdr($data);
  my $ar_hdr = $fl_hdr->first($data);
  while($ar_hdr)
  {
    $ar->add_data($ar_hdr->ar_name, "TODO", {
      uid  => $ar_hdr->ar_uid,
      gid  => $ar_hdr->ar_gid,
      date => $ar_hdr->ar_date,
      mode => $ar_hdr->ar_mode,
    });
    $ar_hdr = $ar_hdr->next($data, $fl_hdr);
  }
  return length $data;
}

1;
