#!/usr/bin/perl -w

my @files = `hadoop fs -ls hdfs://p-head03.alley.sara.nl/data/public/common-crawl/parse-output/segment/1346823845675`;

#@files = <*>;
foreach $file (@files)
{
  print $file;
}

