#!/usr/bin/env perl

# #------------------------------------------------------------------
# flashlite_usage_report/1.0
# Platform: Flashlite
# #
# # Description:
# # This script gathers the job requests and usage metrics from Flashlite log
# # files for a collection of job log files with the same prefix within the
# # same directory, and calculates efficiency values using the formula
# # e = cputime/walltime/cpus_used.
# # # If no prefix is specified, a warning wil be given, and the usage metrics
# # will be reported for all job logs found within the present directory.
# #
# # Usage:
# # Run the script from within the directory that contains the log files
# # to be read. Include the log prefix as an argument on the
# # command line, eg:
# # perl <path/to/script/gadi_usage_report.pl <prefix>
# #
# # Output:
# # Tab-delimited summary of the resources requested and used for each job
# # will be printed to STDOUT. Use output redirection when executing the
# # script to save the data to a text file, eg:
# # perl <path/to/script/gadi_usage_report.pl <prefix> > resources_summary.txt
#
# # Author: Tracy Chew
# # tracy.chew@sydney.edu.au
# #
# # Date last modified: 13/08/2020
# #
# # If you use this script towards a publication, please acknowledge the
# # Sydney Informatics Hub (or co-authorship, where appropriate).
# #
# # Suggested acknowledgement:
# # The authors acknowledge the scientific and technical assistance
# # <or e.g. bioinformatics assistance of <PERSON>> of Sydney Informatics
# # Hub and resources and services from the National Computational
# # Infrastructure (NCI), which is supported by the Australian Government
# # with access facilitated by the University of Sydney.
# #------------------------------------------------------------------

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

my @logs=split(' ', `ls $dir\/$prefix*.e*`);
my $report={};

print "#JobName\tCPUs_requested\tCPUs_used\tCPU_percent\tMem_requested\tMem_used\tVMem_used\tCPUtime\tCPUtime_mins\tWalltime_req\tWalltime_used\tWalltime_mins\tJobFS_req\tJobFS_used\tEfficiency\tService_units(1*CPU_hours)\tQueue\tAccount\tExitStatus\tJobID\n";

foreach my $file (@logs) {
	my $report_found=`grep -im 1 "Job Execution History" $file`;
	if ($report_found){
		my $jobname=`grep -im 1 JobName $file | cut -d':' -f2`;
		my $req=`grep -im 1 ResourcesRequested $file`;
		my($mem_req,$cpus_req,$place_req,$walltime_req)=split(',',$req);
		$cpus_req=~s/ncpus=//g;
		$mem_req=~s/ResourcesRequested:mem=//g;
		$walltime_req=~s/walltime=//g;
		# Collect resources used
		my $used=`grep -im 1 ResourcesUsed $file`;
		my($cpu_pc_used,$cputime,$mem_used,$cpus_used,$vmem_used,$walltime_used)=split(',',$used);
		$cpu_pc_used=~s/ResourcesUsed:cpupercent=//g;
		$cpus_used=~s/ncpus=//g;
		$mem_used=~s/mem=//g;
		$vmem_used=~s/vmem=//g;
		$cputime=~s/cput=//g;
		my ($cpu_hours, $cpu_mins, $cpu_secs) = split('\:', $cputime);
		my $cputime_mins = sprintf("%.2f",(($cpu_hours*60) + $cpu_mins + ($cpu_secs/60)));
		my $cputime_hours = sprintf("%.2f",($cputime_mins/60));
		$walltime_used=~s/walltime=//g;
		my ($wall_hours, $wall_mins, $wall_secs) = split('\:', $walltime_used);
		my $walltime_mins = sprintf("%.2f",(($wall_hours*60) + $wall_mins + ($wall_secs/60)));
		my $e = sprintf("%.2f",($cputime_mins/($walltime_mins*$cpus_used)));
		my $queue=`grep -im 1 QueueUsed $file | cut -d':' -f2`;
		my $account=`grep -im 1 AccountString $file | cut -d':' -f2`;
		my $exit=`grep -im 1 ExitStatus $file | cut -d':' -f2`;
		my $jobid=`grep -im 1 JobId $file | cut -d':' -f2`;
		chomp($jobname,$cpus_req,$mem_req,$walltime_req,$walltime_used,$queue,$account,$exit,$jobid);
		print "$jobname\t$cpus_req\t$cpus_used\t$cpu_pc_used\t$mem_req\t$mem_used\t$vmem_used\t$cputime\t$cputime_mins\t$walltime_req\t$walltime_used\t$walltime_mins\tNA\tNA\t$e\t$cputime_hours\t$queue\t$account\t$exit\t$jobid\n";
	}
}

exit;
