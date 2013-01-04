register '/home/participant/git/commoncrawl-examples/lib/*.jar';
register '/home/participant/git/commoncrawl-examples/dist/lib/commoncrawl-examples-1.0.1.jar';
a = LOAD 'hdfs://p-head03.alley.sara.nl/user/naward12/testset.arc.gz' USING org.commoncrawl.pig.ArcLoader() as (date, length, type: chararray, statuscode, ipaddress, url, html);
b = filter a by type == 'text/html';
c = foreach b generate url, REPLACE (html, '\n', ' ') as html;
define myscript `script2.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/script2.pl', '/home/participant/git/naward12/check.pl','/home/participant/git/naward12/dtd.tar','/home/participant/git/naward12/charset.cfg', '/home/participant/git/naward12/httpd.conf','/home/participant/git/naward12/validator.conf','/home/participant/git/naward12/types.conf','/home/participant/git/naward12/tips.cfg');
d = stream c through myscript as (url, errorcode, htmlversion, tag);
e = limit d 20;
dump e;
