#!/bin/bash -l
#SBATCH -J XDEMScalability
#SBATCH --time=0-2:00:00
#SBATCH -N 8
#SBATCH -n 1024
#SBATCH -c 1
#SBATCH --hint=nomultithread
#SBATCH --exclusive
#SBATCH --partition batch
#SBATCH --qos normal
#SBATCH --output SLURM_%x_%j.log
#SBATCH --error SLURM_%x_%j.log
#SBATCH --chdir=/work/projects/mhpc-softenv/project1-workflow_XDEM_scalability/test-run

echo "== Starting run at $(date)"
echo "== Job ID: ${SLURM_JOBID}"
echo "== Node list: ${SLURM_NODELIST}"
echo "== Submit dir. : ${SLURM_SUBMIT_DIR}"

# Output directory
JOB_DIR="${PWD}"
RUN_DIR="${PWD}/job_${SLURM_JOBID}_$(date '+%F_%H-%M-%S')_maxNN${SLURM_NNODES}"
mkdir -p "${RUN_DIR}"
cd "${RUN_DIR}"

# XDEM environment and settings
module use /work/projects/mhpc-softenv/easybuild/aion-epyc-prod-2023a/modules/all/
module load cae/XDEM/master-20240425-52cc25a6-foss-2023a-MPIOMP   # for XDEM
module load data/h5py/3.9.0-foss-2023a                            # for clean script
module load data/R-bundle-XDEM/20230721-foss-2023a-R-4.3.1        # for plot script

# Testcase settings
TESTCASE_DIR="${JOB_DIR}/../testcases/BlastFurnaceCharging-5.5M"

# Set XDEM settings
XDEM_DRIVER="${XDEM_ROOT_DIR}/bin/XDEM_Simulation_Driver"
XDEM_INPUT="${TESTCASE_DIR}/blastFurnaceCharging-5.5M-middle-nocheckpoint.h5"
PARTITIONER="ORB"  # Partitioner: ORB Zoltan-RCB Zoltan-RIB METIS SCOTCH
NT=4               # Number of threads per process

for NN in $(seq 1 ${SLURM_NNODES}) ; do

    # NT -> number of threads, NN -> number of nodes, NP -> number of processes, NC -> number of cores
    NC=$(( $NN * 128 ))
    NP=$(( $NC / $NT ))

    echo "[$(date)] Run XDEM on $NC cores on $NN nodes , with $NP MPI processes and $NT OpenMP threads, with $PARTITIONER partitioner"

    OUTPUT_TAG="NN${NN}-NC${NC}-NP${NP}-NT${NT}-Partitioner${PARTITIONER}"
    OUTPUT_LOG="${RUN_DIR}/output_${OUTPUT_TAG}.log"
    OUTPUT_DIR="${RUN_DIR}/output_${OUTPUT_TAG}"

    # Run XDEM simulation in parallel
    export OMP_NUM_THREADS=$NT
    srun -N "$NN" -n "$NP" -c "$NT" --cpu-bind=cores \
    	"${XDEM_DRIVER}" \
            "${XDEM_INPUT}" \
            --terminal-progress-interval 0.01 \
            --output-path "${OUTPUT_DIR}" \
            --MPI-partitioner "${PARTITIONER}" \
            --allow-empty-partitions 1 \
            --max-iterations 1000 \
            --broadphase-extension-factor -1 \
        &> "${OUTPUT_LOG}"

    # Remove unneeded output files
    find "${OUTPUT_DIR}" \( -name '*.xdmf' -o -name '*_rank-*.*' -o -name '*.dat' \) -delete

    # Cleanup output file
    OUTPUT_FILE="${OUTPUT_DIR}/blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"
    "${JOB_DIR}/delete_all_but_workload_data.py" "${OUTPUT_FILE}"
    "${JOB_DIR}/h5repack_inplace.sh"             "${OUTPUT_FILE}"
done

# Generate strong scalability plots
PLOT_LOG="${RUN_DIR}/output_plot_strong_scalability.log"
PLOT_SCRIPT_ARGS=$(for N in $(seq 1 8) ; do echo -n "--nnodes=$N:$(ls output_NN$N-*/blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5) " ; done)
echo "PLOT_SCRIPT_ARGS = ${PLOT_SCRIPT_ARGS}"
"${JOB_DIR}/plot_strong_scalability.R" ${PLOT_SCRIPT_ARGS} &> "${PLOT_LOG}"

echo "== Job end at $(date)!"

