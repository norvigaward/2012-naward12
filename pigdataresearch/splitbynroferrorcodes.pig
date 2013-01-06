--dit script splitst op dit moment de errorcodes maar nog niet zeker hoe verder

a = load 'hdfs://p-head03.alley.sara.nl/user/naward12/twinkle/part-m-00000' as (url: chararray, errorcode: chararray, htmlversion, tag);
b = foreach a generate url, REPLACE (errorcode, '[^0-9]', ' ') as errorcode;
c = foreach b generate url, TOKENIZE(errorcode) as errorcode;

SPLIT c INTO err0 IF SIZE(errorcode) == 0, err1 IF SIZE(errorcode) == 1, err2 IF SIZE(errorcode) == 2, err3 IF SIZE(errorcode) == 3, err4 IF SIZE(errorcode) == 4, err5 IF SIZE(errorcode) == 5, err6 IF SIZE(errorcode) == 6, err7 IF SIZE(errorcode) == 7, err8 IF SIZE(errorcode) == 8, err9 IF SIZE(errorcode) == 9, err10 IF SIZE(errorcode) == 10;

errsorted1 = order err1 by errorcode;
