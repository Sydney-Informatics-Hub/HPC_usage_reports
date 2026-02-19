#!/usr/bin/env python3
"""
match_nf_logs.py
================
Joins two Nextflow-related log files on their shared work directory hash,
producing a single merged TSV ready for Excel.

Input files
-----------
-n / --nf-log     Nextflow task log TSV, produced by:
                      nextflow log <run_name> -f 'name,status,native_id,work_dir'
                  Expected columns (tab-separated, no header):
                      name  status  native_id  work_dir

-l / --log-report PBS resource-usage report TSV produced by the
                  gadi_nfcore_report / collect_nf_logs pipeline.
                  Expected first column:  Log_path  (e.g. work/XX/HASH/.command.log)
                  Remaining columns:      Exit_status  Service_units  NCPUs_requested ...

Output
------
-o / --output     Merged TSV (default: matched_logs.tsv).
                  Unmatched rows from either file are written to
                  <output>.unmatched.tsv so nothing is silently lost.

Usage
-----
    python3 match_nf_logs.py -n nextflow_log.tsv -l log_report.tsv
    python3 match_nf_logs.py -n nextflow_log.tsv -l log_report.tsv -o my_run.tsv
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def work_key(path: str) -> Optional[str]:
    """
    Extract a normalised 'XX/HASH' key from any string that contains a
    Nextflow work directory path.  Works whether the path is:
      - a full absolute path  (/scratch/.../work/9e/c258d1ff...)
      - a relative path       (work/9e/c258d1ff.../.command.log)
      - a truncated hash      (work/9e/c258d1...)
    Returns None if no work-dir pattern is found.
    """
    m = re.search(r'work/([0-9a-f]{2}/[0-9a-f]{6,})', path)
    if not m:
        return None
    prefix, hashpart = m.group(1).split('/', 1)
    # Normalise: lowercase, strip any trailing /.command.log or similar
    return f"{prefix.lower()}/{hashpart.lower()}"


def read_tsv(path: str) -> tuple[list[str], list[list[str]]]:
    """Return (header_row, data_rows) for a TSV file.  Header is the first
    line if it doesn't look like a work-dir path, otherwise header=[].
    """
    lines = Path(path).read_text().splitlines()
    lines = [l for l in lines if l.strip()]
    if not lines:
        return [], []

    # Detect header: first column of first line is not a path
    first_col = lines[0].split('\t')[0]
    if first_col.startswith('work/') or first_col.startswith('/'):
        header = []
        data = [l.split('\t') for l in lines]
    else:
        header = lines[0].split('\t')
        data = [l.split('\t') for l in lines[1:]]
    return header, data


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="Match a Nextflow task log with a PBS resource report on work-dir hash.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    ap.add_argument('-n', '--nf-log',     required=True,
                    help='Nextflow log TSV (name, status, native_id, work_dir)')
    ap.add_argument('-l', '--log-report', required=True,
                    help='PBS resource report TSV (Log_path as first column)')
    ap.add_argument('-o', '--output',     default='matched_logs.tsv',
                    help='Output TSV (default: matched_logs.tsv)')
    args = ap.parse_args()

    # -----------------------------------------------------------------------
    # 1. Load the Nextflow log
    # -----------------------------------------------------------------------
    nf_header, nf_rows = read_tsv(args.nf_log)

    # Build lookup:  work_key -> row (list of strings)
    # We expect columns: name, status, native_id, work_dir
    # but accept 3-column files where work_dir is missing (native_id may be
    # the path for CACHED tasks with no PBS ID).
    NF_COLS = ['Task_name', 'NF_status', 'Native_id', 'Work_dir']

    nf_lookup: dict[str, list[str]] = {}
    nf_unmatched: list[list[str]] = []

    for row in nf_rows:
        # Pad to at least 4 columns
        row = row + [''] * (4 - len(row))
        task_name, nf_status, native_id, work_dir = row[:4]

        # Fallback: if work_dir is empty but native_id looks like a path
        if not work_dir and native_id.startswith('/'):
            work_dir = native_id
            native_id = 'UNKNOWN'

        key = work_key(work_dir) if work_dir else None

        if key:
            nf_lookup[key] = [task_name, nf_status, native_id, work_dir]
        else:
            nf_unmatched.append(row)

    # -----------------------------------------------------------------------
    # 2. Load the PBS log report
    # -----------------------------------------------------------------------
    log_header, log_rows = read_tsv(args.log_report)

    # Default header if absent
    if not log_header:
        log_header = [
            'Log_path', 'Exit_status', 'Service_units',
            'NCPUs_requested', 'NCPUs_used', 'CPU_time_used',
            'Memory_requested', 'Memory_used',
            'Walltime_requested', 'Walltime_used',
            'JobFS_requested', 'JobFS_used',
        ]

    # -----------------------------------------------------------------------
    # 3. Merge
    # -----------------------------------------------------------------------
    out_header = NF_COLS + log_header
    matched_rows: list[list[str]] = []
    log_unmatched: list[list[str]] = []

    matched_keys: set[str] = set()

    for row in log_rows:
        row = row + [''] * (len(log_header) - len(row))  # pad
        log_path = row[0]
        key = work_key(log_path)

        if key and key in nf_lookup:
            merged = nf_lookup[key] + row
            matched_rows.append(merged)
            matched_keys.add(key)
        else:
            log_unmatched.append(row)

    # Any NF tasks whose key never appeared in the log report
    nf_only_unmatched = [
        v for k, v in nf_lookup.items() if k not in matched_keys
    ]

    # -----------------------------------------------------------------------
    # 4. Write matched output
    # -----------------------------------------------------------------------
    out_path = Path(args.output)
    with out_path.open('w') as f:
        f.write('\t'.join(out_header) + '\n')
        for row in matched_rows:
            f.write('\t'.join(row) + '\n')

    # -----------------------------------------------------------------------
    # 5. Write unmatched rows (if any)
    # -----------------------------------------------------------------------
    unmatched_path = out_path.with_suffix('').with_name(
        out_path.stem + '.unmatched.tsv'
    )
    any_unmatched = nf_unmatched or log_unmatched or nf_only_unmatched
    if any_unmatched:
        with unmatched_path.open('w') as f:
            f.write('Source\t' + '\t'.join(out_header) + '\n')
            for row in nf_only_unmatched:
                padded = row + [''] * (len(log_header))
                f.write('NF_LOG_ONLY\t' + '\t'.join(padded) + '\n')
            for row in log_unmatched:
                padded = [''] * len(NF_COLS) + row
                f.write('LOG_REPORT_ONLY\t' + '\t'.join(padded) + '\n')
            for row in nf_unmatched:
                padded = row + [''] * len(log_header)
                f.write('NF_NO_WORKDIR\t' + '\t'.join(padded) + '\n')

    # -----------------------------------------------------------------------
    # 6. Summary
    # -----------------------------------------------------------------------
    print("=" * 52)
    print(" match_nf_logs.py — complete")
    print("=" * 52)
    print(f" Matched rows written     : {len(matched_rows)}")
    print(f" Output file              : {out_path}")
    if any_unmatched:
        total_unmatched = len(nf_only_unmatched) + len(log_unmatched) + len(nf_unmatched)
        print(f" Unmatched rows           : {total_unmatched}")
        print(f" Unmatched written to     : {unmatched_path}")
    else:
        print(" Unmatched rows           : 0")
    print("=" * 52)


if __name__ == '__main__':
    main()