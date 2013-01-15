--  count how much of every html type there are

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/for_real25/*, hdfs://p-head03.alley.sara.nl/user/naward12/for_real26/*, hdfs://p-head03.alley.sara.nl/user/naward12/for_real28/*' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
b = group a by htmlversion;
c = foreach b generate group, COUNT(a);
-- no output until here
store c into 'htmlversionslist';
