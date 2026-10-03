#!/bin/bash
#SBATCH --job-name=build_fmriprep_25.2.6
#SBATCH --partition=cpu_nodes
#SBATCH --time=5:00:00
#SBATCH --nice=5
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G

# Builds a PINNED fMRIPrep 25.2.6 container,
# stored under a versioned file name so it never overwrites the group's existing fmriprep.sif.

set -euo pipefail

IMAGE="docker://nipreps/fmriprep:25.2.6"

# Get username automatically
USERNAME=$(whoami)

# Set adjustable paths
WORK_DIR="/local/work/${USERNAME}_fmriprep_build_25.2.6"
CONTAINER_DEST="/groups/pni/containers"  # If you are not part of the PNI group, then you need to adjust
SIF_NAME="fmriprep-25.2.6.sif"

mkdir -p "${WORK_DIR}"

# Do not silently overwrite an existing container
if [[ -e "${CONTAINER_DEST}/${SIF_NAME}" ]]; then
    echo "ERROR: ${CONTAINER_DEST}/${SIF_NAME} already exists. Remove it first if you want to rebuild."
    exit 1
fi

echo "Building container from ${IMAGE}"
apptainer build "${WORK_DIR}/${SIF_NAME}" "${IMAGE}"

echo "Copying container"
cp "${WORK_DIR}/${SIF_NAME}" "${CONTAINER_DEST}/${SIF_NAME}"

# Record a checksum so you can later confirm every job used the identical image
sha256sum "${CONTAINER_DEST}/${SIF_NAME}" | tee "${CONTAINER_DEST}/${SIF_NAME}.sha256"

echo "Cleaning the node"
rm -rf "${WORK_DIR}"

echo "Done: ${CONTAINER_DEST}/${SIF_NAME}"
