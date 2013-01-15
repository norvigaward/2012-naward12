a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/for_real25/,hdfs://p-head03.alley.sara.nl/user/naward12/for_real28/' as (url: chararray, errorcode: chararray, htmlversion, valid, tag);
b = FILTER a BY (NOT (url matches '.*?timeout.*?'));
c = FILTER b BY (NOT (errorcode matches '.*?timeout.*?'));
d = FILTER c BY (NOT (htmlversion matches '.*?timeout.*?'));
e = FILTER d BY (NOT (valid matches '.*?timeout.*?'));
f = FILTER e BY (NOT (tag matches '.*?timeout.*?'));
store f into 'final3';
