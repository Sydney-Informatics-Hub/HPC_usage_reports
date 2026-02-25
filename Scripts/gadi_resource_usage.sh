#!/bin/bash

module load nextflow

RUN_NAME="$1"

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

if [ ! -d "work" ]; then
    echo "Cannot find work directory. Exiting."
    exit 1
fi

FIRST=true
SEARCH_PARAMS=()

nextflow log -f hash,name "$RUN_NAME" > "$TMPOUT"

while read HASH NAME; do
    if $FIRST; then
        SEARCH_PARAMS+=("-path" "*/${HASH}*")
        FIRST=false
    else
        SEARCH_PARAMS+=("-o" "-path" "*/${HASH}*")
    fi
done < "$TMPOUT"

echo -e "Job_name\tHash\tLog_path\tExit_status\tService_units\tNCPUs_requested\tCPU_time_used\tMemory_requested\tMemory_used\tWalltime_requested\tWalltime_used\tJobFS_requested\tJobFS_used" > "$OUTPUT"

find work -type f \( "${SEARCH_PARAMS[@]}" \) -name ".command.log" | \
    while read LOG; do
        HASH="${LOG:5:9}"
        JOBNAME=$(grep -m 1 -F "$HASH" "${TMPOUT}" | cut -f 2- )
        awk -v OFS="\t" -v logfile="$LOG" -v hash="$HASH" -v jobname="$JOBNAME" '
        BEGIN {
            exit_status = "NA"
            service_units = "NA"
            ncpus_requested = "NA"
            cpu_time_used = "NA"
            memory_requested = "NA"
            memory_used = "NA"
            walltime_requested = "NA"
            walltime_used = "NA"
            jobfs_requested = "NA"
            jobfs_used = "NA"
        }
        /^=+$/ {flag1=1; next}
        flag1 && ! /Resource Usage/ {flag1=0; next}
        flag1 && /Resource Usage/ {flag2=1; next}
        flag2 {
            if($0 ~ /Exit Status/) exit_status = $3
            if($0 ~ /Service Units/) service_units = $3
            if($0 ~ /NCPUs Requested/) ncpus_requested = $3
            if($0 ~ /CPU Time Used/) cpu_time_used = $7
            if($0 ~ /Memory Requested/) memory_requested = $3
            if($0 ~ /Memory Used/) memory_used = $6
            if($0 ~ /Walltime Requested/) walltime_requested = $3
            if($0 ~ /Walltime Used/) walltime_used = $6
            if($0 ~ /JobFS Requested/) jobfs_requested = $3
            if($0 ~ /JobFS Used/) jobfs_used = $6
        }
        END {
            print jobname, hash, logfile, exit_status, service_units, ncpus_requested, cpu_time_used, memory_requested, memory_used, walltime_requested, walltime_used, jobfs_requested, jobfs_used
        }' $LOG
    done >> "${OUTPUT}"

rm "${TMPOUT}"