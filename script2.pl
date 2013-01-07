#!/usr/bin/perl -w

sub subScript
{
        my ($html) = @_;
        open(HANDLE,">tmpfile");
        print HANDLE "$html";
        close (HANDLE);
        my $errorCode = `perl -T -w check2 tmpfile`;
        system("rm tmpfile");
        return $errorCode;
}
system("tar -xf dtd.tar");
$/ = "\t";
while(<>)
{
	my $url = $_;
	chomp($url);
	$/ = "\n";
	$_ = <>;
	s/\s+/ /g; #substitute one or more spaces for a space and do this for all match$
	s/\s$//; #substitue a new line for nothing
	my $html = "$_\n";
	
	my $html_picture = 0;
	if($html =~ /".*href\=\"http\:\/\/validator.w3.org\/check\?uri\=referer\".*"/i)
	{
		$html_picture = 1;
	}
        $errorCodeMetVersie = subScript($html); #dit is een variabele met errocodes met ; ertussen de HTML versie
    
        print "$url\t$errorCodeMetVersie\t$html_picture\n"; #print $_ dan tab dan $error code
        $/ = "\t";
}
