--dit script splitst op dit moment de errorcodes maar nog niet zeker hoe verder

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test5/*' as (url: chararray, errorcode: chararray, htmlversion, tag);
b = foreach a generate url, REPLACE (errorcode, '[^0-9]', ' ') as errorcode;
c = foreach b generate url, TOKENIZE(errorcode) as errorcode;
d = foreach c {
aerror = a.errorcode;
adist = DISTINCT aerror;
generate url, adist; 
}

d = foreach c { 
cerror = c.errorcode; 
generate url, count(cerror); 
}

 cdist = DISTINCT cerror;


e = foreach d generate url, flatten(errorcode) as errorcode;
f = distinct e;


errsorted1 = order err1 by errorcode;

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test5/*' as (url: bytearray, errorcode: bytearray, htmlversion, tag);
b = foreach a generate url, REPLACE (errorcode, '[^0-9]', ' ') as errorcode;
c = foreach b generate url, TOKENIZE(errorcode) as errorcode;
d = foreach c {
aerror = a.errorcode;
adist = DISTINCT aerror;
generate url, adist; 
}
