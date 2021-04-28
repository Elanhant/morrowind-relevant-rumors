#!/usr/bin/env perl

# I was unable to use JSON:PP that is included in Perl5,
# so instead opted for including it with my own code.
use lib '.';
use JSON;

my $configFileName = 'config.json';

my $json_text = do {
   open(my $json_fh, "<", $configFileName)
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};

sub main {
  my ($R) = @_;
  my $config = from_json($json_text);
  my $responses = $config->{responses};

  my $questId = $R->{SH}->{SCVR}[0]->{name};
  $questId =~ s/RE_(.+)_Response/$1/;

  my $responseIndex = $R->{SH}->{INTV}[0]->{compare_value} - 1;

  my $responseText = $responses->{$questId}[$responseIndex]->{text} or die("Can't find response for quest ID '$questId' and index $responseIndex.");

  if (length($responseText) > 500) {
     die("Response for quest ID '$questId' and index $responseIndex is too long, should be no more than 500 characters.");
  }

  print "Response for $questId (response index $responseIndex):\n";
  print "----------\n$responseText\n----------\n\n";

  $R->set({f=>"response"}, $responseText);
}
