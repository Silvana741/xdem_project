
import os
from datetime import datetime
# Get current timestamp for directory names
timestamp = datetime.now().strftime("%F_%H-%M-%S")
SLURM_JOBID = os.environ.get("SLURM_JOBID", "unknown")
JOB_DIR = "/home/users/sbelegu/hpcs_project/project1-workflow_XDEM_scalability/test-run"
TESTCASE_DIR = os.path.join(JOB_DIR, "../testcases/BlastFurnaceCharging-5.5M")
XDEM_ROOT_DIR = "/path/to/XDEM"  # Adjust this to your actual XDEM root directory
XDEM_DRIVER = os.path.join(XDEM_ROOT_DIR, "bin/XDEM_Simulation_Driver")
XDEM_INPUT = os.path.join(TESTCASE_DIR, "blastFurnaceCharging-5.5M-middle-nocheckpoint.h5")

rule all:
    input:
        expand("job_{job_id}_{timestamp}_maxNN{nnodes}/output_NN{nnodes}-NC{ncores}-NP{nprocs}-NT{nthreads}-Partitioner{partitioner}/blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5",
               job_id=SLURM_JOBID, timestamp=timestamp, nnodes=nodes_array, ncores=lambda wildcards: wildcards.nnodes * 128, nprocs=lambda wildcards: (wildcards.nnodes * 128) // NT, nthreads=NT, partitioner=PARTITIONER),
        "job_{job_id}_{timestamp}_maxNN32/output_plot_strong_scalability.log".format(job_id=SLURM_JOBID, timestamp=timestamp)


rule prepare_directory:
    output:
        run_dir=directory("job_{SLURM_JOBID}_{timestamp}_maxNN{nnodes}")
    shell:
        """
        mkdir -p {output.run_dir}
        """


rule run_xdem:
    input:
        directory(run_dir="{run_dir}"),
        script="{XDEM_DRIVER}",
        input_file="{XDEM_INPUT}"
    output:
        directory(output_dir="{output_dir}"),
        log="{output_log}"
    params:
        nthreads=NT,
        partitioner=PARTITIONER
    shell:
        """
        module use /work/projects/mhpc-softenv/easybuild/aion-epyc-prod-2023a/modules/all/
        module load cae/XDEM/master-20240425-52cc25a6-foss-2023a-MPIOMP
        module load data/h5py/3.9.0-foss-2023a
        module load data/R-bundle-XDEM/20230721-foss-2023a-R-4.3.1

        export OMP_NUM_THREADS={params.nthreads}
        srun -N {config[nnodes]} -n {config[nc]} -c {params.nthreads} --cpu-bind=cores \
            {input.script} \
                {input.input_file} \
                --terminal-progress-interval 0.01 \
                --output-path {output.output_dir} \
                --MPI-partitioner {params.partitioner} \
                --allow-empty-partitions 1 \
                --max-iterations 1000 \
                --broadphase-extension-factor -1 \
            &> {output.log}
        """

rule cleanup_output:
    input:
        "results/output_NN{nn}-NC{nc}-NP{np}-NT{nt}-Partitioner{partitioner}/blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"
    output:
        "results/output_NN{nn}-NC{nc}-NP{np}-NT{nt}-Partitioner{partitioner}/cleaned_blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"
    params:
        delete_script="{JOB_DIR}/delete_all_but_workload_data.py",
        repack_script="{JOB_DIR}/h5repack_inplace.sh"
    resources:
        nodes=1,
        ntasks=1,
        cpus_per_task=1
    shell:
        """
        {params.delete_script} {input}
        {params.repack_script} {input}
        mv {input} {output}
        """

rule generate_plots:
    input:
        expand("results/output_NN{nn}-NC{nc}-NP{np}-NT{nt}-Partitioner{partitioner}/cleaned_blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5",
               nn=[1, 2, 3, 4],
               nc=[128, 256, 384, 512],
               np=[32, 64, 96, 128],
               nt=[4],
               partitioner=["ORB"])
    output:
        "results/output_plot_strong_scalability.log"
    params:
        plot_script="{JOB_DIR}/plot_strong_scalability.R"
    resources:
        nodes=1,
        ntasks=1,
        cpus_per_task=1
    shell:
        """
        PLOT_SCRIPT_ARGS=$(for N in {input} ; do echo -n "--nnodes=${{N#*NN}}:${{N##*/}} " ; done)
        {params.plot_script} $PLOT_SCRIPT_ARGS &> {output}
        """
