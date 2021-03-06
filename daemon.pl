#!/usr/bin/env perl

use App::Daemon qw( daemonize );
daemonize();

use Capture::Tiny ':all';
use JSON;
use Module::Load;

my @queue = ();
my $last = 1;

while(1){

	if(scalar @queue == 0){
		sleep(60) if($last==0);
		$last = 0;
		my @news = `ls data/queue`;
		@news = sort @news;
		push(@queue, @news);
	}

	if(scalar @queue > 0){
		my $file = $queue[0];
		chomp($file);
		$last = 1;

		local $/=undef;
		open(my $fh, "<", "data/queue/".$file);
			my $code = <$fh>;
			my ($stdout, $stderr, @result) = capture { eval $code; };
			open (my $lh, ">", "data/logs/".$file.".log");
				print $lh $stdout;
				print $lh $stderr if($stderr);
			close($lh);
		close($fh);

		system("rm data/queue/".$file);
		system("cp data/logs/$file.log public/data/results/$file/output.log ");
		shift @queue;
	}
}