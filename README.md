# HPC usage reports

This repository contains scripts to pull resource usage data from job logs into tab-delimited format and to report queue time from job history. Usage reporting scripts are useful for resource benchmarking and accounting purposes. We currently provide scripts for: 

* [University of Sydney's Artemis HPC](#artemis-hpc)
* [National Compute Infrastructure Gadi HPC](#nci-gadi-hpc)
* Executing nf-core pipelines on national HPCs

## Scripts 
### Artemis HPC 

**[artemis_queuetime_report.pl](Scripts/artemis_queuetime_report.pl)** 

This script reports the queue time of a collection of completed jobs with the same prefix on Artemis. If no prefix is specified, a warning will be given, and the queue time will be reported for all jobs with uasge logs found within the present directory. 

Please note that queue time can only be reported up to 14 days post-completion, as PBS does not preserve historical records beyond this point. In order to remove this time restriction, jobs can be submitted with the line `qstat -xf $PBS_JOBID` anywhere in the job script. This will preserve the required record in the ".o" output log file. As such there are two ways in which this script can be run. Please see script header for execution instructions. 


**[artemis_usage_report.pl](Scripts/artemis_usage_report.pl)** 

This script gathers the job requests and usage metrics from Artemis usage log files for a collection of job log files with the same prefix within the same directory, calculates efficiency values using the formula:  
```
e = cputime/walltime/cpus_used
```
Service units (SUs) are calculated using the formula:
```
SU = walltime * cpus_requested.
```
If no prefix is specified, a warning will be given, and the usage metrics will be reported for all usage logs found within the present directory. Please see script header for execution instructions. 

### NCI Gadi HPC 

**[gadi-usage-report.pl](Scripts/gadi_usage_report.pl)**

This script gathers the job requests and usage metrics from Gadi log files for a collection of job log files with the same prefix within the same directory, and calculates efficiency values using the formula:
```
e = cputime/walltime/cpus_used
```

If no prefix is specified, a warning wil be given, and the usage metrics will be reported for all job logs found within the present directory. Please see script header for execution instructions.

**[gadi-queuetime-report.pl](Scripts/gadi_queuetime_report.pl)** 

This script reports the queue time of a collection of completed jobs with the same output log file prefix on Gadi. If no prefix is specified, a warning will be given, and the queue time will be reported for all jobs with logs found within the present directory. Please note that PBS does not preserve job history on Gadi past 24 hours post job-completion.

In order to remove this time restriction, jobs can be submitted with the line `qstat -xf $PBS_JOBID`` anywhere in the job script, with or without output redirection. This will preserve the required record in the ".o" output log file (no output redirection) or on a separate file (with output redirection). There are THREE ways in which this script can be run. Please see script header for execution instructions.

**[gadi-nfcore-report.sh](Scripts/gadi_nfcore_report.sh)**

This script gathers the job requests and usage metrics from Gadi log files, same as [gadi-queuetime-report.pl](Scripts/gadi-queuetime-report.pl). However, this script loops through the Nextflow work directory to collect `.commmand.log` files and prints all output to a .tsv file: `gadi-nf-core-joblogs.tsv`