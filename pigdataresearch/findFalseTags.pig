-- dit script filtert alle tuples eruit die een tag hebben maar toch html fouten
-- we kunnen later een count toevoegen om het aantal te tellen
-- replace kan weg, als er in plaats van ; kommas , gebruikt worden

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test5/*' as (url: chararray, errorcode: chararray, htmlversion, tag);
b = foreach a generate url, REPLACE (errorcode, '[^0-9]', ' ') as errorcode, tag;
c = foreach b generate url, TOKENIZE(errorcode) as errorcode, tag;
d = filter c by(NOT IsEmpty(errorcode) AND tag == 1);
-- tot hier geen output
dump d;
