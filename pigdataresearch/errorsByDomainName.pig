-- niet af

a = load 'bLABLABLALLBALALB' as url;  
define myscript `bepaaldomein.pl` input (stdin using PigStreaming()) output (stdout) ship('/home/participant/git/naward12/pigdataresearch/bepaaldomein.pl');
b = stream a through myscript as (domain);  
