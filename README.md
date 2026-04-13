# HPC usage reports

This repository contains scripts to pull resource usage data from job logs into tab-delimited format and to report queue time from job history. Usage reporting scripts are useful for resource benchmarking and accounting purposes. We currently provide scripts for: 

* [National Compute Infrastructure Gadi HPC](#nci-gadi-hpc)
* Executing nf-core pipelines on national HPCs

## Usage guide 

### NCI Gadi HPC 

**[gadi_usage_report_v1.2.pl](Scripts/gadi_usage_report_v1.2.pl)**

Description: 

This script gathers the job compute requests and usage metrics from Gadi PBS logs and summarises them into a tab-delimited output. 

Efficiency/utilisation values are reported for CPU using the formula `cpu_e = cputime/walltime/cpus_used`.

GPU usage (NGPUS, memory used, and GPU utilisation) can be optionally reported by appliny `-g` flag to the run.


Options:

```
  -a <dir>      Report on all .o log files in the specified directory
  -l <logfile>  Report on one exact logfile
  -p <pattern>  Report on .o log files matching a filename pattern
  -g            Include GPU metrics
```
 
At least one of `-a <val>`, `-l <val>` or `-p <val> must be supplied. `-g` can be optionallay added to any of these 3 options. Logs with no GPU usage will have `NA` for the 3 GPU output fields. 

Usage examples:
perl gadi_usage_report_v1.2.pl -a /path/to/logdir # all logs in dir
perl gadi_usage_report_v1.2.pl myjob.o -g # a specific log, report GPU usage
perl gadi_usage_report_v1.2.pl name # all logs with name including 'name'

Output:

Tab-delimited summary of the resources requested and used for each job will be printed to STDOUT. 

Use output redirection when executing the script to save the data to a text file, eg:

`perl <path/to/script/gadi_usage_report_v1.2.pl <options> > resources_summary.txt`
  
If no prefix is specified, a warning wil be given, and the usage metrics will be reported for all job logs found within the present directory. 

Example output:

```console
perl ./HPC_usage_reports/Scripts/gadi_usage_report_v1.2.pl -a /scratch/aa00/my-pbs-logs/ -g

######
Reporting on all usage log files in /scratch/aa00/my-pbs-logs/.
######

-g supplied - including GPU metrics
#JobName        Exit_status     Service_units   CPU_efficiency  CPUs    GPU_util        NGPUS   Mem_req Mem_used        GPU_mem_used    CPUtime_mins    Walltime_req    Walltime_mins   JobFS_req       JobFS_used Date
hg38_1140_test_three_cpu_only.o    0       8.28    0.14    12      NA      NA      48.0GB  14.99GB NA      11.88   00:10:00        6.90    100.0MB 0B      2026-03-19
dgxa100_4pod5drs_2ngpu.o        0       64.40   0.15    64      0.83    4       1000.0GB        34.71GB 312.89GB        130.72  00:30:00        13.42   200.0GB 0B      2026-04-13
gpuhopper_4pod5drs_2ngpu.o      0       41.20   0.36    24      0.74    2       480.0GB 33.39GB 173.62GB        117.37  00:30:00        13.73   200.0GB 0B      2026-04-12
gpuhopper_4pod5drs_4ngpu.o      0       115.60  0.21    48      0.11    4       1.0TB   35.7GB  372.48GB        190.73  00:30:00        19.27   200.0GB 0B      2026-04-13
gpuvolta_4pod5drs_2ngpu.o       0       113.84  0.19    48      0.83    4       382.0GB 32.98GB 91.47GB 431.80  01:00:00        47.43   200.0GB 0B      2026-04-13

```

**[gadi-nfcore-report.sh](Scripts/gadi_nfcore_report.sh)**

This script gathers the job requests and usage metrics from Gadi log files, same as [gadi-queuetime-report.pl](Scripts/gadi-queuetime-report.pl). However, this script loops through the Nextflow work directory to collect `.commmand.log` files and prints all output to a .tsv file: `gadi-nf-core-joblogs.tsv`

**[gadi_nextflow_usage_v1.1.sh](Scripts/gadi_nextflow_usage_v1.1.sh)**

This script takes a nextflow run name (e.g. from `nextflow log`), pulls out all the task hashes from the run, and finds the relevant work directory to collect `.command.log` files from that run only. The script gathers the job requests and usage metrics from Gadi post-job files similar to [gadi-queuetime-report.pl](Scripts/gadi-queuetime-report.pl), and 
[gadi-nfcore-report.sh](Scripts/gadi-queuetime-report.pl). 

Results are printed to file: `resource_usage.<nextflow_run_name>.log`.

Supply the run name as first and only positional argument to the script. If you have forgotten the run name, identify it from the output of the `nextflow log` command (most recent run name sprinted closest to command prompt): 

```bash
module load nextflow
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
bash Scripts/gadi_nextflow_usage.sh maniac_lorenz
```

Example output:
```console
Job_name        Hash    Log_path        Exit_status     Service_units   NCPUs_requested CPU_time_used(mins)     CPU_efficiency  Memory_requested        Memory_used     Walltime_requested      Walltime_used(mins)JobFS_requested  JobFS_used
PREPARE_GENOME:INDEX_MINIMAP2 (T2T)	68/7bbdc7	../work/68/7cbdc706bba77935ff576939e5478a/.command.log	0	0.19	4	2.42	0.4315	16.0GB	16.0GB	0:30:00	1.4	100.0MB	0B
PREPARE_GENOME:BUILD_BED12 (T2T)	a1/bad978	../work/a1/bad9785fc4775f110218ef1a350609/.command.log	NA	NA	NA	NA	NA	NA	NA	NA	NA	NA	NA
PREPARE_GENOME:INDEX_SAMTOOLS (T2T)	8d/3dd9b9	../work/8d/32d9b9ebe7d3993d8cc952f15b75e0/.command.log	0	0.09	12	0.15	0.0577	48.0GB	3.1GB	1:00:00	0.22	100.0MB	0B
MAPPING:MINIMAP2_MAP_SORT_INDEX (15022)	7a/2e38bd	../work/7a/2e38bd6b0dec1dc227f8de0b90d389/.command.log	0	33.71	24	608.33	0.6016	96.0GB	84.49GB	6:00:00	42.13	100.0MB	0B
MAPPING:MINIMAP2_MAP_SORT_INDEX (15022)	f6/d611b9	../work/f6/d611b993ae5fcf51ca6c0307425c98/.command.log	0	55.71	24	1066.82	0.6384	96.0GB	78.22GB	6:00:00	69.63	100.0MB	0B
BAM_QC (BAM QC: 15022)	1d/a2c7f5	../work/1d/a2c7f512627c840726d4c7375df4f2/.command.log	0	7.11	12	41.68	0.1953	48.0GB	48.0GB	1:00:00	17.78	100.0MB	0B
```
