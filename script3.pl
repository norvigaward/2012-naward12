
#!/usr/bin/perl -w

sub doNothingWithHtml
{
        my ($html) = @_;
  my $errorList = "";
	my $range = 10;
	my $forLoop = int(rand($range));
	$range = 399;
	for ($forLoop; $forLoop>= 1; $forLoop--) 
	{
		$errorList .= int(rand($range))+1;
		$errorList .= ";";
 	}
	
	return $errorList;
}

my $print = doNothingWithHtml($ARGV[0]);
print "$print";
