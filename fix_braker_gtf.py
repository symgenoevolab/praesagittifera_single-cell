#!/usr/bin/env python3
"""
Fix BRAKER/AUGUSTUS GTF files so they are accepted by `cellranger mkref`.

BRAKER writes `gene` and `transcript` lines with a bare ID in column 9, e.g.

    chr1  AUGUSTUS  gene        2618  2956  .     -  .  g1
    chr1  AUGUSTUS  transcript  2618  2956  0.96  -  .  g1.t1

This script rewrites them as proper GTF attributes:

    gene        -> gene_id "g1";
    transcript  -> gene_id "g1"; transcript_id "g1.t1";

All other lines (CDS, exon, intron, start/stop_codon, mRNA, comments, ...)
are written unchanged.

The gene_id of a transcript is taken from the transcript_id -> gene_id mapping
found on the file's other feature lines; if a transcript has no such lines,
it is derived by stripping the trailing ".tN" suffix (g1.t1 -> g1).
"""

import argparse
import gzip
import re
import sys
from collections import Counter

TX_SUFFIX = re.compile(r"\.t\d+$")
TID_RE = re.compile(r'transcript_id "([^"]+)"')
GID_RE = re.compile(r'gene_id "([^"]+)"')


def open_text(path, mode="rt"):
    if path == "-":
        return sys.stdin if "r" in mode else sys.stdout
    if path.endswith(".gz"):
        return gzip.open(path, mode)
    return open(path, mode)


def is_bare_id(attr):
    """True if column 9 is a single bare ID (no key/value pairs)."""
    attr = attr.strip()
    return bool(attr) and '"' not in attr and ";" not in attr and " " not in attr


def main():
    p = argparse.ArgumentParser(
        description="Fix bare gene/transcript IDs in BRAKER GTF files "
                    "(column 9) for cellranger mkref.",
        epilog="Example: fix_braker_gtf.py -i braker.gtf -o braker.fixed.gtf",
    )
    p.add_argument("-i", "--input", required=True,
                   help="input BRAKER GTF (.gtf or .gtf.gz; '-' for stdin)")
    p.add_argument("-o", "--output", required=True,
                   help="output fixed GTF (.gtf or .gtf.gz; '-' for stdout)")
    args = p.parse_args()

    if args.input != "-" and args.input == args.output:
        p.error("input and output must be different files")

    with open_text(args.input) as fh:
        lines = fh.readlines()

    # Pass 1: transcript_id -> gene_id from lines that already have attributes
    tx2gene = {}
    for line in lines:
        if line.startswith("#"):
            continue
        cols = line.rstrip("\n").split("\t")
        if len(cols) != 9:
            continue
        t, g = TID_RE.search(cols[8]), GID_RE.search(cols[8])
        if t and g:
            tx2gene.setdefault(t.group(1), g.group(1))

    # Pass 2: rewrite
    stats = Counter()
    out = open_text(args.output, "wt")
    try:
        for n, line in enumerate(lines, 1):
            if line.startswith("#") or not line.strip():
                out.write(line)
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) != 9:
                sys.stderr.write(f"WARNING: line {n} has {len(cols)} columns; "
                                 "written unchanged\n")
                stats["malformed"] += 1
                out.write(line)
                continue

            feature, attr = cols[2], cols[8].strip()
            if is_bare_id(attr) and feature == "gene":
                cols[8] = f'gene_id "{attr}";'
                stats["gene_fixed"] += 1
            elif is_bare_id(attr) and feature in ("transcript", "mRNA"):
                gid = tx2gene.get(attr)
                if gid is None:
                    gid = TX_SUFFIX.sub("", attr)
                    stats["gene_id_from_suffix"] += 1
                cols[8] = f'gene_id "{gid}"; transcript_id "{attr}";'
                stats[f"{feature}_fixed"] += 1
            else:
                if is_bare_id(attr):
                    sys.stderr.write(f"WARNING: line {n}: bare ID on '{feature}' "
                                     "feature; written unchanged\n")
                    stats["bare_other_unchanged"] += 1
                out.write(line)
                continue
            out.write("\t".join(cols) + "\n")
    finally:
        if out is not sys.stdout:
            out.close()

    sys.stderr.write(f"Input : {args.input}\nOutput: {args.output}\n")
    for k in ("gene_fixed", "transcript_fixed", "mRNA_fixed",
              "gene_id_from_suffix", "bare_other_unchanged", "malformed"):
        if stats[k]:
            sys.stderr.write(f"  {k}: {stats[k]}\n")


if __name__ == "__main__":
    main()
