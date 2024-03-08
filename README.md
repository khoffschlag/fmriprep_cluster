# Running fmriprep on the cluster
The goal of this document is to help you understand how to run fmriprep on the IKIM cluster!

### Important cluster considerations:
- Everything should now be run through Slurm
- the IO traffic, so communication between the nodes and the NFS, should be kept minimal
- working directories should be in /local/work or $TMPDIR (i.e. /local/work/renglert/)
- NOTHING should be stored in /tmp!
- make sure to not overcrowd the nodes with residual data

### Overall structure
- the fmriprep_wrapper.sh script manages the distribution of the participants to the nodes
- another script that submits the fmriprep_wrapper.sh to slurm is recommended (see "run_fmriprep_A01.sh")
- the preprocessing of all participants is parallelized only across participants, so 1 job = 1 participant
- one node will be occupied for the fmriprep_wrapper.sh, so 9 jobs equals 8 participants simultaneously
- for each participant, the raw data and the container will be copied to the node, the outputs will be stored locally
- after completion, the outputs (derivatives) will be copied to the nfs and the remaining data will be deleted

### Details
**The basic outline of the "for loop" to submit the jobs:**

Iterate over the participants in the NFS folder:
- copy the container to the node
- copy the target participant into a BIDS compatible format (incl. description.json)
- run the actual analysis, and
    - write the temp files locally
    - output the derivatives locally
- when the analysis is complete, copy the derivatives back to the NFS
- delete everything else (temp files, docker container, single-sub BIDS folder)

The folder structure on the individual nodes will look like this:
```
/local/work/renglert/A01/
└───sub-XXXXXXXXX
│   └───input
│       └───sub-XXXXXXXXX
│           dataset_description.json
│           └───sub-XXXXXXXXX
│   └───output
│       │   ...
│   └───tmp
│       │   ...
└───sub-YYYYYYYYY
│   └───input
│       └───sub-YYYYYYYYY
│   │       │   ...
    .
    .
    .
```
This structure is chosen, so that parallel runs on the same node do not interfere with each other! The outer folder
sub-XXXXXXXXX will be deleted once the preprocessing and the data migration to the nfs is complete.

To handle an upper limit of jobs, so i.e. only 8 simultaneously, we submit the jobs with a while loop in the
participant level for loop. For this we just check the amount of jobs our $USER has currently running, compare that
to the MAX JOBS and either submit a new job (=participant), or we just wait a specific amount and check again, until
all participants are done.

There are two types of log files currently created:
- one automatically named, next to the slurm script which contains the logs of the wrapper that distributes the jobs
- logs for each participant, stored in the provided folder. This holds the logs on the actual analysis pipeline


### Things to note:
- only cancel the job that manages the jobs, if the individual jobs die, they at least delete most of the data

- when trying to access a specific node through slurm to clean up some data for example, you can run the following:
```
$ srun --time 01:00:00 -w c57 --pty bash -i
```
- this requests access to c57 for 1 hour, and it automatically starts an interactive terminal

- take care of using variables! When using variables inside the for loop, make sure to use "\\" so that it is not
immediately evaluated when starting the script, but only in-line

- apptainer automatically binds $HOME and /scratch, this does not work on the cluster, that's why we have to manually
bind the temporary working directory
