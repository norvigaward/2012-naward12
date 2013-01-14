-- count how many times each error code is found (multiples in the same document counted as one)

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test24/*' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
b = foreach a generate url, TOKENIZE(errorcode) as errorcode;
noempty = foreach b generate url, ((errorcode is null or IsEmpty(errorcode)) ? {('none')} : errorcode) as errorcode;
c = foreach noempty generate url, flatten(errorcode) as errorcode;
d = distinct c;
e = group d by errorcode;
ealles = group d all;
f = foreach e generate group as errorNo, COUNT(d);
g = foreach ealles generate 'totaal:' as errorNo, COUNT(d); 
h = union f, g;
-- tot hier geen output
dump h;
