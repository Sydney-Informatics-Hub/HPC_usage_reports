#!/usr/bin/env perl

#------------------------------------------------------------------
# queuetime_report/1.1 
# Platform: NCI's Gadi
#
# Description: 
# This script reports the queue time of a collection of completed jobs
# with the same output log file prefix on Gadi. If no prefix is specified, 
# a warning wil be given, and the queue time will be reported for all jobs
# with logs found within the present directory. Please note that PBS does
# not preserve job history on Gadi past 24 hours post job-completion.
# In order to remove this time restriction, jobs can be submitted with 
# the line 'qstat -xf $PBS_JOBID' anywhere in the job script, with or 
# without output redirection. This will preserve the required record in 
# the ".o" output log file (no output redirection) or on a separate file
# (with output redirection). There are THREE ways in which this script 
# can be run (see "Usage" below).
#
# Usage:
# Run the script from within the directory that contains the log 
# files for the jobs of interest. Include the prefix of the logs 
# as an argument on the command line, eg:
# perl <path/to/script/queuetime_report.pl <prefix>
#
# Option 1 - script is run within 24 hours of all jobs completing, AND
# the PBS_JOBID is suffix of the logs (Gadi default log file naming):
# No additional arguments are required
#
# Option 2 - 'qstat -xf $PBS_JOBID' has been included in the job script,
# so that the queue time can be reported at any time (not limited to within
# 24 hours of job completion):
# Run the script with the additional flag 'q', eg:
# perl <path/to/script/queuetime_report.pl <prefix> -q
# This will cause the script to search for the required information 
# within the job usage log instead of using qstat.
#
# Option 3 - 'qstat -xf $PBS_JOBID' has been included in the job script,
# and the output redirected to a file with suffix '.qstat'. This file will 
# be searched for the queue time information.
# Run the script with the additional flag 'f', eg:
# perl <path/to/script/queuetime_report.pl <prefix> -f
#
# Output:
# Tab-delimited summary of the job name and queue time will be printed 
# to STDOUT. Example:
# $ ~/queuetime_report.pl align_ -f
# 
# ######
# Obtaining queue time from usage log. WARNING: this method will FAIL if the jobs were not run with 'qstat -xf $PBS_JOBID > <somefilename>.qstat' within the job script.
# ######
#
# #JobName        Queue_name      Queue_time(mins)
# align_100nodes_270179   normal-exec     0.92
# align_200nodes_ks07_chunk3      normal-exec     27.63
# align_200nodes_oj47_chunk4      normal-exec     244.87
# align_20nodes_mo73_chunk8       normal-exec     44.02
# align_25nodes_mo73_chunk5       normal-exec     25.08
# align_40nodes_ks07_chunk9       normal-exec     0.23
# align_75nodes_vt74_chunk6       normal-exec     121.60
#
#
# Use output redirection when executing the script to save 
# the data to a text file, eg:
# perl <path/to/script/queuetime_report.pl <prefix> > queue_times.txt
#
# Author: Cali Willet
# cali.willet@sydney.edu.au
#
# Date last modified: 11/012/2019
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
my ($self_query, $file_query) = 0; 
foreach my $elem (@ARGV) {
	chomp $elem;
	if ($elem=~m/^\-q/) {
		$self_query = 1;
		 print "\n######\nObtaining queue time from usage log. WARNING: this method will FAIL if the jobs were not run with 'qstat -xf \$PBS_JOBID' within the job script.\n######\n\n"; 
	}
	if ($elem=~m/^\-f/) {
		$file_query = 1;
		 print "\n######\nObtaining queue time from usage log. WARNING: this method will FAIL if the jobs were not run with 'qstat -xf \$PBS_JOBID > <somefilename>.qstat' within the job script.\n######\n\n"; 
	}	
	else {
		$prefix = $elem; 
	}
}

if (!$prefix) {
	print "\n######\nWARNING: no log prefix specified. Will report on all log files in $dir.\n######\n\n"; 
}

my @logs = (); 
if ($file_query) {
	@logs = split(' ', `ls $dir\/$prefix*.qstat*`);
}
else {
	@logs = split(' ', `ls $dir\/$prefix*.o*`);
}
my $report={};

print "#JobName\tQueue_name\tQueue_time(mins)\n";

foreach my $file (@logs) {
	my @name_fields = split('\/', $file);
	my ($name, $id) = split('\.', $name_fields[-1]);  
	$id=~s/^o//;
	
	my $ctime = ''; 
	my $stime = ''; 
	my $queue = '';
	
	if ( ($self_query) || ($file_query) ) {		
		chomp ($ctime = `grep "ctime" $file`);
		chomp ($stime = `grep "stime" $file`);
		chomp ($queue = `grep "queue" $file`);
	}
	else {
		my @name_fields = split('\/', $file);
		my ($name, $id) = split('\.', $name_fields[-1]);  
		$id=~s/^o//;		
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

