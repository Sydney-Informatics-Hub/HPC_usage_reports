#!/usr/bin/env perl

#------------------------------------------------------------------
# gadi_usage_report_v1.2 
# Platform: NCI Gadi HPC
#
# Description: 
# This script gathers the job requests and usage metrics from Gadi 
# PBS log and reports them as TSV. Efficiency/utilisation values are 
# reported for CPU using the formula cpu_e = cputime/walltime/cpus_used.
# GPU usage can be optionally reported.
#
# Date last modified: 13/04/26
# Version 1.2 updates: 
# - reorder headings to bring VIP details to fore
# - remove clock time, to reduce log complexity
# - updated to match new NCI .o log format omitting 'NCPUs Used' from Q4.2025
# - added optional reporting of gpu metrics with `-g` 
# - added usage option to do all logs matching pattern word:
# - reformatted as options (min 1, max 2) rather than 1 positional arg
#
# Options:
#  -a <dir>      Report on all .o log files in the specified directory
#  -l <logfile>  Report on one exact logfile
#  -p <pattern>  Report on .o log files matching a filename pattern
#  -g            Include GPU metrics
# 
# At least one of a, l or p umust be supplied with arguments, -g can be
# optionallay added to any of these 3 options.
#
# Usage examples:
#
# perl gadi_usage_report_v1.2.pl -a /path/to/logdir # all logs in dir
# perl gadi_usage_report_v1.2.pl myjob.o -g # a specific log, report GPU usage
# perl gadi_usage_report_v1.2.pl name # all logs with name including 'name'
# 
# Output:
# Tab-delimited summary of the resources requested and used for each job 
# will be printed to STDOUT. Use output redirection when executing the 
# script to save the data to a text file, eg:
# perl <path/to/script/gadi_usage_report.pl <input> > resources_summary.txt  
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
use Getopt::Std;

my %opt;
getopts('a:l:p:g', \%opt);

my $dir=`pwd`;
chomp $dir;
my @logs;
my @no_report;

# Check that exactly one of -a, -l, -p was supplied
my $n_modes = 0;
$n_modes++ if defined $opt{a};
$n_modes++ if defined $opt{l};
$n_modes++ if defined $opt{p};

if ($n_modes > 1) {
    die "\nERROR: Please supply only one of -a <dir>, -l <logfile>, or -p <pattern>\n\n";
}

if (defined $opt{l}) {
    my $logfile = $opt{l};
    chomp $logfile;
    @logs = (`ls "$logfile"`);
}
elsif (defined $opt{p}) {
    my $prefix = $opt{p};
    chomp $prefix;
    @logs = split(' ', `ls $dir/*$prefix*.o`);
}
elsif (defined $opt{a}) {
    my $target_dir = $opt{a};
    chomp $target_dir;
    print "\n######\nReporting on all usage log files in $target_dir.\n######\n\n";
    @logs = split(' ', `ls $target_dir/*.o`);
}
else {
    print "\n######\nNo log selection flag specified. Will report on all usage log files in $dir.\n######\n\n";
    @logs = split(' ', `ls $dir/*.o`);
}

my $g = 0;
if ($opt{g}) {
    $g = 1;
    print "-g supplied - including GPU metrics\n";
}

my $report={};

