package API_PLN::Service::AnalyzerFL3;

use 5.018002;
use strict;
use warnings;
use JSON;
use URI::Escape;
use FL3 'pt';
use Lingua::FreeLing3::Sentence;
use Lingua::FreeLing3::Utils qw/word_analysis/;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

my $fl3_morph_pt = Lingua::FreeLing3::MorphAnalyzer->new('pt',
    ProbabilityAssignment  => 0, QuantitiesDetection    => 0,
    MultiwordsDetection    => 0, NumbersDetection       => 0,
    DatesDetection         => 0, NERecognition          => 0,
  );

my $hash_token = 'fl3_analyzer';
my %parameters = ( 
    text => {
      description => 'The text to be analyzed',
      required => 1,
    },
    word => {
      description => 'The word to be analyzed',
      required => 1,
    },
    ner => {
      description => 'Named-entity recognition',
      required => 0,
    },
 );

sub get_token {
  return $hash_token;
}

sub param_function {
	#return sub {
	    my ($input_params) = @_;
	    my $flag = 0;
	    for my $param (keys %parameters){
	      if ($parameters{$param}{required} == 1){
	        $flag++ if (exists($input_params->{$param}));
	      }
	    }
	    return $flag;
	#}
}

sub main_function {
	#return sub {
		my ($input_params) = @_;
		if(exists $input_params->{word}){
			my %options = ( lang=>'pt' );
		  	my $result = _fl3_analyzer_word($input_params->{word}, %options);
			return encode_json $result;
		}
		else{
			my $text = $input_params->{text};
			my $ner = 0;
			$ner = $input_params->{ner} if exists $input_params->{ner};
			my %options = ( lang => 'pt', ner => $ner );
			my $result = _fl3_analyzer($text, %options);
			return encode_json $result;
		}
	#}
}


sub _fl3_analyzer {
  my ($text, %options) = @_;
  return unless $text;

  my $morph = Lingua::FreeLing3::MorphAnalyzer->new($options{lang},
      NERecognition => $options{ner},
    );

  my $tokens = tokenizer->tokenize($text);
  my $sentences = splitter->split($tokens);
  $sentences = $morph->analyze($sentences);
  $sentences = hmm->analyze($sentences);

  my $result;
  foreach (@$sentences) {
    my @words = $_->words;
    foreach my $w (@words) {
      push @$result, {word=>$w->form, pos=>$w->tag, lemma=>$w->lemma};
    }
  }

  return $result;
}

sub _fl3_analyzer_word {
  my ($word, %options) = @_;
  return unless $word;

  my $words = tokenizer($options{lang})->tokenize($word);
  
  my $analysis = $fl3_morph_pt->analyze([Lingua::FreeLing3::Sentence->new(@$words)]);
  my @w = $analysis->[0]->words;
  my $result =  $w[0]->analysis(FeatureStructure=>1);

  my @final;
  foreach (@$result) {
    my $pos = $_->{tag};
    my $lemma = $_->{lemma};
    my $cat = '_';
    $cat = lc($1) if $pos =~ m/^(\w)/;
    push @final, {lemma=>$lemma, pos=>$pos, cat=>$cat, word=>$word};
  }

  return [@final];
}


1;
__END__
