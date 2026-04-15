#!/usr/bin/env perl

#------------------------------------------------------------------
# gadi_usage_report/1.1
# Platform: NCI Gadi HPC
#
# Description:
# This script gathers the job requests and usage metrics from Gadi log
# files for a collection of job log files with the same prefix within the
# same directory, and calculates efficiency values using the formula
# e = cputime/walltime/cpus_used.
# # If no prefix is specified, a warning wil be given, and the usage metrics
# will be reported for all job logs found within the present directory.
#
# Version 1.1 updates
# Reports usage for all logs in /path/to/dir or for logs specified
# Faster, by only checking end of log (was slow for logs with big
# stdout)
# Reports job exit status
# Reports files with no usage log
#
# Usage:
# command line, eg:
# perl gadi_usage_report.pl /path/to/logdir
# perl gadi_usage_report.pl myjob.o
#
# Output:
# Tab-delimited summary of the resources requested and used for each job
# will be printed to STDOUT. Use output redirection when executing the
# script to save the data to a text file, eg:
# perl <path/to/script/gadi_usage_report.pl <prefix> > resources_summary.txt
#
# Date last modified: 02/06/21
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
use File::Basename;

my $dir=`pwd`;
chomp $dir;
my @logs;
my @no_report;

my $prefix = '';
if ($ARGV[0]) {
        @logs=@ARGV;
}
else {
        print "\n######\nWARNING: no log prefix specified. Will report on all log files in $dir.\n######\n\n";
        @logs=split(' ', `ls $dir\/$prefix*.o*`);
}

my $report={};

if(@logs){
        print "#JobName\tCPUs_requested\tCPUs_used\tMem_requested\tMem_used\tCPUtime\tCPUtime_mins\tWalltime_req\tWalltime_used\tWalltime_mins\tJobFS_req\tJobFS_used\tEfficiency\tService_units(CPU_hours)\tJob_exit_status\tDate\tTime\n";

        foreach my $file (@logs) {
                my @name_fields = split('\/', $file);
                my $name=basename($file);
                my @walltime = split(' ', `tail -12 $file | grep "Walltime"`);
                if($walltime[2]){
                        my $walltime_req = $walltime[2];
                        my $walltime_used = $walltime[5];
                        my ($wall_hours, $wall_mins, $wall_secs) = split('\:', $walltime_used);
                        my $walltime_mins = sprintf("%.2f",(($wall_hours*60) + $wall_mins + ($wall_secs/60)));
                        my @cpus = split(' ', `tail -12 $file | grep -i "NCPUs"`);
                        my $cpus_req = $cpus[2];
                        my $cpus_used = $cpus[5];
                        my @mem = split(' ', `tail -n 12 $file | grep -i "Memory"`);
                        my $mem_req = $mem[2];
                        my $mem_used = $mem[5];
                        chomp (my $cputime = `tail -12 $file | grep -i "CPU Time Used" | awk '{print \$4}'`);
                        my ($cpu_hours, $cpu_mins, $cpu_secs, $cputime_mins) = 0;
                        my @jobFS = split(' ', `tail -12 $file | grep -i "JobFS"`);
                        my $jobFS_req = $jobFS[2];
                        my $jobFS_used = $jobFS[5];
                        my $e = 0;
                        if ($cpus_used!~m/unknown/) {  #not sure if this 'unknown' report ever happens on Gadi like it does on Artemis...
                                $cpus_used = ceil($cpus_used);
                                ($cpu_hours, $cpu_mins, $cpu_secs) = split('\:', $cputime);
                                $cputime_mins = sprintf("%.2f",(($cpu_hours*60) + $cpu_mins + ($cpu_secs/60)));
                                $e = sprintf("%.2f",($cputime_mins/$walltime_mins/$cpus_used));
                        }
                        chomp (my $SUs = `tail -12 $file | grep -i "Service Units" | awk '{print \$3}'`);
                        chomp (my $exit_status = `tail -12 $file | grep -i "Exit Status" | cut -d ":" -f2 | awk '{\$1=\$1};1' | awk '{print \$1}'`);
                        chomp (my $date = `tail -12 $file | grep -i "Resource Usage on" | awk '{print \$4}'`);
                        chomp (my $time = `tail -12 $file | grep -i "Resource Usage on" | awk '{print \$5}' | sed 's/:\$//'`);
                        print "$name\t$cpus_req\t$cpus_used\t$mem_req\t$mem_used\t$cputime\t$cputime_mins\t$walltime_req\t$walltime_used\t$walltime_mins\t$jobFS_req\t$jobFS_used\t$e\t$SUs\t$exit_status\t$date\t$time\n";
                }
                else{
                        push(@no_report, $file);
                }
        }
}
if (@no_report){
        print "\n\n######\nWARNING: Usage metrics were not reported for: @no_report\n######\n\n";
}
