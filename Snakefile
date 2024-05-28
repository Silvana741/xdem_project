configfile: "config.yaml"

def format_output_log(config):
    log_path = config["output_log"].format(nn=config["nn"], nc=config["nc"], np=config["np"], nt=config["nt"], par=config["partitioner"])
    print(f"Formatted output log path: {log_path}")  # Debugging statement
    return log_path
        
rule run_xdem_driver:
    input:
        xdem_input=config["xdem_input"]
    output:
        log=format_output_log(config),
        results="output/blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"
    params:
        nt=config["nt"],
        nn=config["nn"],
        np=config["np"],
        output_dir=config["output_dir"],
        partitioner=config["partitioner"],
        max_iterations=config["max_iterations"],
        xdem_driver=config["xdem_driver"]
    shell:
        """
        module use /work/projects/mhpc-softenv/easybuild/aion-epyc-prod-2023a/modules/all/
        module load cae/XDEM/master-20240425-52cc25a6-foss-2023a-MPIOMP
        module load data/h5py/3.9.0-foss-2023a
        module load data/R-bundle-XDEM/20230721-foss-2023a-R-4.3.1
        export OMP_NUM_THREADS={params.nt}
        srun -N {params.nn} -n {params.np} -c {params.nt} --cpu-bind=cores \
            {params.xdem_driver} {input.xdem_input} \
            --terminal-progress-interval 0.01 \
            --output-path {params.output_dir} \
            --MPI-partitioner {params.partitioner} \
            --allow-empty-partitions 1 \
            --max-iterations {params.max_iterations} \
            --broadphase-extension-factor -1 \
            &> {output.log}
        """

rule cleanup_output:
    input:
        path=format_output_log(config)
    output:
        cleaned_results="output/cleaned_blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"
    params:
        delete_script="scripts/delete_all_but_workload_data.py",
        repack_script="scripts/h5repack_inplace.sh"
    shell:
        """
        set -euo pipefail  # Enable strict mode and exit on error
        
        echo "Cleaning up output files..."
        find "output" \( -name '*.xdmf' -o -name '*_rank-*.*' -o -name '*.dat' \) -delete
        echo "Deleted intermediate files."

        input_file="output/blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"
        echo "Running delete script on input_file..."
        {params.delete_script} $input_file
        echo "Delete script finished."

        echo "Running repack script on input_file..."
        {params.repack_script} $input_file
        echo "Repack script finished."

        echo "Copying cleaned file to output directory..."
        cp $input_file {output.cleaned_results}
        echo "File copied to {output.cleaned_results}."
        """

rule generate_plots:
    input:
        "output/cleaned_blastFurnaceCharging-5.5M-middle-nocheckpoint_allranks.h5"
    output:
        "output_plot_strong_scalability.log"
    params:
        plot_script="scripts/plot_strong_scalability.R"
    shell:
        """
        PLOT_SCRIPT_ARGS={input}
        {params.plot_script} $PLOT_SCRIPT_ARGS &> {output}
        """


