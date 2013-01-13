#!/usr/bin/perl -w

my @files = `hadoop fs -ls hdfs://p-head03.alley.sara.nl/data/public/common-crawl/parse-output/segment/1346823845675`;
foreach $file (@files)
{
  $file = substr $file, 33;
}


#-rw-r--r--   3 evert evert   38810225 2012-09-09 22:20 /data/public/common-crawl/parse-output/segment/1346823845675/1346867516861_1743.arc.gz
