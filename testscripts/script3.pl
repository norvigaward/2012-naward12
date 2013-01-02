#!/usr/bin/perl -w

sub doNothingWithHtml
{
	my ($html) = @_;
	my $errorList = "";
	my $range = 10;
	my $forLoop = int(rand($range));
	$range = 489;
	for ($forLoop; $forLoop>= 1; $forLoop--)
	{
		$errorList .= (int(rand($range))+1);
		$errorList .= ";";
	}
	$errorList .= "/t";
	my @htmlArray = ("HTML1", "HTML2", "HTML3", "XHTML1");
	$range = 3;
	$errorList .= $htmlArray[int(rand($range))];
	return $errorList;
}

my $print = doNothingWithHtml($ARGV[0]);
print "$print";
