# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..13\n"; }
END {print "not ok 1\n" unless $loaded;}
use XML::Template;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# Create a test object and give it a file
%namespace = (
	      ok => "ok",
	      ok_now => "not ok",
	      still_ok => "ok",
	      not_ok => "not ok",
	      foobar => "ok.xmlt",
	      RESULTS => {
		  1 => { NUMBER=>"7", RESULT => "ok" },
		  2 => { NUMBER=>"8", RESULT => "ok" },
		  3 => { NUMBER=>"9", RESULT => "ok" },
	      },
	      with_test => {
		  result => "ok"
		  },
 );

my $interp = XML::Template->new("examples");
print $interp->compose(\%namespace, "example.xmlt");
