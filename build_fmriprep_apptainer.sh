#!/bin/bash
#SBATCH --job-name=build_fmriprep
#SBATCH --partition=cpu_nodes
#SBATCH --time=5:00:00
#SBATCH --nice=5
#SBATCH --cpus-per-task=1

# Get username automatically
USERNAME=$(whoami)

# Set adjustable paths
WORK_DIR="/local/work/${USERNAME}_fmriprep_build"
CONTAINER_DEST="/groups/pni/containers"  # If you are not part of the PNI group, then you need to adjust

# Create working directory
mkdir -p ${WORK_DIR}

echo "Building container"
apptainer build ${WORK_DIR}/fmriprep.sif docker://poldracklab/fmriprep:latest

echo "Copying container"
cp ${WORK_DIR}/fmriprep.sif ${CONTAINER_DEST}/fmriprep.sif

echo "Cleaning the node"
rm ${WORK_DIR}/fmriprep.sif

echo "Done"