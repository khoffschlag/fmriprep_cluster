#!/bin/bash


# Set default values
PARAM1="default_value1"
PARAM2="default_value2"

usage() {
  echo "-i      Input BIDS dataset"
      echo "-o      Derivatives dir (i.e., where to store the results)"
      echo "-t      Where to store temporary PUMI workflow files on the cluster (MUST BE SOMEWHERE IN /tmp !)"
      echo "-l      NFS directory that should be used to store the Slurm log files (+ Apptainer SIF file)"
      echo "-p      PUMI pipeline you want to run (default: '${PIPELINE}')"
      echo "-r      Nipype plugin params to limit resource usage (default: '${RESOURCES}')"
      echo "-m      Maximum amount of jobs that you want to have running at a time (default: '${MAX_JOBS}')"
      echo "-n      Slurm nice value. The higher the nice value, the lower the priority! (default: '${NICE}')"
      echo "-b      Which PUMI GitHub branch to install (default: '${BRANCH}')"
      echo "-d      Minimum delay between submission of jobs in seconds (default: '${SUBMIT_DELAY}')"
      echo "-c      CPU's per task (default: '${CPUS_PER_TASK}')"
}


# Parse options
while getopts "i:o:t:l:p:r:m:n:b:d:c:h" opt; do
  case $opt in
    i) INDIR="$OPTARG";;
    o) OUTDIR="$OPTARG";;
    t) TMP_PUMI="$OPTARG";;
    l) LOG_PATH="$OPTARG";;
    p) PIPELINE="$OPTARG";;
    r) RESOURCES="$OPTARG";;
    m) MAX_JOBS="$OPTARG";;
    n) NICE="$OPTARG";;
    b) BRANCH="$OPTARG";;
    d) SUBMIT_DELAY="$OPTARG";;
    c) CPUS_PER_TASK="$OPTARG";;

    h) usage;;

    # catch invalid args
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1;;
    # catch missing args
    :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1;;
  esac
done
