--  give the average distinct error codes per html type

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/for_real25/, hdfs://p-head03.alley.sara.nl/user/naward12/for_real26/, hdfs://p-head03.alley.sara.nl/user/naward12/for_real28/' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
b = foreach a generate url, htmlversion, TOKENIZE(errorcode) as errorcode;
noempty = foreach b generate url, htmlversion, ((errorcode is null or IsEmpty(errorcode)) ? {('none')} : errorcode) as errorcode;
c = foreach noempty generate url, htmlversion, flatten(errorcode) as errorcode;
d = distinct c;
dfilter = filter d by NOT errorcode == '600';
e = group dfilter by htmlversion;
f = foreach e generate group as versie, COUNT(dfilter) as aantalFoutenPerVersie;
g = group a by htmlversion;
h = foreach g generate group as versie2, COUNT(a) as aantalKeerAanwezig;
i = join f by versie, h by versie2;
j = foreach i generate versie, ((float)aantalFoutenPerVersie / (float)aantalKeerAanwezig) as gemiddeldAantalFouten;
-- no output until here
store j into 'errorsbyhtmltype';
