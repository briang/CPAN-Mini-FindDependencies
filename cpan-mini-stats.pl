#!/usr/local/bin/perl

use 5.010;

use strict;
use warnings FATAL => 'all';
#use diagnostics;

use Data::Dump;
#use Carp qw();

$|=1;
################################################################################
use Archive::Tar;
use CPAN::DistnameInfo;
use File::Find::Rule;
use Time::HiRes qw(time);

# Archives:            22,720
# Unknown suffix:          32
# Corrupt archive:         28
# With META.json:       1,321
# Without META.yml:     4,934
# Unparsable META.yml:    129
# OK:                  17,597
# Time:                   638.3 seconds

my @all_cpan = grep {
    ! /CHECKSUMS$/
} File::Find::Rule->file->in('/mirrors/cpan/authors/id');

say 0+@all_cpan, " archives";

my $time = time;
my ($bad_suffix, $bad_archive, $has_meta_json, $no_meta_yml, $bad_yaml, $good, $n) = (0) x 99;
for my $archive (@all_cpan) {
#last if $n >= 1000;
    print "\r$n" unless ++$n % 100;
    state $tar = Archive::Tar->new;
    $Archive::Tar::WARN = 0;

    $bad_suffix++, next
      unless CPAN::DistnameInfo->new($archive)->extension;

    $Archive::Tar::error = '';
    $tar->read(join "/", $archive);
    $bad_archive++, next
      unless $tar->error;

    my ($meta_json) = grep { m{^[^/]*/META\.json} } $tar->list_files;
    $has_meta_json++
      if $meta_json;

    my ($meta) = grep { m{^[^/]*/META\.yml} } $tar->list_files;
    $no_meta_yml++, next
      unless $meta;

    my $yaml = $tar->get_content( $meta );
    $yaml = eval { YAML::Tiny::Load($yaml) };
    $bad_yaml++, next
      if $@;

    $good++;

}
$time = time - $time;

say <<EOP;

Unknown suffix:      $bad_suffix
Corrupt archive:     $bad_archive
With META.json:      $has_meta_json
Without META.yml:    $no_meta_yml
Unparsable META.yml: $bad_yaml
OK:                  $good
EOP
printf "Time:                %.1f seconds\n", $time;
