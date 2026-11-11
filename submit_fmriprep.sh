#!/bin/bash

# Default parameters
MAX_JOBS=21   # max number of array tasks running at the same time
NICE=5
CPUS_PER_TASK=15
REQUIRED_VERSION="25.2.7"
SIF_SHA256="d63c20ae73f4356e8252341216f0b3263c344eed4b93d2473ea401ffb374e4f7"
# ----------

usage() {
      echo "-i      Input BIDS dataset"
      echo "-o      Derivatives dir (i.e., where to store the results)"
      echo "-a      Path to the fmriprep.sif apptainer file"
      echo "-t      Where to store temporary files on the cluster, should be in /local/work"
      echo "-f      link to the freesurfer license"
      echo "-l      NFS directory that should be used to store the slurm log files "
      echo "-m      Maximum number of jobs running at the same time (default: '${MAX_JOBS}')"
      echo "-n      Slurm nice value. The higher the nice value, the lower the priority! (default: '${NICE}')"
      echo "-c      CPU's per task (default: '${CPUS_PER_TASK}')"
}

while getopts "i:o:a:t:f:l:m:n:c:h" opt; do
  case "$opt" in
    i) INDIR="$OPTARG";;
    o) OUTDIR="$OPTARG";;
    a) CONTAINER="$OPTARG";;
    t) TMP_FMRIPREP="$OPTARG";;
    f) FREESURFER_LICENSE="$OPTARG";;
    l) LOG_PATH="$OPTARG";;
    m) MAX_JOBS="$OPTARG";;
    n) NICE="$OPTARG";;
    c) CPUS_PER_TASK="$OPTARG";;
    h) usage; exit 0;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1;;
    :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1;;
  esac
done

echo "Verifying temporary directory is in /local/work..."
if [[ "${TMP_FMRIPREP}" != /local/work/* ]]; then
    echo "Error: Temporary directory must be in /local/work/"
    echo "Current value: ${TMP_FMRIPREP}"
    echo "Please specify a path starting with /local/work/"
    exit 1
fi

# Check the container exists and is the required fMRIPrep version before submitting anything
if [[ ! -f "${CONTAINER}" ]]; then
    echo "Error: container not found: ${CONTAINER}"
    exit 1
fi
CONTAINER_VERSION=$(apptainer exec --cleanenv "${CONTAINER}" fmriprep --version 2>&1)
echo "Container reports: ${CONTAINER_VERSION}"
if [[ "${CONTAINER_VERSION}" != *"${REQUIRED_VERSION}"* ]]; then
    echo "Error: expected fMRIPrep ${REQUIRED_VERSION}, got: ${CONTAINER_VERSION}"
    exit 1
fi

mkdir -p "${LOG_PATH}"
mkdir -p "${OUTDIR}"

SUBJECT_LIST="${LOG_PATH}/subject_list_$(date +%Y%m%d_%H%M%S).txt"
find "${INDIR}" -maxdepth 1 -mindepth 1 -type d -name 'sub-*' -printf '%f\n' | sort > "${SUBJECT_LIST}"
N_SUBJECTS=$(wc -l < "${SUBJECT_LIST}")
if [[ "${N_SUBJECTS}" -eq 0 ]]; then
    echo "Error: no sub-* folders found in ${INDIR}"
    exit 1
fi
echo "Found ${N_SUBJECTS} subjects (array task N processes line N of ${SUBJECT_LIST}):"
cat "${SUBJECT_LIST}"

# Everything the array tasks need is handed over via the environment
export INDIR OUTDIR CONTAINER TMP_FMRIPREP FREESURFER_LICENSE LOG_PATH
export CPUS_PER_TASK REQUIRED_VERSION SIF_SHA256 SUBJECT_LIST

ARRAY_JOB_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fmriprep_array_job.sh"

sbatch \
    --array=1-${N_SUBJECTS}%${MAX_JOBS} \
    --nice=${NICE} \
    --cpus-per-task=${CPUS_PER_TASK} \
    --output="${LOG_PATH}/fmriprep_%A_%a.out" \
    --error="${LOG_PATH}/fmriprep_%A_%a.out" \
    --export=ALL \
    "${ARRAY_JOB_SCRIPT}"

echo "Array job submitted!"