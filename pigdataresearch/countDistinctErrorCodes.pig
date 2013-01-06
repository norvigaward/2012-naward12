-- dit script telt hoe vaak elke error code voorkomt
-- als een errorcode meerdere malen bij 1 url voorkomt wordt deze 1x geteld
-- is nog best traag

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test5/*' as (url: chararray, errorcode: chararray, htmlversion, tag);
b = foreach a generate url, REPLACE (errorcode, '[^0-9]', ' ') as errorcode;
c = foreach b generate url, TOKENIZE(errorcode) as errorcode;
noempty = foreach c generate url, ((errorcode is null or IsEmpty(errorcode)) ? {('none')} : errorcode) as errorcode;
d = foreach noempty generate url, flatten(errorcode) as errorcode;
e = distinct d;
f = group e by errorcode;
g = foreach f generate group, COUNT(e);
-- tot hier geen output
dump g;
