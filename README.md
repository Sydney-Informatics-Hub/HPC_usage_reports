# HPC usage reports

This repository contains scripts to pull resource usage data from job logs into tab-delimited format and to report queue time from job history. Usage reporting scripts are useful for resource benchmarking and accounting purposes. We currently provide scripts for: 

* [National Compute Infrastructure Gadi HPC](#nci-gadi-hpc)
* Executing nf-core pipelines on national HPCs

## Usage guide 

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

**[gadi_resource_usage.sh](Scripts/gadi_resource_usage.sh)**

This script takes a nextflow run name (e.g. from `nextflow log`), pulls out
all the task hashes from the run, and finds the relevant work directory
to collect `.command.log` files from that run only. The script gathers the job
requests and usage metrics from Gadi post-job files similar to [gadi-queuetime-report.pl](Scripts/gadi-queuetime-report.pl), and 
[gadi-nfcore-report.sh](Scripts/gadi-queuetime-report.pl). 

Results are printed to file: `resource_usage.<nextflow_run_name>.log`.

Example usage: 

```bash
nextflow log 
```
```console
TIMESTAMP               DURATION        RUN NAME                STATUS  REVISION ID     SESSION ID                              COMMAND                  

2026-02-25 11:51:55     -               kickass_cantor          -       593881520d      e2ddc027-c09f-487c-a241-be9771114df6    nextflow run main.nf ...
2026-02-25 11:54:03     50m 35s         loving_boltzmann        ERR     593881520d      e2ddc027-c09f-487c-a241-be9771114df6    nextflow run main.nf ...
2026-02-25 13:07:06     5h 34m 53s      maniac_lorenz           OK      593881520d      e2ddc027-c09f-487c-a241-be9771114df6    nextflow run main.nf ...
```

Collect logs:

```bash
bash Scripts/gadi_resource_usage.sh maniac_lorenz
```