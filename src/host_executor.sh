#/bin/sh

#
# This script will initiate and control the profiling on the remote hosts.
#
# Author:   Joeri Hermans
# Date:     17 March 2016
# Version:  0.1
#

# Fetch the arguments in a human-readable format.
host_address=$1
job=$2
sampling_frequency=$3
sampling_duration=$4
enable_io=$5
output_directory=$6

# Define the root directory of the scripts
SCRIPTS_ROOT=$(pwd)"/src"

# Initiate a connection to the remote hosts and start the profiling.
ssh -tt $host_address "rm -rf profiler_$host_address && sh $SCRIPTS_ROOT/sampler.sh $host_address $sampling_frequency $sampling_duration $enable_io \"$SCRIPTS_ROOT\" \"$job\"; exit;"
# Copy all data files to the local computer.
scp -r $host_address:~/profiler_$host_address $output_directory/profiler_$host_address
