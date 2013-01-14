-- count the average number of distinct errors per domain name

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test/*' as (url: chararray, errorcode: chararray, htmlversion, valid);
define myscript `bepaaldomein.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/pigdataresearch/bepaaldomein.pl');
b = foreach a generate url, errorcode;
c = stream b through myscript as (domain, errorcode);

-- no output until this line
dump c;

a = load '/home/participant/for_real14/*' as (url: chararray, errorcode: chararray, htmlversion, valid);

define myscript `test.sh` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/test.sh','/home/participant/git/naward12/check3','/home/participant/git/naward12/dtd.tar','/home/participant/git/naward12/charset.cfg', '/home/participant/git/naward12/httpd.conf','/home/participant/git/naward12/validator.conf','/home/participant/git/naward12/types.conf','/home/participant/git/naward12/tips.cfg');
