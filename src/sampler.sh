
#/bin/sh

#
# Executor of the sampler. This script will initiate local sampling. First, it will search
# for all available processes specified by the user. It will profile these jobs with the
# specified parameters, and then aggregate them for a first time on host level.
#
# Author:   Joeri Hermans
# Date:     17 March 2016
# Version:  0.1
#
# This script is partially based on the on provided by Brendan Gregg.
# Thanks, without you my project would have been a lot harder :)
#

## BEGIN Scripts constants. ####################################################

JAVA_HOME=/usr/lib/jvm/jdk1.8.0_60

## END Scripts constants. ######################################################

# Fetch all the parameters in a human-readable format.
host_address=$1
sampling_frequency=$2
sampling_duration=$3
enable_io=$4
scripts_root=$5
job=$6

# Create a directory for the profiler and move into it.
rm -rf profiler_$host_address/*
rm -rf profiler_$host_address
mkdir profiler_$host_address
cd profiler_$host_address

# Figure out where the perf Java agent files are.
AGENT_OUT=""
AGENT_JAR=""
# First, figure out where the Java agent JAR is located.
if [[ -e $scripts_root/perf-map-agent/out/attach-main.jar ]]; then
    AGENT_JAR=$scripts_root/perf-map-agent/out/attach-main.jar
elif [[ -e $scripts_root/perf-map-agent/attach-main.jar ]]; then
    AGENT_JAR=$scripts_root/perf-map-agent/attach-main.jar
fi
# Finally, retrieve the location of the perfmap library for Java mappings.
if [[ -e $scripts_root/perf-map-agent/out/libperfmap.so ]]; then
    AGENT_OUT=$scripts_root/perf-map-agent/out
elif [[ -e $scripts_root/perf-map-agent/libperfmap.so ]]; then
    AGENT_OUT=$scripts_root/perf-map-agent
fi

# Check if the Java agent and the mapping library could be found.
if [[ "$AGENT_OUT" == "" || "$AGENT_JAR" == "" ]]; then
    echo "ERROR: Missing perf-map-agent files. Check installation."
    exit 1
fi

# Fetch the PID's of the mappers.
pids=$(ps aux | grep -v std | grep -v container-executor | grep -v pts | $job | awk '{print $2}')
# pids=$(ps aux | grep jhermans | grep -v root | $job | awk '{print $2}')

# Check if pids are availabl.
if [[ -z $pids ]]; then
    echo "ERROR: No PIDs available on $host"
    exit 1
fi

# Process all PIDs in parallel.
while IFS= read -r line;
do
    pid=$(echo $line)
    mkdir $pid
    cd $pid
    # Store the current directory for future reference.
    current_dir=$(pwd -P)
    # Build the Java system table mapping command.
    cmd="cd $AGENT_OUT; $JAVA_HOME/bin/java -Xms32m -Xmx128m -cp $AGENT_JAR:$JAVA_HOME/lib/tools.jar net.virtualvoid.perf.AttachOnce $pid"
    # Check if we're allowed to attach to the process.
    user=$(ps ho user -p $pid)
    if [[ "$user" != root ]]; then
        if [[ "$user" == [0-9]* ]]; then
            user=$(awk -F: '$3 == '$user' { print $1 }' /etc/passwd);
        fi
        cmd="su - $user -c \"$cmd\""
    fi
    # Check if th mapfile exists, and remove it if this is the case.
    mapfile=/tmp/perf-$pid.map
    [[ -e $mapfile ]] && rm $mapfile
    # Check if I/O sampling needs to be performed.
    if [[ $enable_io == true ]]; then
        perf record --call-graph=fp -F $sampling_frequency -a -g -p $pid \
             -e 'sched:sched_switch' \
             -e 'sched:sched_stat_sleep' \
             -e 'sched:sched_stat_blocked' -o perf.data.raw -- sleep $sampling_duration &&
        perf inject -i -s perf.data.raw -o perf.data &&
        $(eval $cmd) &&
        chown root $mapfile &&
        chmod 666 $mapfile &&
        cp $mapfile $current_dir/ &&
        cd $current_dir && perf script -f comm,pid,tid,cpu,time,event,ip,sym,dso,trace -i perf.data | \
            $scripts_root/flamegraph/stackcollapse-perf.pl > stackcollapse.data 2>&1 &
    else
        perf record -F $sampling_frequency -o perf.data -a -g -p $pid -- sleep $sampling_duration &&
        $(eval $cmd) &&
        chown root $mapfile &&
        chmod 666 $mapfile &&
        cp $mapfile $current_dir/ &&
        cd $current_dir && perf script | $scripts_root/flamegraph/stackcollapse-perf.pl > stackcollapse.data 2>&1 &
    fi
    # Go back to the top folder.
    cd $current_dir
    cd ..
done <<< "$pids"

# Wait for the background profiling jobs to finish.
wait

# Aggregate on host-level.
rm -rf aggregated
mkdir aggregated

destination_file=aggregated/stackcollapse.data
data_files=""

current_dir=$(pwd -P)
while IFS= read -r line;
do
    pid=$(echo $line)
    data_files="$data_files $current_dir/$pid/stackcollapse.data"
done <<< "$pids"

# Aggregate all data files.
python $scripts_root/stack_aggregation.py $destination_file $data_files

# Set the default coloring method of the flamegraph, in the other case, set the io color.
if [[ $enable_io == true ]]; then
    color=io
else
    color=java
fi

# Aggreate stackcollapse data to a flamegraph on host level.
cat aggregated/stackcollapse.data | $scripts_root/flamegraph/flamegraph.pl --color=$color --hash > aggregated/flamegraph.svg
