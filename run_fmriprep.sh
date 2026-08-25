#!/bin/bash

# Get username automatically
USERNAME=$(whoami)

# Adjustable paths - modify these as needed
DATASET_PATH="/groups/pni/${USERNAME}/Attractor/INDI_Lite_BIDS/"  # Path to input dataset
CONTAINER_PATH="/groups/pni/containers/fmriprep.sif"  # Path to apptainer fMRIPrep image
LICENSE_PATH="./license.txt"  # Path to FreeSurfer license
LOG_DIR="./logs/"  # Path to directory where logs should be saved to
WORK_DIR="/local/work/${USERNAME}_fmriprep_dir/"  # Specify where on the cluster nodes the fMRIPrep working dir should be placed

# Set maximum number of concurrent jobs
MAX_JOBS=21

# Set output directory (adjustable)
OUTPUT_DIR="${DATASET_PATH}/derivatives/fmriprep_desc-AnatAndFuncAndMNI152NLin2009cAsym2mm_all_tasks/"

# Check if container image exists
if [ ! -f "${CONTAINER_PATH}" ]; then
    echo "Error: fMRIPrep container image not found at ${CONTAINER_PATH}"
    echo "Please check the path or build the container first."
    exit 1
fi

# Check if license file exists
if [ ! -f "${LICENSE_PATH}" ]; then
    echo "Error: FreeSurfer license file not found at ${LICENSE_PATH}"
    echo "Please ensure license.txt is in the specified directory."
    echo "If you don't have a FreeSurfer license yet, register at https://surfer.nmr.mgh.harvard.edu/registration.html to get one via email."
    exit 1
fi

# Check if dataset path exists
if [ ! -d "${DATASET_PATH}" ]; then
    echo "Error: Dataset directory not found at ${DATASET_PATH}"
    echo "Please check the dataset path."
    exit 1
fi

echo "Work directory set to: ${WORK_DIR}"
echo "Verifying work directory is in /local..."
if [[ "${WORK_DIR}" == /local/* ]]; then
    echo "Work directory is correctly in /local"
else
    echo "Error: Work directory is NOT in /local"
    exit 1
fi

# Create necessary directories if they don't exist
mkdir -p ${LOG_DIR}

# Submit the job
sbatch ./fmriprep_wrapper.sh \
-i ${DATASET_PATH} \
-o ${OUTPUT_DIR} \
-a ${CONTAINER_PATH} \
-m ${MAX_JOBS} \
-t ${WORK_DIR} \
-f ${LICENSE_PATH} \
-l ${LOG_DIR}