if (@logs){

    if ($g) {
        print "#JobName\tExit_status\tService_units\tCPU_efficiency\tCPUs\tGPU_util\tNGPUS\tMem_req\tMem_used\tGPU_mem_used\tCPUtime_mins\tWalltime_req\tWalltime_mins\tJobFS_req\tJobFS_used\tDate\n";
    }
    else {
        print "#JobName\tExit_status\tService_units\tCPU_efficiency\tCPUs\tMem_req\tMem_used\tCPUtime_mins\tWalltime_req\tWalltime_mins\tJobFS_req\tJobFS_used\tDate\n";
    }

    foreach my $file (@logs) {
        chomp $file;
        my @name_fields = split('\/', $file);
        my $name=basename($file);
        my @walltime = split(' ', `tail -12 $file | grep "Walltime"`);

        if($walltime[2]){
            # walltime
            my $walltime_req = $walltime[2];
            my $walltime_used = $walltime[5];
            my ($wall_hours, $wall_mins, $wall_secs) = split('\:', $walltime_used);
            my $walltime_mins = sprintf("%.2f",(($wall_hours*60) + $wall_mins + ($wall_secs/60)));

            # memory
            my @mem = split(' ', `tail -n 12 $file | grep -i "Memory"`);
            my $mem_req = $mem[2];
            my $mem_used = $mem[5];

            # cpus, cpu time and cpu e
            my @cpus = split(' ', `tail -12 $file | grep -i "NCPUs"`);
            my $cpus = $cpus[2];

            chomp (my $cputime = `tail -12 $file | grep -i "CPU Time Used" | awk '{print \$7}'`);
            my ($cpu_hours, $cpu_mins, $cpu_secs, $cputime_mins) = 0;
            my $cpu_e = 0;
            if ($cpus!~m/unknown/) {  # not sure if this 'unknown' report ever happens on Gadi like it does on Artemis...
                $cpus = ceil($cpus);
                ($cpu_hours, $cpu_mins, $cpu_secs) = split('\:', $cputime);
                $cputime_mins = sprintf("%.2f",(($cpu_hours*60) + $cpu_mins + ($cpu_secs/60)));
                $cpu_e = sprintf("%.2f",($cputime_mins/$walltime_mins/$cpus));
            }
            chomp (my $SUs = `tail -12 $file | grep -i "Service Units" | awk '{print \$3}'`);
            chomp (my $exit_status = `tail -12 $file | grep -i "Exit Status" | cut -d ":" -f2 | awk '{\$1=\$1};1' | awk '{print \$1}'`);
            chomp (my $date = `tail -12 $file | grep -i "Resource Usage on" | awk '{print \$4}'`);
            chomp (my $time = `tail -12 $file | grep -i "Resource Usage on" | awk '{print \$5}' | sed 's/:\$//'`);

            # jobfs
            my @jobFS = split(' ', `tail -12 $file | grep -i "JobFS"`);
            my $jobFS_req = $jobFS[2];
            my $jobFS_used = $jobFS[5];

            # ngpus, gpu util, gpu memory
            my ($gpu_u, $ngpus, $gpu_mem) = 0;
            if ($g) { 
                my @gpus = split(' ', `tail -n 12 $file | grep -i -m 1 "NGPU"`);
                my @gpu_mem = split(' ', `tail -n 12 $file | grep -i -m 1 "GPU Memory"`); 
                
                if (defined $gpus[2] && defined $gpus[5] && $gpus[2] ne '0') {
                    my $gpu_util = $gpus[5];
                    $gpu_util =~ s/\%$//;
                    $ngpus = $gpus[2];
                    $gpu_mem = $gpu_mem[3];
                    $gpu_u = sprintf("%.2f", ($gpu_util / ($ngpus * 100)));
                }
                else {
                    $gpu_u = 'NA';
                    $ngpus = 'NA';
                    $gpu_mem = 'NA';
                }                
            }

            # print
            if ($g) {
                print "$name\t$exit_status\t$SUs\t$cpu_e\t$cpus\t$gpu_u\t$ngpus\t$mem_req\t$mem_used\t$gpu_mem\t$cputime_mins\t$walltime_req\t$walltime_mins\t$jobFS_req\t$jobFS_used\t$date\n";
            }
            else {
                print "$name\t$exit_status\t$SUs\t$cpu_e\t$cpus\t$mem_req\t$mem_used\t$cputime_mins\t$walltime_req\t$walltime_mins\t$jobFS_req\t$jobFS_used\t$date\n";
            }
        }
        else{
            push(@no_report, $file);
        }
    }
}
if (@no_report){
    print "\n\n######\nWARNING: Usage metrics were not reported for: @no_report\n######\n\n";
}
