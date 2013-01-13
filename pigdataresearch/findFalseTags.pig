-- dit script filtert alle tuples eruit die een tag hebben maar toch html fouten
-- mochten we nog gaan kijken naar de tags, kunnen we met dit script verder

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/test5/*' as (url: chararray, errorcode: chararray, htmlversion, tag);
b = foreach a generate url, TOKENIZE(errorcode) as errorcode, tag;
c = filter d by(NOT IsEmpty(errorcode) AND tag == 1);
-- tot hier geen output
dump c;
