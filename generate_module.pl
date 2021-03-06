#!/usr/bin/env perl

use XML::DT;
use XML::LibXML;
use Data::Dumper;
use strict;
use warnings;
use experimental 'smartmatch';
use Switch;
use Scalar::Util qw(looks_like_number);
use String::Util qw(trim);
use Capture::Tiny ':all';

my $filename = shift;
my $flag = shift;

## SCHEMA VALIDATION;

my $schema = XML::LibXML::Schema->new(location => 'xml_schema.xsd');
my $parser = XML::LibXML->new;
my $doc = $parser->parse_file($filename);
eval { $schema->validate($doc) };
die $@ if $@;


## MODULE GENERATION;

my $tool;
my $service;
my $fh;
my %hash_info = ();
my %tests = ();
my %documentation = ();
my $aux_test = 0;
my $aux_doc = 0;
my $test_number = 1;
my $last_param = 0;
my $method = 0;
my $packages = "";
my $all_code = "";
my $lang = "perl";
my @files = ();
my @dirs = ();

$hash_info{hash_token} = "";
$hash_info{subtitle} = "";
$hash_info{description} = "";
$hash_info{input} = "";
$hash_info{output} = "";
$hash_info{cost} = 0;
$hash_info{parameters} = ();
$hash_info{text_cost} = ();


# Variable Reference
# $c - contents after child processing
# $q - element name (tag)
# %v - hash of attributes

