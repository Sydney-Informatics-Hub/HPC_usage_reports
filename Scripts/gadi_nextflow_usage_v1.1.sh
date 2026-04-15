#!/bin/bash

module load nextflow

RUN_NAME="$1"
WORKDIR="${2:-work}" # optional positional command line argument, default is './work'

if [ -z "$RUN_NAME" ]; then
    echo "No run name supplied. Exiting."
    exit 1
fi

OUTPUT="resource_usage.${RUN_NAME}.log"
TMPOUT="${OUTPUT}.tmp"

if [ -f "$TMPOUT" ]; then
    echo "Temp file ${TMPOUT} already exists. Refusing to run."
    exit 1
fi

if [ ! -d "$WORKDIR" ]; then
    echo "Cannot find work directory $WORKDIR. Exiting."
    exit 1
fi

nextflow log -f hash,name "$RUN_NAME" > "$TMPOUT"

if [[ ! -s "$TMPOUT" ]]; then
    echo "ERROR: run name $RUN_NAME not found in this directory" >&2
    rm -f "$TMPOUT"
    exit 1
fi

echo -e "Job_name\tHash\tLog_path\tExit_status\tService_units\tNCPUs_requested\tCPU_time_used(mins)\tCPU_efficiency\tMemory_requested\tMemory_used\tWalltime_requested\tWalltime_used(mins)\tJobFS_requested\tJobFS_used" > "$OUTPUT"

while read -r HASH JOBNAME; do
    LOG=$(find "$WORKDIR" -type f -path "*/${HASH}*" -name ".command.log" | head -n 1)

    if [[ -z "$LOG" ]]; then
        continue
    fi

    awk -v OFS="\t" -v logfile="$LOG" -v hash="$HASH" -v jobname="$JOBNAME" '
    function time_to_mins(t, a, n, h, m, s, total_secs) {
        n = split(t, a, ":")
        if (n != 3) return "NA"
        h = a[1] + 0
        m = a[2] + 0
        s = a[3] + 0
        total_secs = (h * 3600) + (m * 60) + s
        return total_secs / 60
    }

    BEGIN {
        exit_status = "NA"
        service_units = "NA"
        ncpus_requested = "NA"
        cpu_time_used = "NA"
        cpu_time_used_mins = "NA"
        cpu_efficiency = "NA"
        memory_requested = "NA"
        memory_used = "NA"
        walltime_requested = "NA"
        walltime_used = "NA"
        walltime_used_mins = "NA"
        jobfs_requested = "NA"
        jobfs_used = "NA"
    }

    /^=+$/ {flag1=1; next}
    flag1 && ! /Resource Usage/ {flag1=0; next}
    flag1 && /Resource Usage/ {flag2=1; next}

    flag2 {
        if ($0 ~ /Exit Status/)        exit_status = $3
        if ($0 ~ /Service Units/)      service_units = $3
        if ($0 ~ /NCPUs Requested/)    ncpus_requested = $3
        if ($0 ~ /CPU Time Used/)      cpu_time_used = $7
        if ($0 ~ /Memory Requested/)   memory_requested = $3
        if ($0 ~ /Memory Used/)        memory_used = $6
        if ($0 ~ /Walltime Requested/) walltime_requested = $3
        if ($0 ~ /Walltime Used/)      walltime_used = $6
        if ($0 ~ /JobFS Requested/)    jobfs_requested = $3
        if ($0 ~ /JobFS Used/)         jobfs_used = $6
    }

    END {
        if (cpu_time_used != "NA")
            cpu_time_used_mins = sprintf("%.2f", time_to_mins(cpu_time_used))

        if (walltime_used != "NA")
            walltime_used_mins = sprintf("%.2f", time_to_mins(walltime_used))

        if (cpu_time_used != "NA" && walltime_used != "NA" && ncpus_requested != "NA" && ncpus_requested > 0) {
            cpu_efficiency = time_to_mins(cpu_time_used) / time_to_mins(walltime_used) / ncpus_requested
            cpu_efficiency = sprintf("%.4f", cpu_efficiency)
        }

        print jobname, hash, logfile, exit_status, service_units, ncpus_requested, cpu_time_used_mins, cpu_efficiency, memory_requested, memory_used, walltime_requested, walltime_used_mins, jobfs_requested, jobfs_used
    }' "$LOG"

done < "$TMPOUT" >> "$OUTPUT"

rm "$TMPOUT"
