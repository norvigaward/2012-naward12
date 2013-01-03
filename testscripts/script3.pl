#!/usr/bin/perl -w

sub doNothingWithHtml
{
	my ($html) = @_;
	my $errorList;
	my $range = 10;
	my $getal;
	my $forLoop = int(rand($range));
	if ($forLoop > 0)
	{
		$errorList = "";
	}
	else
	{
		$errorList = ";";
	}
	$range = 489;
	for ($i = $forLoop; $i >= 1; $i--)
	{
		$getal = int(rand($range))+1;
		$errorList.= $getal;
		$errorList.= ";";
	}
	$errorList.= "-";
	my @htmlArray = ("HTML1", "HTML2", "HTML3", "XHTML1");
	$range = 4;
	$errorList.= $htmlArray[int(rand($range))];
	return $errorList;
}

my $print = doNothingWithHtml($ARGV[0]);
print "$print";
