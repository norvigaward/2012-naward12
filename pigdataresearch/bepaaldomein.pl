#!/usr/bin/perl -w

while(<>)
{
  my $url = $_;
  chomp($url);
  $url = URI->new($url);
  $domain = $url->host;
  print $domain;
}
