-- count the average number of distinct errors per domain name

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/for_real25/*, hdfs://p-head03.alley.sara.nl/user/naward12/for_real26/*, hdfs://p-head03.alley.sara.nl/user/naward12/for_real28/*' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
b = filter a by NOT errorcode == 'error';
c = foreach b generate url, errorcode;
define myscript `bepaaldomein.pl` input (stdin using PigStreaming('\t')) output (stdout) ship('bepaaldomein.pl');
d = stream c through myscript as (url, domain, errorcode);
e = foreach d generate url, domain, TOKENIZE(errorcode) as errorcode;
f = foreach e generate url, domain, flatten(errorcode) as errorcode;
g = distinct f;
gfilter = filter g by NOT errorcode == '600';
h = group gfilter by domain;
i = foreach h generate group as tldomain, COUNT(gfilter) as aantalFoutenPerDomein;
j = group d by domain;
k = foreach j generate group as tldomain2, COUNT(d) as aantalKeerAanwezig;
l = join i by tldomain, k by tldomain2;
m = foreach l generate tldomain, ((float)aantalFoutenPerDomein / (float)aantalKeerAanwezig) as gemAantalFouten;
-- no output till here
store m into 'errorsbydomain';