my %handler=(
	 '-default'   => sub{""},
	 '-begin' => sub{
			 		if($flag){
			 			switch($flag){
			 				case "-h" { print "HELP!\n"; exit(0);}
			 				case "-d" { print "REMOVING IF EXIST!\n";}
			 			}
			 		}
			 		my %param = ();
    			push @{$hash_info{parameters}}, \%param;
			 	},
	 	'-end'	=> sub{ 
	 									print $fh create_documentation();
	 									close($fh);
 										system("cd modules/intermediate/Spline-$tool; cpanm -S -v .");
 										system("cd modules/Spline-$tool-$service; cpanm -S -v .");
	 								},
    'cost' => sub{ $hash_info{cost} = int($c); },
    'definition' => sub{ $hash_info{description} = $c; },
    'route' => sub{ $hash_info{hash_token} = $c; },
    'implementation' => sub{""},
    'main' => sub{
    								$all_code = $c;
    								print $fh create_hash_info(%hash_info); 
										print $fh create_default_functions();
										$lang = $v{lang} if $v{lang};
										if($method==0){
											print $fh create_main_function_perl($all_code, $method) if($lang eq 'perl');
											print $fh create_main_function_bash($all_code, $method) if($lang eq 'bash');
    								}
    				},
    'meta' => sub{
    				if($v{batch}){
    					$v{batch} = 0 if $v{batch} eq 'false';
    					$v{batch} = 1 if $v{batch} eq 'true';
    					$method = $v{batch};
    				}
    	},
    'name' => sub{ 
		     				$service = ucfirst($c);
		     				my @modules = `ls modules`;
		     				if (!("Spline-$tool-$service\n" ~~ @modules)){
	     						system("cd modules; h2xs -XAn Spline::$tool::$service; chmod -R 777 Spline-$tool-$service");
	     						system("cp modules/intermediate/Spline-Services/.gitignore modules/Spline-$tool-$service/");
		     					open($fh, '>', "modules/Spline-$tool-$service/lib/Spline/$tool/$service.pm"); 
		     					print $fh "package Spline::$tool::$service;\n\n";
		     					print $fh "use 5.018002;\nuse strict;\nuse warnings;\nuse JSON;\nuse utf8;\nuse Encode qw(decode_utf8);\n\n";
		     				}
		     				else{
		     					system("rm -rf modules/Spline-$tool-$service") if($flag and $flag eq "-d");
		     					print STDERR "This module already exists!\n";
		     					exit(0);
		     				}
		     			}, 
    'package' => sub{ 
    				if($method == 0){ print $fh "use $c;\n"; }
    				else{ $packages .= "load '$c'; "; }
    			},
    'packages' => sub{""},
    'default' => sub{ $hash_info{parameters}->[(scalar @{$hash_info{parameters}})-1]{default} = $c; },
    'description' => sub{ $hash_info{parameters}->[(scalar @{$hash_info{parameters}})-1]{description} = $c; },
    'parameter' => sub{ 
							$hash_info{parameters}->[(scalar @{$hash_info{parameters}})-1]{name} = $v{name};
							$v{required} = 1 if $v{required} eq 'true';
							$v{required} = 0 if $v{required} eq 'false';
							$hash_info{parameters}->[(scalar @{$hash_info{parameters}})-1]{required} = $v{required};
							$hash_info{parameters}->[(scalar @{$hash_info{parameters}})-1]{type} = $v{type};
							my %param = ();
							push @{$hash_info{parameters}}, \%param;
						}, # attributes: required
    'parameters' => sub{""},
    'service' => sub{""},
    'subtitle' => sub{ $hash_info{subtitle} = $c; },
    'test' => sub {
		    			create_tests($tool, $service, $aux_test, $test_number, $hash_info{hash_token},  %tests);
		    			%tests = ();
		    			$aux_test = 0;
		    			$test_number++;
		    		},
    'code' => sub {
							push @{$tests{test_code}}, trim($c);
							$aux_test++;
						},
    'param' => sub { $tests{test_param}{$v{name}} = trim($c); },
    'tests' => sub {""},
    'text_cost' => sub{ 
 									my %pair = ();
 									$pair{cost} = $v{cost};
 									$pair{length} = $v{length};
 									$pair{field} = $v{field};
 									push @{$hash_info{text_cost}}, \%pair;
 								}, # attributes: length, cost
    'text_costs' => sub{""},
    'tool' => sub{ 
     				$tool = ucfirst($c);
     				my @intermediates = `ls modules/intermediate`;
     				if (!("Spline-$tool\n" ~~ @intermediates)){
   						system("cd modules/intermediate; h2xs -XAn Spline::$tool; chmod -R 777 Spline-$tool");
   						system("cp modules/intermediate/Spline-Services/.gitignore modules/intermediate/Spline-$tool/");
     				} 
 					},
    'documentation' => sub{""},
    'header' => sub{ 
								$documentation{$aux_doc}{title} = uc($v{title}); 
								$documentation{$aux_doc}{content} = $c;
								$aux_doc++; 
    				},
    'output' => sub{
    		if($method==1){
					print $fh create_main_function_perl($all_code, $method) if($lang eq 'perl');
					print $fh create_main_function_bash($all_code, $method) if($lang eq 'bash');
				}
    	},
    'file' => sub{ push @files, $c; },
    'dir' => sub{ 
    			push @dirs, $c; 
    			push @files, $c.".zip";
    		},
);
dt($filename, %handler);


