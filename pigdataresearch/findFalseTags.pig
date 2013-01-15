-- filter all tuples that have a tag for good html but nevertheless have errorcodes.

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/for_real25/, hdfs://p-head03.alley.sara.nl/user/naward12/for_real26/, hdfs://p-head03.alley.sara.nl/user/naward12/for_real28/' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
noerr = filter a by NOT errorcode == 'error';
b = foreach noerr generate url, TOKENIZE(errorcode) as errorcode, tag;
c = filter b by(NOT IsEmpty(errorcode) AND tag == 1);
d = foreach c generate url;
-- tot hier geen output
store d into 'findFalseTags';
