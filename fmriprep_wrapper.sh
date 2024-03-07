#!/bin/bash


# Set default values
MAX_JOBS=16
NICE=5
SUBMIT_DELAY=72
CPUS_PER_TASK=15


# this is called with the -h help function
usage() {
      echo "-i      Input BIDS dataset"
      echo "-o      Derivatives dir (i.e., where to store the results)"
      echo "-a      Path to the fmriprep.sif apptainer file"
      echo "-t      Where to store temporary files on the cluster, should be in TMPDIR/yourname or /local/work"
      echo "-f      link to the freesurfer license"
      echo "-l      NFS directory that should be used to store the slurm log files "
      echo "-m      Maximum amount of jobs that you want to have running at a time (default: '${MAX_JOBS}')"
      echo "-n      Slurm nice value. The higher the nice value, the lower the priority! (default: '${NICE}')"
      echo "-d      Minimum delay between submission of jobs in seconds (default: '${SUBMIT_DELAY}')"
      echo "-c      CPU's per task (default: '${CPUS_PER_TASK}')"
}


# Parse options
while getopts "i:o:a:t:f:l:m:n:d:c:h" opt; do
  case "$opt" in
    i) INDIR="$OPTARG";;
    o) OUTDIR="$OPTARG";;
    a) CONTAINER="$OPTARG";;
    t) TMP_FMRIPREP="$OPTARG";;
    f) FREESURFER_LICENSE="$OPTARG";;
    l) LOG_PATH="$OPTARG";;
    m) MAX_JOBS="$OPTARG";;
    n) NICE="$OPTARG";;
    d) SUBMIT_DELAY="$OPTARG";;
    c) CPUS_PER_TASK="$OPTARG";;

    h) usage;;
    # catch invalid args
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1;;
    # catch missing args
    :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1;;
  esac
done

# Every sub-dataset (containing only one subject) still needs a dataset_description.json
dataset_description_path="${INDIR}/dataset_description.json"

# Create directories
mkdir -p "${LOG_PATH}"
mkdir -p "${OUTDIR}"
mkdir -p "${TMP_FMRIPREP}"/job_scripts/

# iterate over sub folders and
for participant_folder in ${INDIR}/sub-*; do
    PARTICIPANT_ID=$(basename "$participant_folder")
    job_path="${TMP_FMRIPREP}/job_scripts/job_${PARTICIPANT_ID}.sh"

    cat << EOF > "${job_path}"
#!/bin/bash
#SBATCH --job-name=${PARTICIPANT_ID}
#SBATCH --output="${LOG_PATH}/${PARTICIPANT_ID}.out"
#SBATCH --error="${LOG_PATH}/${PARTICIPANT_ID}.out"
#SBATCH --time=48:00:00
#SBATCH --nice=${NICE}
#SBATCH --cpus-per-task ${CPUS_PER_TASK}

echo "*************************************************************"
echo "Starting on \$(hostname) at \$(date +"%T")"
echo "*************************************************************"

TMP_LOCAL="/local/work/renglert/A01/${PARTICIPANT_ID}"
echo "\${TMP_LOCAL}"

# directory for single sub BIDS
participant_data_in="\${TMP_LOCAL}/input/${PARTICIPANT_ID}"
echo "\${participant_data_in}"
# dir for derivatives
participant_data_out="\${TMP_LOCAL}/output/${PARTICIPANT_ID}"
# dir for temporary files
participant_tmp="\${TMP_LOCAL}/tmp/${PARTICIPANT_ID}/"

# clear the dirs if they exist, then create them
rm -rf "\${participant_data_in}"
mkdir -p "\${participant_data_in}"
rm -rf "\${participant_data_out}"
mkdir -p "\${participant_data_out}"
rm -rf "\${participant_tmp}"
mkdir -p "\${participant_tmp}"

# copy the participant data and the description.json from the NFS to the node
cp -vr "${participant_folder}" "\${participant_data_in}"
cp -v "${dataset_description_path}" "\${participant_data_in}"

# create local copy of the freesurfer license
cp -v "${FREESURFER_LICENSE}" "\${TMP_LOCAL}/tmp/freesurfer_license.txt"

# copy the apptainer image
mkdir -p "\${TMP_LOCAL}"/apptainer_image/"${PARTICIPANT_ID}"/
cp "${CONTAINER}" "\${TMP_LOCAL}"/apptainer_image/"${PARTICIPANT_ID}"/fmriprep.sif

apptainer exec -B "\${TMP_LOCAL}":"\${TMP_LOCAL}" --writable-tmpfs "\${TMP_LOCAL}"/apptainer_image/"${PARTICIPANT_ID}"/fmriprep.sif \
	bash -c "fmriprep \${participant_data_in} \${participant_data_out} participant -w \${participant_tmp} --fs-license-file \${TMP_LOCAL}/tmp/freesurfer_license.txt"

echo "******************** PARTICIPANT INPUT TREE ****************************"
tree \${participant_data_in}
echo "***************************************************************"
echo ""
echo "******************** PARTICIPANT TMP TREE ****************************"
tree \${participant_tmp}
echo "***************************************************************"
echo ""
echo "******************** PARTICIPANT DATA OUT TREE ****************************"
tree \${participant_data_out}
echo "***********************************************************************"

# Move results to the output directory
cp -vr \${participant_data_out}/* ${OUTDIR}/

# Remove (most) files from cluster
rm -rf "\${participant_data_in}"
rm -rf "\${participant_data_out}"
rm -rf "\${participant_tmp}"
rm -rf "\${TMP_LOCAL}"


echo "*************************************************************"
echo "Ended on \$(hostname) at \$(date +"%T")"
echo "*************************************************************"

EOF

    while true; do
        job_count=$(squeue -u "$USER" -h | wc -l)

        if [ ${job_count} -lt ${MAX_JOBS} ]; then
            echo "Number of jobs (${job_count}) is below the limit (${MAX_JOBS}). Submitting job..."
            break
        else
            echo "Waiting. Current job count: ${job_count}. Limit is ${MAX_JOBS}."
            sleep 80  # Wait some time before checking again
        fi
    done

    sbatch ${job_path}
    sleep ${SUBMIT_DELAY}  # Do not spawn jobs very fast, even if the amount of jobs is not exceeding the limit

done

# clean the tmp folder on the wrapper node
rm -rf "\${TMP_FMRIPREP}"

echo "--------------------------------------------------------------------"
echo "Last job script was submitted..."
echo "--------------------------------------------------------------------"
