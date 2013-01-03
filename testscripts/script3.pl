#!/usr/bin/perl -w

sub doNothingWithHtml
{
	my ($html) = @_;
	my $errorList = "";
	my $range = 10;
	my $forLoop = int(rand($range));
	print "$forLoop";
	$range = 489;
	for ($i = $forLoop; $i >= 1; $i--)
	{
		$errorList.= (int(rand($range))+1);
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
