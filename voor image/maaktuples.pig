register 'git/commoncrawl-examples/lib/*.jar';
register 'git/commoncrawl-examples/dist/lib/commoncrawl-examples-1.0.1.jar';
a = LOAD 'hdfs://p-head03.alley.sara.nl/data/public/common-crawl/award/testset/1346864466526_10.arc.gz' USING org.commoncrawl.pig.ArcLoader() as (date, length, type: chararray, statuscode, ipaddress, url, html);
b = filter a by type == 'text/html';
c = foreach b generate url, REPLACE (html, '\n', ' ') as html;
define myscript `script2.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('script2.pl', 'check.pl','dtd.tar','charset.cfg', 'httpd.conf','validator.conf','types.conf','tips.cfg');
d = stream c through myscript as (url, errorcode, tag);
e = limit d 10;
dump e; 
