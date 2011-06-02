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
use CPAN::Meta;
use File::Find::Rule;
use Time::HiRes qw(time);

# Archives:             22,720
# Unknown suffix:           32
# Corrupt archive:          28
# With META.json:        1,321
# With META.yml:        17,726
# With both:             1,266
# Unparsable META.yml:     163
# Unparsable META.json:      0
# OK:                   17,618
# Time:                    618.3 seconds

my @all_cpan = grep {
    ! /CHECKSUMS$/
} File::Find::Rule->file->in('/mirrors/cpan/authors/id');

my $time = time;

my ($bad_suffix, $bad_archive, $has_meta_json,
    $has_meta_yml, $has_both, $bad_yaml, $bad_json, $good, $n) = (0) x 99;

for my $archive (@all_cpan) {
    #last if $n >= 300;
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

    my ($meta_yml) = grep { m{^[^/]*/META\.yml} } $tar->list_files;
    $has_meta_yml++,
      if $meta_yml;

    $has_both++
      if $meta_json && $meta_yml;

    my $meta_any = $tar->get_content( $meta_yml // $meta_json );
    my $meta;
    if ($meta_yml) {
        $meta = eval { CPAN::Meta->load_yaml_string($meta_any) };
        $bad_yaml++, next
          if $@;
    }
    elsif ($meta_json) {
        $meta = eval { CPAN::Meta->load_json_string($meta_any) };
        $bad_json++, next
          if $@;
    }
    else { next }

    $good++;
}
$time = time - $time;

say "\rArchives:             " . @all_cpan;
say <<EOP;
Unknown suffix:       $bad_suffix
Corrupt archive:      $bad_archive
With META.json:       $has_meta_json
With META.yml:        $has_meta_yml
With both:            $has_both
Unparsable META.yml:  $bad_yaml
Unparsable META.json: $bad_json
OK:                   $good
EOP
printf "Time:                 %.1f seconds\n", $time;
