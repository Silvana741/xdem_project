#!/usr/bin/env python3
import sys
import os
import subprocess

jobscript = sys.argv[1]

with open(jobscript) as f:
    lines = f.readlines()
    jobname = [l.split()[1] for l in lines if l.startswith("#SBATCH --job-name")][0]
    log = [l.split()[1] for l in lines if l.startswith("#SBATCH --output")][0]
    err = [l.split()[1] for l in lines if l.startswith("#SBATCH --error")][0]
    time = [l.split()[1] for l in lines if l.startswith("#SBATCH --time")][0]
    nodes = [l.split()[1] for l in lines if l.startswith("#SBATCH --nodes")][0]
    ntasks = [l.split()[1] for l in lines if l.startswith("#SBATCH --ntasks")][0]
    cpus_per_task = [l.split()[1] for l in lines if l.startswith("#SBATCH --cpus-per-task")][0]

cmd = [
    "sbatch",
    "--job-name", jobname,
    "--output", log,
    "--error", err,
    "--time", time,
    "--nodes", nodes,
    "--ntasks", ntasks,
    "--cpus-per-task", cpus_per_task
]

subprocess.check_call(cmd + [jobscript])
