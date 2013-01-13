#!/usr/bin/perl -w
    
@files = `hadoop fs -ls hdfs://p-head03.alley.sara.nl/data/public/common-crawl/parse-output/segment/1346823845675`;
foreach $file (@files)
{
  $file = "hdfs://p-head03.alley.sara.nl".(substr $file, 55);
}    
    
$pigString = "register '//home//participant//git//commoncrawl-examples//lib//*.jar'; 
register '//home//participant//git//commoncrawl-examples//dist//lib//commoncrawl-examples-1.0.1-HM.jar'; a = LOAD '^1, ^2, ^3, ^4, ^5, ^6, ^7, ^8, ^9, ^10, ^11, ^12, ^13, ^14, ^15' USING org.commoncrawl.pig.ArcLoader() AS (charset: chararray, length, type: chararray, statuscode, ipaddress, url: chararray, html);
b = FILTER a BY type == 'text//html';
c = foreach b generate url, charset, REPLACE (html, '\n', ' ') as html;
define myscript `test.sh` input (stdin using PigStreaming('\t')) output (stdout) ship('//home//participant//git//naward12//test.sh','//home//participant//git//naward12//check3','//home//participant//git//naward12//dtd.tar','//home//participant//git//naward12//charset.cfg', '//home//participant//git//naward12//httpd.conf','//home//participant//git//naward12//validator.conf','//home//participant//git//naward12//types.conf','//home//participant//git//naward12//tips.cfg');
d = stream c through myscript as (url, errorcode, htmlversion, valid);
store d into 'didado';";

$arrayLength = scalar(@files);
$boole = 1;
$teller = -1;
    
while($boole)
{
  if (++$teller < $arrayLength)
  {
    $pigString =~ s/^1/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
    $pigString =~ s/^2/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^3/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^4/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^5/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^6/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^7/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^8/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^9/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^10/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^11/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
    $pigString =~ s/^12/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
     $pigString =~ s/^13/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
    $pigString =~ s/^14/$files[$teller]/;
  }
  if (++$teller <= $arrayLength)
  {
    $pigString =~ s/^15/$files[$teller]/;
  }
  if (++$teller > $arrayLength)
  {
    $boole = 0;
  }
  print $pigString; 
}
    
