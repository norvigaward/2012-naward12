#!/usr/bin/perl -w

#this script extracts the top level domain out of an url
use URI;

$/ = "\t";
while(<>)
{
  my $string1 = $_;
  $/ = "\n";
  $_ = <>;
  $errorcode = $_;
  my $url = URI->new($string1);
  my $domain = $url->host;
  my @domainGehakt = split('\.', $domain);
  my $lengte = scalar(@domainGehakt);
  my $output = $domainGehakt[$lengte - 1];
  my $string2 = $url->as_string;
  print "$string2\t$output\t$errorcode";
  $/ = "\t";
}
