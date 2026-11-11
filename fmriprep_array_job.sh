#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH --time=96:00:00
#SBATCH --mem=90G

TASK_ID=${SLURM_ARRAY_TASK_ID:?"must be submitted as a slurm array job"}

PARTICIPANT_ID=$(sed -n "${TASK_ID}p" "${SUBJECT_LIST}")
if [[ -z "${PARTICIPANT_ID}" ]]; then
    echo "Error: no subject for array task ${TASK_ID} in ${SUBJECT_LIST}"
    exit 1
fi
participant_folder="${INDIR}/${PARTICIPANT_ID}"
dataset_description_path="${INDIR}/dataset_description.json"
if [[ ! -d "${participant_folder}" ]]; then
    echo "Error: subject folder not found: ${participant_folder}"
    exit 1
fi

echo "****** Task ${TASK_ID} (${PARTICIPANT_ID}) starting on $(hostname) at $(date +"%T") ******"

TMP_LOCAL="${TMP_FMRIPREP}/jobs/${PARTICIPANT_ID}"
echo "${TMP_LOCAL}"

LOG_LOCAL="${TMP_LOCAL}/fmriprep.log"
LOG_NFS="${LOG_PATH}/${PARTICIPANT_ID}.fmriprep.log"

cleanup() {
    if [[ -f "${LOG_LOCAL}" ]]; then
        cp "${LOG_LOCAL}" "${LOG_NFS}" || true
    fi
    rm -rf "${TMP_LOCAL}"
}
trap cleanup EXIT

# directory for single sub BIDS
participant_data_in="${TMP_LOCAL}/input/${PARTICIPANT_ID}"
echo "${participant_data_in}"
# dir for derivatives
participant_data_out="${TMP_LOCAL}/output/${PARTICIPANT_ID}"
# dir for temporary files
participant_tmp="${TMP_LOCAL}/tmp/${PARTICIPANT_ID}/"

# clear the dirs if they exist, then create them
rm -rf "${participant_data_in}"
mkdir -p "${participant_data_in}"
rm -rf "${participant_data_out}"
mkdir -p "${participant_data_out}"
rm -rf "${participant_tmp}"
mkdir -p "${participant_tmp}"

# copy the participant data and the description.json from the NFS to the node
rsync -a --copy-links "${participant_folder}" "${participant_data_in}"
rsync -a --copy-links "${dataset_description_path}" "${participant_data_in}"

# create local copy of the freesurfer license
cp "${FREESURFER_LICENSE}" "${TMP_LOCAL}/tmp/freesurfer_license.txt"

# Per-node container cache
SIF_CACHE_DIR="${TMP_FMRIPREP}/sif_cache"
SIF="${SIF_CACHE_DIR}/fmriprep-${REQUIRED_VERSION}.sif"
mkdir -p "${SIF_CACHE_DIR}"

(
    flock -x 200

    USE_CACHE=0
    if [[ -f "${SIF}" ]]; then
        echo "Found cached container image, verifying checksum..."
        if echo "${SIF_SHA256}  ${SIF}" | sha256sum --check --status; then
            USE_CACHE=1
            echo "Found valid cached container image that is going to be re-used for this run..."
        else
            echo "Found cached container image does not match expected hashsum and will not be used in this run..."
            rm -f "${SIF}"
        fi
    fi

    if [[ ${USE_CACHE} -eq 0 ]]; then
        echo "Copying container image to node-local cache..."
        if ! cp "${CONTAINER}" "${SIF}.tmp.$$"; then
            echo "Copying the container image failed"
            rm -f "${SIF}.tmp.$$"
            exit 1
        fi
        mv "${SIF}.tmp.$$" "${SIF}"
        echo "Verifying copied container image..."
        if ! echo "${SIF_SHA256}  ${SIF}" | sha256sum --check --status; then
            echo "ERROR: checksum of the copied container does not match and therefore gets removed and whole run canceled"
            rm -f "${SIF}"
            exit 1
        fi
    fi
) 200>"${SIF_CACHE_DIR}/.sif_cache.lock" || {
    echo "ERROR: could not stage/verify the container image on this node"
    exit 1
}

# verify the fMRIPrep version on the compute node as well
FMRIPREP_VERSION=$(apptainer exec --cleanenv "${SIF}" fmriprep --version 2>&1)
echo "fMRIPrep version: ${FMRIPREP_VERSION}"
if [[ "${FMRIPREP_VERSION}" != *"${REQUIRED_VERSION}"* ]]; then
    echo "ERROR: expected fMRIPrep ${REQUIRED_VERSION}, aborting."
    rm -rf "${TMP_LOCAL}"
    exit 1
fi

apptainer exec --cleanenv -B "${TMP_LOCAL}":"${TMP_LOCAL}" "${SIF}" \
    fmriprep "${participant_data_in}" "${participant_data_out}" participant \
    -w "${participant_tmp}" \
    --output-spaces anat func MNI152NLin2009cAsym:res-2 \
    --nthreads ${CPUS_PER_TASK} \
    --omp-nthreads 4 \
    --mem_mb 80000 \
    --fs-license-file "${TMP_LOCAL}/tmp/freesurfer_license.txt" \
    > "${TMP_LOCAL}/fmriprep.log" 2>&1

FMRIPREP_EXIT=$?
echo "fMRIPrep exit code: ${FMRIPREP_EXIT}"

# Move results to the output directory
cp -r ${participant_data_out}/* "${OUTDIR}/"

# Remove (most) files from cluster
rm -rf "${participant_data_in}"
rm -rf "${participant_data_out}"
rm -rf "${participant_tmp}"

echo "****** ${PARTICIPANT_ID} ended on $(hostname) at $(date +"%T") ******"

exit ${FMRIPREP_EXIT}