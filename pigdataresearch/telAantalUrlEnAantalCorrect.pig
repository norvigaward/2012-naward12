-- dit script telt het aantal correcte html paginas, en het totale aantal paginas

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test24/*' as (url: chararray, errorcode: chararray, htmlversion, valid);
b = group a all;
c = foreach b generate 'totaal:' as name, COUNT(a) as aantal;
d = filter a by valid == 1;
e = group d all;
f = foreach e generate 'correct:' as name, COUNT(d) as aantal;
g = union c, f;
--tot hier geen output
dump g;
