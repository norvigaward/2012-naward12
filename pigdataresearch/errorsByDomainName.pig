-- count the average number of distinct errors per domain name

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test/*' as (url: chararray, errorcode: chararray, htmlversion, valid);
b = filter a by NOT errorcode == 'error';
c = foreach b generate url, errorcode;
define myscript `bepaaldomein.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/pigdataresearch/bepaaldomein.pl');
d = stream c through myscript as (url, domain, errorcode);
e = foreach d generate url, domain, TOKENIZE(errorcode) as errorcode;
f = foreach e generate url, domain, flatten(errorcode) as errorcode;
g = distinct f;
h = group g by domain;
i = foreach h generate group as versie, COUNT(g) as aantalFoutenPerDomein;
-- no output before this line
dump i;




a = load '/home/participant/for_real14/part-m-00041' as (url: chararray, errorcode: chararray, htmlversion, valid);
b = filter a by NOT errorcode == 'error';
c = foreach b generate url, errorcode;
define myscript `bepaaldomein.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('/home/participant/git/naward12/pigdataresearch/bepaaldomein.pl');
d = stream c through myscript as (domain, errorcode);