sub create_hash_info{
	my ($hash_info) = @_;

	my $hash_token = $hash_info{hash_token};
	my $subtitle = $hash_info{subtitle};
	my $description = $hash_info{description};
	my $input = $hash_info{input};
	my $output = $hash_info{output};
	my $cost = $hash_info{cost};
	my $parameters = $hash_info{parameters};
	my $text_costs = $hash_info{text_cost};

	my $r = "\n";
	$r .= "my %index_info = (\n";
	  $r .= "\thash_token => '$hash_token',\n";
	  $r .= "\tparameters => {\n";
	    $r .= "\t\tapi_token => {\n";
	      $r .= "\t\t\tdescription => 'The token to be identified',\n";
	      $r .= "\t\t\trequired => 1,\n";
	      $r .= "\t\t\ttype => 'text',\n";
	    $r .= "\t\t},\n";
	  for( my $i = 0 ; $i < scalar @{$parameters} ; $i++){
	  	if (defined $parameters->[$i]{name}){
	  		my $aux_name = $parameters->[$i]{name};
	  		my $aux_required = $parameters->[$i]{required};
	  		my $aux_type = $parameters->[$i]{type};
		  	$r .= "\t\t$aux_name => {\n";
		      $r .= "\t\t\tdescription => '$parameters->[$i]{description}',\n" if(defined $parameters->[$i]{description});
		      $r .= "\t\t\trequired => $aux_required,\n";
		      $r .= "\t\t\ttype => '$aux_type',\n";
		      if(defined $parameters->[$i]{default}){
		      	if (looks_like_number($parameters->[$i]{default})){ $r .= "\t\t\tdefault => $parameters->[$i]{default},\n";}
		      	else {$r .= "\t\t\tdefault => '$parameters->[$i]{default}',\n";}
		      }
		    $r .= "\t\t},\n";
	  	}
	  }
	  $r .= "\t},\n";
	  $r .= "\tsubtitle => '$subtitle',\n" if(!($subtitle eq ""));
	  $r .= "\tdescription => '$description',\n" if(!($description eq ""));
	  $r .= "\tcost => $cost,\n";
	if ($text_costs and (scalar @{$text_costs}) > 0){
		$r .= "\ttext_cost => {\n";
		my %aux_costs = ();
		for( my $i = 0 ; $i < scalar @{$text_costs} ; $i++){
			my $aux_len = $text_costs->[$i]{length};
			my $aux_cost = $text_costs->[$i]{cost};
			my $aux_field = $text_costs->[$i]{field};
			push @{$aux_costs{$aux_field}}, $aux_len;
			push @{$aux_costs{$aux_field}}, $aux_cost;
		}
		for my $aux_field (keys %aux_costs){
			$r .= "\t\t$aux_field => [";
			for(my $i=0; $aux_costs{$aux_field}->[$i]; $i=$i+2){
				$r .= "[".$aux_costs{$aux_field}->[$i].",".$aux_costs{$aux_field}->[$i+1]."],";
			}
			$r .= "],\n";
		}
	  $r .= "\t},\n";
	}
	$r .= ");\n\n";

	return $r;
}

sub create_default_functions{
	my $function = "_".lc($tool)."_".lc($service);
	local $/=undef;
	open(my $fth, "<", "function_template.txt");
	$_ = <$fth>;
	s/service_function/$function/;
	my $result = $_;
	close($fth);
	return $result;
}

