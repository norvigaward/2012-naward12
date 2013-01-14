-- count how much of every html type there are

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test24/*' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
b = group a by htmlversion;
c = foreach b generate group, COUNT(a);
-- tot hier nog geen output
dump c;
