register '/home/participant/git/commoncrawl-examples/lib/*.jar';
register '/home/participant/git/commoncrawl-examples/dist/lib/commoncrawl-examples-1.0.1-HM.jar';
a = LOAD 'hdfs://p-head03.alley.sara.nl//data/public/common-crawl/parse-output/segment/1346876860493/*.arc.gz' USING org.commoncrawl.pig.ArcLoader() AS (charset: chararray, length, type: chararray, statuscode, ipaddress, url: chararray, html);
b = FILTER a BY type == 'text/html';
c = foreach b generate url, charset, REPLACE (html, '\n', ' ') as html;
define myscript `check3` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/test.sh','/home/participant/git/naward12/check3','/home/participant/git/naward12/dtd.tar','/home/participant/git/naward12/charset.cfg', '/home/participant/git/naward12/httpd.conf','/home/participant/git/naward12/validator.conf','/home/participant/git/naward12/types.conf','/home/participant/git/naward12/tips.cfg');
d = stream c through myscript as (url, errorcode, htmlversion, valid, picture);
store d into 'for_real16';
