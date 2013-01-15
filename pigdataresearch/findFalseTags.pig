-- filter all tuples that have a tag for good html but nevertheless have errorcodes.

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/for_real25/, hdfs://p-head03.alley.sara.nl/user/naward12/for_real26/, hdfs://p-head03.alley.sara.nl/user/naward12/for_real28/' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
noerr = filter a by NOT errorcode == 'error';
b = foreach noerr generate url, valid, tag;
c = filter b by (valid == 0 AND tag == 1);
d = foreach c generate url, valid;
-- no output until here
store d into 'findFalseTags';
-- and count the number of sites with false tags too
e = group d by valid;
f = foreach e generate COUNT(d) as aantalKeerAanwezig;
store f into 'findFalseTagsAantal';
