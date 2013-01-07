register '/home/participant/git/commoncrawl-examples/lib/*.jar';
register '/home/participant/git/commoncrawl-examples/dist/lib/commoncrawl-examples-1.0.1-HM.jar';
a = LOAD 'hdfs://p-head03.alley.sara.nl/user/naward12/testset.arc.gz' USING org.commoncrawl.pig.ArcLoader() as (charset, length, type: chararray, statuscode, ipaddress, url, html);
b = filter a by type == 'text/html';
c = foreach b generate charset;
dump c;
