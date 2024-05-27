This repository shows the running of XDEM Scalability tests using Snakemake as the workflow manager.
To run it in Aion cluster, you can follow the steps listed below:
- Log in in Aion cluster
- Copy the repository where the files of the project are present using the command:
'''
cp path/to/repo .
'''
- Set the number of nodes and other properties in slurm-profile/cluster.yaml file.
- Run the snakemake command with the command:
'''
snakemake --profile slurm-profile
'''
-You can see the sample of the output in sample-output folder.
