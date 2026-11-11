#!/bin/bash

# Get username automatically
USERNAME=$(whoami)

# Adjustable paths - modify these as needed
DATASET_PATH="/groups/pni/${USERNAME}/Attractor/INDI_Lite_BIDS"  # Path to input dataset (no trailing slash)
CONTAINER_PATH="/groups/pni/containers/fmriprep-25.2.7.sif"
LICENSE_PATH="./license.txt"                                    # Path to FreeSurfer license
LOG_DIR="./logs_fmriprep-25.2.7/"                          # Separate logs from earlier fMRIPrep runs
WORK_DIR="/local/work/${USERNAME}_fmriprep-25.2.7/"        # Working dir on the cluster nodes (must be in /local)

# Set maximum number of concurrent jobs
MAX_JOBS=69

# Set output directory (NEW directory - never mix with derivatives from other fMRIPrep versions)
OUTPUT_DIR="${DATASET_PATH}/derivatives/fmriprep-25.2.7_desc-onlyRest/"

# Set to 1 only if you deliberately want to continue into an existing, non-empty output directory
ALLOW_EXISTING_OUTPUT=0

# Resolve relative paths to absolute ones, because the generated job scripts
# run later on other nodes and must not depend on the current working directory
LICENSE_PATH=$(realpath -m "${LICENSE_PATH}")
LOG_DIR=$(realpath -m "${LOG_DIR}")/

# Check if container image exists
if [ ! -f "${CONTAINER_PATH}" ]; then
    echo "Error: fMRIPrep container image not found at ${CONTAINER_PATH}"
    echo "Please check the path or build the container first."
    exit 1
fi

# Verify the container checksum, if the build script recorded one
if [ -f "${CONTAINER_PATH}.sha256" ]; then
    echo "Verifying container checksum..."
    if ! sha256sum --check --status "${CONTAINER_PATH}.sha256"; then
        echo "Error: checksum of ${CONTAINER_PATH} does not match ${CONTAINER_PATH}.sha256"
        exit 1
    fi
    echo "Checksum OK"
else
    echo "Warning: no checksum file found at ${CONTAINER_PATH}.sha256 - skipping checksum verification"
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

# Protect against mixing with existing derivatives
if [ -d "${OUTPUT_DIR}" ] && [ -n "$(ls -A "${OUTPUT_DIR}" 2>/dev/null)" ]; then
    if [ "${ALLOW_EXISTING_OUTPUT}" -ne 1 ]; then
        echo "Error: output directory ${OUTPUT_DIR} already exists and is not empty."
        echo "Use a new directory, or set ALLOW_EXISTING_OUTPUT=1 if this is intentional (e.g. rerunning failed subjects)."
        exit 1
    fi
    echo "Warning: writing into existing output directory ${OUTPUT_DIR}"
fi

echo "Work directory set to: ${WORK_DIR}"
echo "Verifying work directory is in /local/work..."
if [[ "${WORK_DIR}" == /local/work/* ]]; then
    echo "Work directory is correctly in /local/work"
else
    echo "Error: Work directory is NOT in /local/work"
    exit 1
fi

# Create necessary directories if they don't exist
mkdir -p "${LOG_DIR}"

echo "Submitting fMRIPrep with:"
echo "  dataset:   ${DATASET_PATH}"
echo "  output:    ${OUTPUT_DIR}"
echo "  container: ${CONTAINER_PATH}"
echo "  logs:      ${LOG_DIR}"

# Submit the job
./submit_fmriprep.sh \
    -i "${DATASET_PATH}" \
    -o "${OUTPUT_DIR}" \
    -a "${CONTAINER_PATH}" \
    -m "${MAX_JOBS}" \
    -t "${WORK_DIR}" \
    -f "${LICENSE_PATH}" \
    -l "${LOG_DIR}"
