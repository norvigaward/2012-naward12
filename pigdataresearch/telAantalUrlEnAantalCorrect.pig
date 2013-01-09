-- dit script telt het aantal correcte html paginas, en het totale aantal paginas
-- replace kan weg, als er in plaats van ; kommas , gebruikt worden

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test5/*' as (url: chararray, errorcode: chararray, htmlversion, tag);
b = group a all;
c = foreach b generate 'totaal:' as name, COUNT(a) as aantal;
d = filter a by errorcode == ';'; --later een komma!
e = group d all;
f = foreach e generate 'correct:' as name, COUNT(d) as aantal;
g = JOIN c by (name, aantal), f by (name, aantal);
--tot hier geen output
dump g;
