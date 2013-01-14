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
	my $html = "$_\n";
        $errorCodeMetVersieenValid = subScript($html); #dit is een variabele met errocodes met ; ertussen de HTML versie
        print "$url\t$errorCodeMetVersieenValid\n"; #print $_ dan tab dan $error code
        $/ = "\t";
}
