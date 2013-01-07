-- testfile voor verschillende dingetjes


a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test5/*' as (url: chararray, errorcode: chararray, htmlversion, tag);
b = foreach a generate url, REPLACE (errorcode, '[^0-9]', ' ') as errorcode;
c = foreach b generate url, TOKENIZE(errorcode) as errorcode;
d = foreach c generate url, flatten(errorcode) as errorcode;
e = distinct d;
f = group e by errorcode;
g = foreach f generate group, COUNT(e);
