#!/usr/bin/perl -w

sub doNothingWithHtml
{
	my ($html) = @_;
	
	my $errorList = "";
	my $range = 399;
	$errorList .= (int(rand($range))+1);
	$errorList .= ";";
	
	return $errorList;
}

my $print = doNothingWithHtml($ARGV[0]);
print "$print";
