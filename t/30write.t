#!/usr/bin/perl -w

use strict;
use warnings;
use Test::More (tests => 2);

use Archive::Ar::Libarchive();

my ($padding_archive) = new Archive::Ar::Libarchive();
$padding_archive->add_data("test.txt", "here\n");
my ($archive_results) = $padding_archive->write();
ok(length($archive_results) == 74, "Archive::Ar::Libarchive pads un-even number of bytes successfully\n");
$padding_archive = new Archive::Ar::Libarchive();
$padding_archive->add_data("test.txt", "here1\n");
$archive_results = $padding_archive->write();
ok(length($archive_results) == 74, "Archive::Ar::Libarchive pads even number of bytes successfully\n");
