-- count the average number of distinct errors per domain name

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test/*' as (url: chararray, errorcode: chararray, htmlversion, valid);
b = filter a by NOT errorcode == 'error';
c = foreach b generate url, errorcode;
define myscript `bepaaldomein.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/pigdataresearch/bepaaldomein.pl');
d = stream c through myscript as (domain, errorcode);

-- no output until this line




a = load '/home/participant/for_real14/part-m-00041' as (url: chararray, errorcode: chararray, htmlversion, valid);
b = filter a by NOT errorcode == 'error';
c = foreach b generate url, errorcode;
define myscript `bepaaldomein.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/pigdataresearch/bepaaldomein.pl');
d = stream c through myscript as (domain, errorcode);
