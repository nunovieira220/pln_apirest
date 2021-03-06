package Spline::FreeLing::AnalyzerWord;

use 5.018002;
use strict;
use warnings;
use JSON;
use utf8;
use Encode qw(decode_utf8);
use FL3 'pt';

my %index_info = (
  hash_token => 'fl3_word_analyzer',
  parameters => {
    api_token => {
      description => 'The token to be indentified',
      required => 1,
      type => 'text',
    },
    word => {
      description => 'The word to be analyzed',
      required => 1,
      type => 'text',
    },
    ner => {
      description => 'Named-entity recognition',
      required => 0,
      type => 'number',
      default => 0,
    },
  },
  subtitle => 'Subtitulo de fl3_word_analyzer',
  description => 'Descricao de fl3_word_analyzer',
  cost => 3,
  text_cost => {
    word => [[20,1]],
  },
);

sub get_token {
  return $index_info{hash_token};
}

sub get_info {
  return \%index_info;
}

sub cost_function{
  my ($input_params) = @_;
  my $cost_result = 0;

  for my $param (keys %{$index_info{text_cost}}){
    my $text_length = "";
    if($index_info{parameters}{$param}{type} eq 'file'){ 
      $text_length = -s "$input_params->{$param}";
    }
    else{ 
      $text_length = length($input_params->{$param});
    }
    for my $pair (@{$index_info{text_cost}{$param}}){
      if($text_length >= int($pair->[0])){
        $cost_result += $pair->[1];
      }
    }
  }

  my $final_cost = $cost_result + $index_info{cost};
  return $final_cost;
}

sub param_function {
  my ($input_params) = @_;
  my $flag = 1;
  for my $param (keys %{$index_info{parameters}}){
    if ($index_info{parameters}{$param}{required} == 1){
      $flag = 0 if (!exists($input_params->{$param}));
    }
    if ($index_info{parameters}{$param}{default}){
      $input_params->{$param} = $index_info{parameters}{$param}{default} if (!exists($input_params->{$param}));
    }
  }
  return $flag;
}

sub main_function {
  my ($input_params) = @_;
  my $result = _fl3_analyzer_word($input_params);
  my $json = encode_json $result;
  return decode_utf8($json);
}

sub _fl3_analyzer_word {
  my ($input_params) = @_;
  my $word = $input_params->{word};
  my $ner = $index_info{parameters}{ner}{default};
  $ner = $input_params->{ner} if exists $input_params->{ner};
  return unless $word;

  my %options = ( lang=>'pt' );

  my $fl3_morph_pt = Lingua::FreeLing3::MorphAnalyzer->new('pt',
    ProbabilityAssignment  => 0, QuantitiesDetection    => 0,
    MultiwordsDetection    => 0, NumbersDetection       => 0,
    DatesDetection         => 0, NERecognition          => 0,
  );

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