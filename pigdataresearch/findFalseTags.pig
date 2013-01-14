-- filter all tuples that have a tag for good html but nevertheless have errorcodes.

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test24/*' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
b = foreach a generate url, TOKENIZE(errorcode) as errorcode, tag;
c = filter d by(NOT IsEmpty(errorcode) AND tag == 1);
-- tot hier geen output
dump c;
