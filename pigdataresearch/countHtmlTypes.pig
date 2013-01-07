-- dit script telt hoeveel er van elk type html zijn
a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/twinkle/part-m-00000' as (url, errorcode, htmlversion, tag);
b = group a by htmlversion;
c = foreach b generate group, COUNT(a);
-- tot hier nog geen output
dump c;
