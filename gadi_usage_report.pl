#!/usr/bin/env perl

#------------------------------------------------------------------
# gadi_usage_report/1.2 
# Platform: NCI Gadi HPC
#
# Description: 
# This script gathers the job requests and usage metrics from Gadi log 
# files for a collection of job log files with the same prefix within the
# same directory, and calculates efficiency values using the formula 
# e = cputime/walltime/cpus_used.
# If the CPU time is zero, the efficiency value will be reported as 
# 'ZERO_TIME'.
# # If no prefix is specified, a warning wil be given, and the usage metrics
# will be reported for all job logs found within the present directory.
#
# Usage:
# Run the script from within the directory that contains the log files
# to be read. Include the log prefix (do not include .<suffix>) as an argument
# on the command line, eg:
# perl <path/to/script/gadi_usage_report.pl <prefix>
#
# Output:
# Tab-delimited summary of the resources requested and used for each job 
# will be printed to STDOUT. Use output redirection when executing the 
# script to save the data to a text file, eg:
# perl <path/to/script/gadi_usage_report.pl <prefix> > resources_summary.txt  

# Author: Cali Willet
# cali.willet@sydney.edu.au
#
# Date last modified: 17/09/2020
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

my $dir=`pwd`;
chomp $dir; 

my $prefix = ''; 
if ($ARGV[0]) {
	$prefix=$ARGV[0]; 
	chomp $prefix;
}
else {
	print "\n######\nWARNING: no log prefix specified. Will report on all log files in $dir.\n######\n\n"; 
}

my @logs=split(' ', `ls $dir\/$prefix*.o*`); 
my $report={};

print "#JobName\tCPUs_requested\tCPUs_used\tMem_requested\tMem_used\tCPUtime\tCPUtime_mins\tWalltime_req\tWalltime_used\tWalltime_mins\tJobFS_req\tJobFS_used\tEfficiency\tService_units(CPU_hours)\n";

foreach my $file (@logs) { 
	my @name_fields = split('\/', $file);
	my ($name, $id) = split('\.', $name_fields[-1]);  
	my @walltime = split(' ', `grep -m 1 "Walltime" $file`); #weird glitch on Gadi where the usage was printed to .o twice - threw errors - fix with -m 1 
	my $walltime_req = $walltime[2];
	my $walltime_used = $walltime[5];
	my ($wall_hours, $wall_mins, $wall_secs) = split('\:', $walltime_used); 
	my $walltime_mins = sprintf("%.2f",(($wall_hours*60) + $wall_mins + ($wall_secs/60)));
	my @cpus = split(' ', `grep -m 1 "NCPUs" $file`); 
	my $cpus_req = $cpus[2];
	my $cpus_used = $cpus[5];	
	my @mem = split(' ', `grep -m 1 "Memory" $file`);	
	my $mem_req = $mem[2];
	my $mem_used = $mem[5];	
	chomp (my $cputime = `grep -m 1 "CPU Time Used" $file | awk '{print \$4}'`);
	my ($cpu_hours, $cpu_mins, $cpu_secs, $cputime_mins) = 0;
	my @jobFS = split(' ', `grep -m 1 "JobFS" $file`);
	my $jobFS_req = $jobFS[2];
	my $jobFS_used = $jobFS[5];		
	my $e = 0; 
	if ($cpus_used!~m/unknown/) {  #not sure if this 'unknown' report ever happens on Gadi like it does on Artemis...
		$cpus_used = ceil($cpus_used); 
		($cpu_hours, $cpu_mins, $cpu_secs) = split('\:', $cputime); 
		if ( ($cpu_hours == 0) && ($cpu_mins ==  0) && ($cpu_secs == 0) ) {
			$e = 'ZERO_TIME';
			$cputime_mins = 0; 
		}
		else {
			$cputime_mins = sprintf("%.2f",(($cpu_hours*60) + $cpu_mins + ($cpu_secs/60)));
			$e = sprintf("%.2f",($cputime_mins/$walltime_mins/$cpus_used));
		}	
	} 
	chomp (my $SUs = `grep -m 1 "Service Units" $file | awk '{print \$3}'`); 
	print "$name\t$cpus_req\t$cpus_used\t$mem_req\t$mem_used\t$cputime\t$cputime_mins\t$walltime_req\t$walltime_used\t$walltime_mins\t$jobFS_req\t$jobFS_used\t$e\t$SUs\n";
}