sub create_main_function_perl{
	my ($code, $method) = @_;
	my $parameters = $hash_info{parameters};
	my $result = "";

	$result = "sub _".lc($tool)."_".lc($service)."{\n";
	$result .= "\tmy (\$input_params) = \@_;\n";
	for( my $i = 0 ; $i < scalar @{$parameters} ; $i++){
  	if (defined $parameters->[$i]{name}){
  		my $aux_name = $parameters->[$i]{name};
  		my $aux_required = int($parameters->[$i]{required});
  		$result .=  "\tmy \$$aux_name = \$input_params->{$aux_name};\n";
  		$result .=  "\treturn unless \$$aux_name;\n" if($aux_required==1);
  	}
  }
  $result .= "\n";
  if($method == 0){
  	$result .= "\tmy \$ID = time();\n";
  	$result .= "\tsystem(\"mkdir public/data/results/\$ID\");\n";
		$result .= $code;
	}
	else{
		$result .= "\tmy \$ID = time();\n";
		$result .= "\tmy \$ans_json = \"data/json/\".\$ID.\".json\";\n";
		$result .= "\tmy \$json = \"public/\".\$ans_json;\n";

		$result .= "\tmy \%status = ();\n";
		$result .= "\t\$status{status} = 'processing';\n";
		$result .= "\t\$status{answer} = \$ans_json;\n\n";

		$result .= "\topen (my \$jfh, \">\", \$json) or die \"cannot open file: \$!\";\n";
			$result .= "\t\tprint \$jfh \"{\\\"status\\\":\\\"processing\\\", \\\"result\\\":[";
			for (my $i = 0; $i < ((scalar @files)-1); $i++){
				#print "------------AQUI: ".$files[$i]."----------\n";
				$result .= "\\\"".$files[$i]."\\\",";
			}
			$result .= "\\\"".$files[(scalar @files)-1]."\\\"";
			$result .= "]}\";\n";
		$result .= "\tclose(\$jfh);\n\n";

		$result .= "\tsystem(\"mkdir public/data/results/\$ID\");\n";

		$code =~ s/\\/\\\\/g;
		$code =~ s/\$/\\\$/g;
		$code =~ s/\@/\\\@/g;
		$code =~ s/\%/\\\%/g;
		$code =~ s/\"/\\\"/g;
		$code =~ s/\\\$ID/\$ID/g;
		#$code =~ s/\\\$json/\$json/g; 
		for( my $i = 0; $i < scalar @{$parameters}; $i++){
			if (defined $parameters->[$i]{name}){
				my $aux_name = $parameters->[$i]{name};
				$code =~ s/\\\$$aux_name/\$$aux_name/g;
			}
		}

		$result .= "\topen (my \$dfh, \">\", \"data/queue/\".\$ID) or die \"cannot open file: \$!\";\n";
			$result .= "\tprint \$dfh \"$packages\";\n";
			$result .= "\tprint \$dfh \"\\n\";\n";
			$result .= "\tprint \$dfh \"$code\";\n";
			$result .= "\tprint \$dfh \"\\n\";\n";
			$result .= "\tprint \$dfh \"";
			for (my $i = 0; $i < (scalar @dirs); $i++){
				$result .= "system(\\\"zip -r public/".$dirs[$i]." public/".$dirs[$i]."\\\");\n";
			}
			$result .= "system(\\\"perl -pi -e 's/\\\\\\\"status\\\\\\\":\\\\\\\"processing\\\\\\\"/\\\\\\\"status\\\\\\\":\\\\\\\"done\\\\\\\"/' \$json \\\");";
			$result .= "\";\n";
		$result .= "\tclose(\$dfh);\n\n";

		$result .= "\treturn \\\%status;\n";
	}
	$result .= "\n}\n\n1;\n__END__";

	return $result;
}

