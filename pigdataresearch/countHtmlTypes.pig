a = load 'twinkle/part-m-00000' as (url, errorcode, htmlversion, tag);
b = group a by htmlversion;
c = foreach b generate group, COUNT(a);

