register '/home/participant/git/commoncrawl-examples/lib/*.jar';
register '/home/participant/git/commoncrawl-examples/dist/lib/commoncrawl-examples-1.0.1.jar';
a = LOAD 'hdfs://p-head03.alley.sara.nl/user/naward12/testset.arc.gz' USING org.commoncrawl.pig.ArcLoader() as (date, length, type: chararray, statuscode, ipaddress, url, html);
b = filter a by type == 'text/html';
c = foreach b generate url, REPLACE (html, '\n', ' ') as html;
define myscript `script2.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/testscripts/script2.pl', '/home/participant/git/naward12/testscripts/script3.pl');
d = stream c through myscript as (url, errorcode, htmlversion, tag);
e = limit d 10;
dump e; 
