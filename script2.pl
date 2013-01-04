#!/usr/bin/perl -w

sub subScript
{
        my ($html) = @_;
        open(HANDLE,">tmpfile");
        print HANDLE "$html";
        close (HANDLE);
        my $errorCode = `perl -T check.pl tmpfile`;
        system("rm tmpfile");
        return $errorCode;
}
system("tar -xf dtd.tar");
$/ = "\t";
while(<>)
{
        $url = $_;
        chomp($url);
        $/ = "\n";
        $_ = <>;
        s/\s+/ /g; #substitute one or more spaces for a space and do this for all match$
        s/\s$//; #substitue a new line for nothing
        $html = "$_\n";
        $errorCodeMetVersie = subScript($html); #dit is een variabele met errocodes met ; ertussen de HTML versie
    if($html =~ /"<\s*a\s+href\s*=\s*"\s*http:\/\/validator.w3.org\/check\?uri=referer\s*"\s*>\s*<\s*a\s+href\s*=\s*"\s*http:\/\/validator\.w3\.org\/check\?uri\=referer\s*"\s*>\s*<\s*img\s+src\s*=\s*"\s*http:\/\/www.w3.org\/Icons\/[^\/]+"\s*alt\s*=\s*"[^\"]+"\s*height\s*=\s*"\s*[0-9]+\s*"\s*width\s*=\s*"\s*\d+\s*"\s*\/>\s*<\s*\/a\s*>"/i)
    {
        $html_picture = 1;
    } else {
        $html_picture = 0;
    }
        print "$url\t$errorCodeMetVersie\t$html_picture\n"; #print $_ dan tab dan $error code
        $/ = "\t";
}
