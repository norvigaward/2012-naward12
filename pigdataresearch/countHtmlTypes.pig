-- dit script telt hoeveel er van elk type html zijn
a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test24' as (url, errorcode, htmlversion, valid);
b = group a by htmlversion;
c = foreach b generate group, COUNT(a);
-- tot hier nog geen output
dump c;
