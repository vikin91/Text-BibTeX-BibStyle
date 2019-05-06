#!/usr/local/bin/perl

use strict;
use lib qw(../blib/lib);

use Text::BibTeX::BibStyle qw($RST);
use Text::BibTeX;
use Text::BibTeX::Entry;
use Data::Dumper;
use Test::More;
use FindBin;
chdir $FindBin::RealBin;

# my $bib_var <EOF;
# @ARTICLE{whole-journal,
#    key = "GAJ",
#    journal = {\mbox{G-Animal's} Journal},
#    year = 1986,
#    volume = 41,
#    number = 7,
#    month = jul,
#    note = {The entire issue is devoted to gnats and gnus (this entry is a cross-referenced ARTICLE (journal))},
# EOF

# my $bst = "bibstyle/alpha.bst";


### processing a single entry is a bad idea beacuse no macros are expanded cf. month=jul vs. month={July}
### - both should give July, but the first option gives nothing when used by the new single entry method
### crossrefs are not supported as well
### processing single entry work only if full information is provided and no macros nor crossrefs are used
### year=xxx is supported and no year={xxx} is required
### source of the problem:  Text::BibTeX::Entry gives warning: <bibs/xampl.bib, line 98, warning: undefined macro "jan"
### more info: http://search.cpan.org/~gward/Text-BibTeX-0.32/btool_faq.pod#Why_aren't_the_BibTeX_"month"_macros_defined?

### not supported as well is: month = "10~" # jan, 
### this gots expanded into: "10~January" but should not be expanded.
### I removed such entries from the test file

### not supported: month = jun # "-" # aug,
### use instead  : month = "June-Aug.",

sub prepare_bbl{
  my $test = shift;
  my $bbls = `cat latex/$test.bbl`;
  $bbls =~ s/\n  / /g;    # Undo wrapping


  my @expected_bbl = split( /\\bibitem/, $bbls );
  shift @expected_bbl
      if $expected_bbl[0]
      =~ /^\\newcommand.*/;   # this method is unable to process \newcommand

  foreach (@expected_bbl)
  {    # we cut the \bibtitem, so we need to give it back
      s/^/\\bibitem/;
  }
  return @expected_bbl;
}

##########################################

sub prepare_bibs{
  my @bibs;
  my $bibfile = Text::BibTeX::File->new("<bibs/xampl-no-crossrefs.bib") 
  or die "foo.bib: $!\n";

  # this line provides standard bibtex 0.99 macros, e.g., months
  $bibfile->set_structure ('Bib');

  while ( my $entry = new Text::BibTeX::Entry $bibfile) {
    next unless $entry->parse_ok;
    next unless $entry->metatype == BTE_REGULAR;
    my $entry_text = $entry->print_s;
    push @bibs, $entry_text unless $entry_text =~ /crossref/;
    push @bibs, "skip" if $entry_text =~ /crossref/;

  }
  return @bibs;
}

##########################################




my @bbls = <latex/*.bbl>;
s!latex/(.*)\.bbl!$1! foreach @bbls;

my @tests = grep -f "rst/$_.rst", @bbls;

@tests = @ARGV if @ARGV;

plan tests => 31; # * ( 0 + scalar @tests ) unless $ENV{OUTPUT};


my %options;
$options{debug} = 1 if $ENV{DEBUG};


foreach my $test (@tests) {

    next unless $test =~ /abbrv/; 
      # sorry, but there are too many little stuuf that this does not support
    print ">>>>>>>>> Test: " . $test . "\n";



    my @bibs = prepare_bibs();

    # my $bibfile = Text::BibTeX::File->new( "<bibs/xampl.bib" );

    my $bst_file_path = "bibstyle/" . $test . ".bst";

    # print "bst_file_path $bst_file_path \n";
    ok( -e $bst_file_path, "bst file exists for test $test" );


    my @expected_bbl = prepare_bbl($test);

    my $bibstyle = Text::BibTeX::BibStyle->new(%options);
    $bibstyle->read_bibstyle($bst_file_path);

    foreach (@bibs) {
        my $bib_str = $_;
        # this cannot be compared as this is no entry
        if ($bib_str eq "skip" ){#or  $bib_str =~ /string/){
          shift @expected_bbl;
          next;
        }
        if ($bib_str =~ /preamble/ or $bib_str =~ /\\end\{thebibliography\}/){
          next;
        }
        

        # read the bst file
        $bibstyle->read_bibstyle($bst_file_path); 
              # this needs to be really here in the loop!! I must have messed something up
              # process a single entry passed by string variable

        # print "bib_str:\n\n$bib_str\n\n";
        my $bbl = $bibstyle->execute( [], $bib_str );

        $bibstyle->convert_format($Text::BibTex::BibStyle::LATEX);
        my $output = $bibstyle->get_output();

        $output
            =~ s/\\begin\{thebibliography\}\{.+\}//;    ## remove the opening
        $output =~ s/\\end\{thebibliography\}//;    ## ... and closing block

        my $exp_bbl = shift @expected_bbl;


        $output =~ s/\n+\W*\n+//g;                  # remove too many newlines
        $exp_bbl =~ s/\n+\W*\n+//g;                 # remove too many newlines

        # print "\t\t\tCompare ".substr($output, 0, index($output, "\n"))." against ".substr($exp_bbl, 0, index($exp_bbl, "\n"))."\n";


        cmp_ok( $output, 'eq', $exp_bbl,
            $test . " compare conversion output" );
        print "======== INPUT: \n"
            . $bib_str
            . "\n"
            . "======== GOT\n"
            . $output
            . "\n"
            . "======== EXPECTED\n"
            . $exp_bbl
            . "\n\n"
            unless $output eq $exp_bbl;

        # is( $output, $exp_bbl, $test." compare conversion output" );

    }

}



done_testing();
