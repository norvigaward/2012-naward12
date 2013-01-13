#!/usr/bin/perl -w
    
@files = `hadoop fs -ls hdfs://p-head03.alley.sara.nl/data/public/common-crawl/parse-output/segment/1346823845675`;
foreach $file (@files)
{
  $file = "hdfs://p-head03.alley.sara.nl".(substr $file, 55);
}    

$arrayLength = scalar(@files);
$boole = 1;
$teller = -1;
    
while($boole)
{    
    my $loadList = "";
       
  if (++$teller < $arrayLength)
  {
    $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
    $loadList.=", ";
    $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
    $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
    $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
    $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
     $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
    $loadList.=$files[$teller];
  }
  if (++$teller <= $arrayLength)
  {
      $loadList.=", ";
    $loadList.=$files[$teller];
  }
  if (++$teller > $arrayLength)
  {
    $boole = 0;
  }
  
   
    my $pigString = "register '//home//participant//git//commoncrawl-examples//lib//*.jar'; 
    register '//home//participant//git//commoncrawl-examples//dist//lib//commoncrawl-examples-1.0.1-HM.jar'; a = LOAD '$loadList' USING org.commoncrawl.pig.ArcLoader() AS (charset: chararray, length, type: chararray, statuscode, ipaddress, url: chararray, html);
    b = FILTER a BY type == 'text//html';
    c = foreach b generate url, charset, REPLACE (html, '\n', ' ') as html;
    define myscript `test.sh` input (stdin using PigStreaming('\t')) output (stdout) ship('//home//participant//git//naward12//test.sh','//home//participant//git//naward12//check3','//home//participant//git//naward12//dtd.tar','//home//participant//git//naward12//charset.cfg', '//home//participant//git//naward12//httpd.conf','//home//participant//git//naward12//validator.conf','//home//participant//git//naward12//types.conf','//home//participant//git//naward12//tips.cfg');
    d = stream c through myscript as (url, errorcode, htmlversion, valid);
    store d into 'didado';";
  
  print $pigString; 
}
    
