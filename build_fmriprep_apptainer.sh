#!/bin/bash

sbatch <<EOF
#!/bin/bash
#SBATCH --job-name=build_fmriprep
#SBATCH --time=2:00:00
#SBATCH --nice=5
#SBATCH --output="/groups/pni/renglert/logs/build_fmriprep.out"
#SBATCH --cpus-per-task=1

echo "building container"
apptainer build ${TMPDIR}/renglert/fmriprep.sif docker://poldracklab/fmriprep:latest

echo "copying container"
cp ${TMPDIR}/renglert/fmriprep.sif /groups/pni/containers/fmriprep.sif

echo "cleaning the node"
rm ${TMPDIR}/renglert/fmriprep.sif

echo "done"
EOF
