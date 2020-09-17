#!/usr/bin/env perl

#------------------------------------------------------------------
# report_queue_time/1.0 
# Platform: NCI's Raijin
#
# Description: 
# This script reports the queue time of a collection of completed jobs
# with the same prefix on Raijin. If no prefix is specified, a warning 
# wil be given, and the queue time will be reported for all jobs with 
# logs found within the present directory. Please note that 
# queue time can only be reported up to 24 hours post-completion, as
# PBS does not preserve historical records on Raijin beyond this point.
# In order to remove this time restriction, jobs can be submitted with 
# the line 'qstat -xf $PBS_JOBID' anywhere in the job script. This will
# preserve the required record in the ".o" output log file. As such there
# are two ways in which this script can be run (see "Usage" below).
#
# Usage:
# Run the script from within the directory that contains the log 
# files for the jobs of interest. Include the prefix of the logs 
# as an argument on the command line, eg:
# perl <path/to/script/raijin_queuetime_report.pl <prefix>
# Option 1 - script is run within 24 hours of all jobs completing:
# No additional arguments are required
# Option 2 - 'qstat -xf $PBS_JOBID' has been included in the job script:
# Run the script with the additional flag 'q', eg:
# perl <path/to/script/raijin_queuetime_report.pl <prefix> -q
# This will cause the script to search for the required information 
# within the job logs instead of using qstat.
#
# Output:
# Tab-delimited summary of the job name and queue time will be printed 
# to STDOUT. Use output redirection when executing the script to save 
# the data to a text file, eg:
# perl <path/to/script/raijin_queuetime_report.pl <prefix> > queue_times.txt
#
# Author: Cali Willet
# cali.willet@sydney.edu.au
#
# Date last modified: 05/06/2019
#
# If you use this script towards a publication, please acknowledge the
# Sydney Informatics Hub (or co-authorship, where appropriate).
#
# Suggested acknowledgement:
# The authors acknowledge the scientific and technical assistance 
# <or e.g. bioinformatics assistance of <PERSON>> of Sydney Informatics
# Hub and resources and services from the National Computational 
# Infrastructure (NCI), which is supported by the Australian Government
# with access facilitated by the University of Sydney.
#------------------------------------------------------------------

use warnings;
use strict;
use POSIX;
use Time::Local; 

my $dir=`pwd`;
chomp $dir; 

my $prefix = '';
my $self_query = 0; 
foreach my $elem (@ARGV) {
	chomp $elem;
	if ($elem=~m/^\-q/) {
		$self_query = 1;
		 print "\n######\nObtaining queue time from log files. WARNING: this method will FAIL if the jobs were not run with 'qstat -xf \$PBS_JOBID' within the job script.\n######\n\n"; 
	}
	else {
		$prefix = $elem; 
	}
}

if (!$prefix) {
	print "\n######\nWARNING: no log prefix specified. Will report on all log files in $dir.\n######\n\n"; 
}

my @logs=split(' ', `ls $dir\/$prefix*.o*`);
my $report={};

print "#JobName\tQueue_name\tQueue_time(mins)\n";

foreach my $file (@logs) {
	my @name_fields = split('\/', $file);
	my ($name, $id) = split('\.', $name_fields[-1]);  
	$id=~s/^o//;
	
	my $ctime = ''; 
	my $stime = ''; 
	my $queue = '';
	
	if ($self_query) {
		
		chomp ($ctime = `grep "ctime" $file`);
		chomp ($stime = `grep "stime" $file`);
		chomp ($queue = `grep "queue" $file`);
	}
	else {
		chomp ($ctime = `qstat -xf $id | grep "ctime"`);  
		chomp ($stime = `qstat -xf $id | grep "stime"`); 
		chomp ($queue = `qstat -xf $id | grep "queue"`);
	}
	$ctime=~s/^.{16}//;
	$ctime=~s/.{5}$//;
	$stime=~s/.{16}//;
	$stime=~s/.{5}$//;
	my @queue = split(' ', $queue);	
	my $queue_name = $queue[-1]; 
	
	use constant Year => 2012;
	my $t1 = convert($ctime);
	my $t2 = convert($stime);
	my $queue_secs = $t2 - $t1;
	my $queue_mins = sprintf("%.2f", ($queue_secs/60));
	
	print "$name\t$queue_name\t$queue_mins\n";	
}

sub convert {
	    my $dstring = shift;

	    my %m = ( 'Jan' => 0, 'Feb' => 1, 'Mar' => 2, 'Apr' => 3,
		    'May' => 4, 'Jun' => 5, 'Jul' => 6, 'Aug' => 7,
		    'Sep' => 8, 'Oct' => 9, 'Nov' => 10, 'Dec' => 11 );

	    if ($dstring =~ /(\S+)\s+(\d+)\s+(\d{2}):(\d{2}):(\d{2})/) {
		my ($month, $day, $h, $m, $s) = ($1, $2, $3, $4, $5);
		my $mnumber = $m{$month}; 
		
		timelocal( $s, $m, $h, $day, $mnumber, Year - 1900 );
	    }
	    else {
		die "Format not recognized: ", $dstring, "\n";
	    }
}
