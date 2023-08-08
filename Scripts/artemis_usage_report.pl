#!/usr/bin/env perl

#------------------------------------------------------------------
# artemis_usage_report/1.1 
# Platform: University of Sydney's Artemis HPC
#
# Description: 
# This script gathers the job requests and usage metrics from Artemis uasge
# log files for a collection of job log files with the same prefix within the
# same directory, calculates efficiency values using the formula 
# e = cputime/walltime/cpus_used, and calculates service
# units (SUs) using the formula SU = walltime * cpus_requested.
# If no prefix is specified, a warning wil be given, and the usage metrics
# will be reported for all usage logs found within the present directory.
#
# Usage:
# Run the script from within the directory that contains the usage log files
# to be read. Include the prefix of the usage logs as an argument on the 
# command line, eg:
# perl <path/to/script/artemis_usage_report.pl <prefix>
#
#Output:
# Tab-delimited summary of the resources requested and used for each job 
# will be printed to STDOUT. Use output redirection when executing the 
# script to save the data to a text file, eg:
# perl <path/to/script/artemis_usage_report.pl <prefix> > resources_summary.txt
#
# Author: Cali Willet
# cali.willet@sydney.edu.au
#
# Date last modified: 15/01/2021
#
# If you use this script towards a publication, please acknowledge the
# Sydney Informatics Hub (or co-authorship, where appropriate).
#
# Suggested acknowledgement:
# The authors acknowledge the scientific and technical assistance 
# <or e.g. bioinformatics assistance of <PERSON>> of Sydney Informatics
# Hub and the University of Sydney's high performance computing cluster 
# Artemis for providing the high performance computing resources that have 
# contributed to the research results reported within this paper.
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


my @logs=split(' ', `ls $dir\/$prefix*.o*usage | sort -V`);
my $report={};

print "#JobName\tExit_status\tCPUs_requested\tCPUs_used\tMem_requested\tMem_used\tCPUtime\tCPUtime_mins\tWalltime_req\tWalltime_used\tWalltime_mins\tEfficiency\tService_units(CPU_hours)\n";

foreach my $file (@logs) {
        my @name_fields = split('\/', $file);
        my $filename=$name_fields[-1];
        my ($name, $id) = split('\.', $name_fields[-1]);
        chomp (my $exit_status=`tail -45 $file | grep "Exit Status:" | awk '{print \$3}'`);
        my @walltime = split(' ', `tail -45 $file | grep "Walltime requested"`);
        my $walltime_req = $walltime[2];
        my $walltime_used = $walltime[6];
        my ($wall_hours, $wall_mins, $wall_secs) = split('\:', $walltime_used);
        my $walltime_mins = sprintf("%.2f",(($wall_hours*60) + $wall_mins + ($wall_secs/60)));
        my @mem = split(' ', `tail -45 $file | grep "Mem requested"`);
        my $mem_req = $mem[2];
        my $mem_used = $mem[6];
        my @cpus = split(' ', `tail -45 $file | grep "Cpus requested"`);
        my $cpus_req = $cpus[2];
        my $cpus_used = $cpus[6];
        chomp (my $cputime = `tail -45 $file | grep "Cpu Time" | awk '{print \$3}'`);
        my ($cpu_hours, $cpu_mins, $cpu_secs, $cputime_mins) = 0;
        my $e = 0;
        if ($cpus_used!~m/unknown/) {
                $cpus_used = ceil($cpus_used);
                ($cpu_hours, $cpu_mins, $cpu_secs) = split('\:', $cputime);
                $cputime_mins = sprintf("%.2f",(($cpu_hours*60) + $cpu_mins + ($cpu_secs/60)));
                $e = sprintf("%.2f",($cputime_mins/$walltime_mins/$cpus_used));
                my $SUs = sprintf("%.2f", (($walltime_mins/60)*$cpus_req));
                print "$filename\t$exit_status\t$cpus_req\t$cpus_used\t$mem_req\t$mem_used\t$cputime\t$cputime_mins\t$walltime_req\t$walltime_used\t$walltime_mins\t$e\t$SUs\n";
        }
        else{
                print "$filename\t$exit_status\t$cpus_req\tunknown\t$mem_req\tunknown\tunknown\tunknown\t$walltime_req\t$walltime_used\t$walltime_mins\tunknown\tunknown\n";
        }
}
print "\n";
