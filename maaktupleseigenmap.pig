register '/home/participant/git/commoncrawl-examples/lib/*.jar';
register '/home/participant/git/commoncrawl-examples/dist/lib/commoncrawl-examples-1.0.1-HM.jar';
a = LOAD 'hdfs://p-head03.alley.sara.nl/user/naward12/testset.arc.gz' USING org.commoncrawl.pig.ArcLoader() as (charset, length, type: chararray, statuscode, ipaddress, url, html);
b = filter a by type == 'text/html';
c = foreach b generate url, charset, REPLACE (html, '\n', ' ') as html;
define myscript `check3` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/check3','/home/participant/git/naward12/dtd.tar','/home/participant/git/naward12/charset.cfg', '/home/participant/git/naward12/httpd.conf','/home/participant/git/naward12/validator.conf','/home/participant/git/naward12/types.conf','/home/participant/git/naward12/tips.cfg');
d = stream c through myscript as (url, errorcode, htmlversion, valid);
store d into 'test15';
