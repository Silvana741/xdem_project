### Workflow for Scalability Studies of XDEM Software (HPC Software Environment Course Project)
This project focuses on developing workflows to simplify and automate scalability studies of the XDEM (eXtended Discrete Element Method) software on High-Performance Computing (HPC) platforms. The XDEM framework simulates granular materials using the Discrete Element Method coupled with Computational Fluid Dynamics, and it is continuously evolving. The primary goal here is to track and evaluate the impact of code changes on simulation performance.

#### Objectives
The main objectives of this project are:

* Conducting scalability studies of XDEM manually.
* Generating performance plots to visualize scalability.
* Automating the scalability study process with Snakemake workflow manager.

#### Tools and Languages
The following tools and languages are utilized in this project:

* Snakemake: A workload manager used for job scheduling on HPC clusters.
* Bash script: Used for scripting tasks and automating processes.
* R (tidyverse and ggplot2): R will be used for data analysis and generating performance plots. The tidyverse and ggplot2 packages will aid in data manipulation and visualization.

#### Repository Structure
This repository is organized as follows:
* sample_output - log files generated for each node, plots 
* slurm_profile - Configuration scripts for cluster parameter used by Snakemake file
* README.md - Documentation
* run_scalability - sample of the batch script that was converted into Snakemake workflow
* Snakefile - the main file controlling the workflow
* config.yaml - the file with the configurations of Snakemake 


#### Getting Started
To run it in Aion cluster, you can follow the steps listed below:
- Log in to Aion cluster and clone this repository 
- Open an interactive job using si
- Load Snakemake module:
```
module use /work/projects/dlsm-soft/easybuild/modules/all/
module load tools/snakemake/8.9.0-foss-2023a
```
- Copy the directory where the files of the project are present using the command:
```
cp /work/projects/mhpc-softenv/project1-workflow_XDEM_scalability .
```
- Set the number of nodes and other properties in slurm-profile/cluster.yaml file.
- Run the snakemake command with the command:
```
snakemake --profile slurm_profile
```
-You can see monitor the jobs that are submitted using ```squeue -u $(whoami)```. The output must resemble the sample of the output in sample-output folder.

#### Contact
For any questions or inquiries regarding this project, feel free to contact Silvana Belegu at silvana.belegu@student.uni.lu 

#### Acknowledgments
We thank Professor Xavier Besseron for providing the resources and support for this project. You can find some of the resources in the links below:
- XDEM Software (https://luxdem.uni.lu/software/index.html)
- Scalability Studies (https://hpc-wiki.info/hpc/Scaling)
- Performance comparison and regression for XDEM (https://www.youtube.com/watch?v=TbCb5F7GfWQ)

This README is part of the Workflow for Scalability Studies of XDEM Software project and is subject to change as the project progresses.