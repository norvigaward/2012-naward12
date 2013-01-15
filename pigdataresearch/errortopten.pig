a =load 'hdfs://p-head03.alley.sara.nl/user/naward12/countdistincterrors/' as (error, number : int );
b = order a by number;
c = limit b 10;
store c into 'topten';
