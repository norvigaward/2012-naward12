#!/usr/bin/perl -w

#this script extracts the top level domain out of an url
use URI;

while(<>)
{
  my $string1 = $_;
  my $url = URI->new($string1);
  my $domain = $url->host;
  my @domainGehakt = split('\.', $domain);
  my $lengte = scalar(@domainGehakt);
  my $output = $domainGehakt[$lengte - 1];
  print $output;
}