sub create_main_function_bash{
	my ($code, $method, $r_dirs, @r_files) = @_;
	my $parameters = $hash_info{parameters};
	my $result = "";

	$result = "sub _".lc($tool)."_".lc($service)."{\n";
	$result .= "\tmy (\$input_params) = \@_;\n";
	for( my $i = 0 ; $i < scalar @{$parameters} ; $i++){
  	if (defined $parameters->[$i]{name}){
  		my $aux_name = $parameters->[$i]{name};
  		my $aux_required = int($parameters->[$i]{required});
  		$result .=  "\tmy \$$aux_name = \$input_params->{$aux_name};\n";
  		$result .=  "\treturn unless \$$aux_name;\n" if($aux_required==1);
  	}
  }
  $result .= "\n";
  if($method == 0){
  	$code =~ s/\"/\\\"/g;
  	$code =~ s/\;\n/\;/g;
  	$code =~ s/^\n//g;
  	$code =~ s/\n/\;/g;
  	$code =~ s/[ \t]+/ /g;
  	$result .= "\tmy \%resulthash = ();\n";
		$result .= "\t\$resulthash{result} = `$code`;\n";
		$result .= "\tchomp \$resulthash{result};\n";
		$result .= "\treturn \\\%resulthash;\n";
	}
	else{
		$result .= "\tmy \$ID = time();\n";
		$result .= "\tmy \$ans_json = \"data/json/\".\$ID.\".json\";\n";
		$result .= "\tmy \$json = \"public/\".\$ans_json;\n";

		$result .= "\tmy \%status = ();\n";
		$result .= "\t\$status{status} = 'processing';\n";
		$result .= "\t\$status{answer} = \$ans_json;\n\n";

		$result .= "\topen (my \$jfh, \">\", \$json) or die \"cannot open file: \$!\";\n";
			$result .= "\t\tprint \$jfh \"{\\\"status\\\":\\\"processing\\\", \\\"result\\\":[";
			for (my $i = 0; $i < (scalar @files); $i++){
				$result .= "\\\"".$files[$i]."\\\",";
			}
			$result .= "\\\"data/results/\$ID/output.log\\\"";
			$result .= "]}\";\n";
		$result .= "\tclose(\$jfh);\n\n";

		$result .= "system(\"mkdir public/data/results/\$ID\");\n";

		$code =~ s/\\/\\\\/g;
		$code =~ s/\$/\\\$/g;
		$code =~ s/\@/\\\@/g;
		$code =~ s/\%/\\\%/g;
		$code =~ s/\"/\\\\\\\"/g; ## AQUI
		#$code =~ s/\\\$json/\$json/g; 
		for( my $i = 0 ; $i < scalar @{$parameters} ; $i++){
			if (defined $parameters->[$i]{name}){
				my $aux_name = $parameters->[$i]{name};
				$code =~ s/\\\$$aux_name/\$$aux_name/g;
			}
		}

		$result .= "\topen (my \$dfh, \">\", \"data/queue/\".\$ID) or die \"cannot open file: \$!\";\n";
			$result .= "\tprint \$dfh \"system(\\\"$code\\\");\";\n";
			$result .= "\tprint \$dfh \"\\n\";\n";
			$result .= "\tprint \$dfh \"";
			for (my $i = 0; $i < (scalar @{$r_dirs}); $i++){
				$result .= "system(\\\"zip -r public/".$r_dirs->[$i]." public/".$r_dirs->[$i]."\\\");\n";
			}
			$result .= "system(\\\"perl -pi -e 's/\\\\\\\"status\\\\\\\":\\\\\\\"processing\\\\\\\"/\\\\\\\"status\\\\\\\":\\\\\\\"done\\\\\\\"/' \$json \\\");";
			$result .= "\";\n";
		$result .= "\tclose(\$dfh);\n\n";

		$result .= "\treturn \\\%status;\n";
	}
	$result .= "\n}\n\n1;\n__END__";

	return $result;
}

sub create_tests{
	my ($toolx, $servicex, $aux_testx, $test_numberx, $hash_tokenx, %testsx) = @_;

	$aux_testx++;

	my $tfh;
	open($tfh, '>', "modules/Spline-$toolx-$servicex/t/generated_test".$test_numberx."_to_".lc($toolx)."_".lc($servicex).".t");

	print $tfh "use strict;\n";
	print $tfh "use warnings;\n";
	print $tfh "use HTTP::Tiny;\n";
	print $tfh "use Data::Dumper;\n";
	print $tfh "use JSON;\n\n";

	print $tfh "use Test::More tests => $aux_testx;\n";
	print $tfh "BEGIN { use_ok('Spline::$toolx::$servicex') };\n\n";

	print $tfh "my \$host = \$ENV{SPLINE_HOST} || 'localhost';\n";
	print $tfh "my \$port = \$ENV{SPLINE_PORT} || 8080;\n\n";

	print $tfh "my \%params = ();\n";
	print $tfh "\$params{api_token} = 'MAIlGopQUt';\n";

	for my $param (keys %{$testsx{test_param}}){
		print $tfh "\$params{$param} = '".$testsx{test_param}{$param}."';\n";
	}

	print $tfh "\nmy \$got = HTTP::Tiny->new->post_form(\"http://\".\$host.\":\".\$port.\"/$hash_tokenx\", \\\%params);\n";
	print $tfh "my \$result = decode_json(\$got->{content});\n\n";

	for my $codex (@{$testsx{test_code}}){
		print $tfh $codex."\n\n";
	}

	close($tfh);
}

sub create_documentation{
	my $result = "";
	for my $num (sort keys %documentation){
		$result .= "\n\n=head1 ".$documentation{$num}{title}."\n\n".$documentation{$num}{content};
	}
	return $result;
}