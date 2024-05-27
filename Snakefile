
import os
from datetime import datetime
configfile: "config.yaml"
# Get current timestamp for directory names
timestamp = datetime.now().strftime("%F_%H-%M-%S")
XDEM_ROOT_DIR = config["xdem_root_dir"]
TESTCASE_DIR = os.path.join(XDEM_ROOT_DIR, config["testcase_dir"])
XDEM_DRIVER = config["xdem_driver"]
XDEM_INPUT = os.path.join(TESTCASE_DIR, config["xdem_input"])
PARTITIONER = config["partitioner"]
NT = config["nt"]
MAX_ITERATIONS = config["max_iterations"]
JOB_DIR = config["job_dir"]
NUM_NODES = config["num_nodes"]

RUN_DIR = os.path.join(JOB_DIR, f"job_{os.environ.get('SLURM_JOBID', 'test')}_{timestamp}_maxNN{NUM_NODES}")
os.makedirs(RUN_DIR, exist_ok=True)

# Rule to load modules
rule load_modules:
    run:
        shell("""
            module use /work/projects/mhpc-softenv/easybuild/aion-epyc-prod-2023a/modules/all/
            module load cae/XDEM/master-20240425-52cc25a6-foss-2023a-MPIOMP
            module load data/h5py/3.9.0-foss-2023a
            module load data/R-bundle-XDEM/20230721-foss-2023a-R-4.3.1
        """)


# Rule to run the XDEM simulations
rule run_simulations:
    input:
        RUN_DIR
    output:
        expand(os.path.join(RUN_DIR, "output_NN{nn}-NC{nc}-NP{np}-NT{nt}-Partitioner{partitioner}/blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"),
               nn=range(1, NUM_NODES + 1), nc=[lambda wildcards: int(wildcards.nn) * 128],
               np=[lambda wildcards: int(wildcards.nc) // NT], nt=[NT], partitioner=[PARTITIONER])
    run:
        for NN in range(1, NUM_NODES + 1):
            NC = NN * 128
            NP = NC // NT
            OUTPUT_TAG = f"NN{NN}-NC{NC}-NP{NP}-NT{NT}-Partitioner{PARTITIONER}"
            OUTPUT_LOG = os.path.join(RUN_DIR, f"output_{OUTPUT_TAG}.log")
            OUTPUT_DIR = os.path.join(RUN_DIR, f"output_{OUTPUT_TAG}")

            shell(f"""
                export OMP_NUM_THREADS={NT}
                srun -N {NN} -n {NP} -c {NT} --cpu-bind=cores \
                    {XDEM_DRIVER} {XDEM_INPUT} \
                    --terminal-progress-interval 0.01 \
                    --output-path {OUTPUT_DIR} \
                    --MPI-partitioner {PARTITIONER} \
                    --allow-empty-partitions 1 \
                    --max-iterations {MAX_ITERATIONS} \
                    --broadphase-extension-factor -1 \
                    &> {OUTPUT_LOG}
            """)


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

# Define the order of execution
rule all:
    input:
        expand(os.path.join(RUN_DIR, "output_plot_strong_scalability.log"))