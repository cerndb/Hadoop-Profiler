#/bin/sh

#
# Entry point of hprofiler (Hadoop Profiler).
#
# Author:   Joeri Hermans
# Version:  0.1
# Since:    17 March 2016
#

## BEGIN Functions. ####################################################

function usage {
    cat <<-END >&2
    hprofiler 0.1.0

    Basic usage:
      ./hprofiler -j [job id]         Target a specific hadoop Job on the cluster.
      ./hprofiler -h [hosts]          Target specific hosts running YARN containers.
      ./hprofiler -r                  Remove all old files.

    Options:
      -f [Hz]    sampling frequency   Sets the sampling frequency of the profiler, default 99.
      -t [s]     sampling duration    Sets the sampling during when sampling a mapper, default 5 seconds.
      -c [url]   cluster address      YARN REST API address.
      -i         I/O                  Profile context switches to identify I/O methods.
      -o [dir]   output directory
      -d         detect anomalies     Identifies nodes which are inheritly different from the majority.
      -e         extract Hadoop       Aggregates the FlameGraphs in such a way that only the Hadoop part is visualized.
END
    exit
}

## END Functions. ######################################################

# Initialize the default profiling parameters.
sampling_duration=5
sampling_frequency=99

job=""
hosts=""
num_hosts=0
cluster=""
enable_io=false
extract_hadoop=false
detect_anomalies=false
output_directory=.

# Parse the arguments specified by the user.
while getopts "o:j:h:f:t:c:irde" opt; do
    case ${opt} in
        j)
            job=${OPTARG}
            ;;
        h)
            IFS=',' read -ra hosts <<< "${OPTARG}"
            num_hosts=${#hosts[@]}
            ;;
        f)
            sampling_frequency=${OPTARG}
            ;;
        o)
            output_directory=${OPTARG}
            ;;
        t)
            sampling_duration=${OPTARG}
            ;;
        c)
            cluster=${OPTARG}
            ;;
        d)
            detect_anomalies=true
            ;;
        i)
            enable_io=true
            ;;
        r)
            rm -rf profiler_*
            rm -rf aggregated
            exit 0
            ;;
        e)
            extract_hadoop=true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# Clean up the old mess first :)
rm -rf profiler_*
rm -rf aggregated

# Check if a job identifier has been specified.
if [[ -z $job ]]; then
    echo "No selector has been specified (-j)."
    echo ""
    usage
    exit 1
fi

# Check if a sufficient number of hosts has been specified, else
# fetch the cluster nodes from YARN.
if [[ -z $hosts ]]; then
    # Check if a YARN address has been specified.
    if [[ -z $cluster ]]; then
        echo "YARN REST API has not been specified."
        exit 1
    fi
    output=$(python2 src/fetch_yarn_nodes.py $cluster $job)
    IFS="," read -ra hosts <<< "$output"
    num_hosts=${#hosts[@]}
    # Check if a sufficient number has been fetched from YARN.
    if [[ $num_hosts -eq 0 ]]; then
        echo "No nodes could be fetched from YARN with the specified parameters."
        exit 1
    fi
fi

# Create the output director for the background processes.
rm -rf $output_directory
mkdir $output_directory

# Iterate through all acquired hosts.
for i in "${hosts[@]}"
do
    bash -c "sh src/host_executor.sh $i \"$job\" $sampling_frequency $sampling_duration $enable_io $output_directory" &
done

# Wait for host processes to finish.
wait

# Prepare for file aggregation.
current_directory=$(pwd -P)
cd $output_directory
rm -rf aggregated
mkdir aggregated
destination_file=aggregated/stackcollapse.data
data_files=$(ls profiler_*/*/stackcollapse.data | tr "\n" " ")
python2 $current_directory/src/stack_aggregation.py $destination_file $data_files
cat aggregated/stackcollapse.data | $current_directory/src/flamegraph/flamegraph.pl --color=java --hash > aggregated/flamegraph.svg
# Clear the empty directories.
find profiler_* -type d -empty -delete

if [[ $enable_io == true ]]; then
    countname=ns
    color=io
else
    countname=samples
    color=java
fi

# Check if the Hadoop extraction needs to be done.
if [[ $extract_hadoop == true ]]; then
    # Move into the aggregated folder.
    cd aggregated
    # Filter out non Hadoop related information.
    cat stackcollapse.data | grep JavaThread::run | sed -r 's/^.{29}//' > stackcollapse_hadoop.data
    # Generate the associated FlameGraph.
    cat stackcollapse_hadoop.data | $current_directory/src/flamegraph/flamegraph.pl --countname=$countname --colors=$color --hash > aggregated/flamegraph_hadoop.svg
    # Move back to the upper folder.
    cd ..
fi
# Go back to the entry point.
cd ..

# Check if anomalies need to be detected.
if [[ $detect_anomalies == true ]]; then
    echo "Detecting anomalies..."
    echo "Listing anomalies:"
    echo "------------------"
    # Fetch the absolute directory of the results folder.
    # Execute the outlier detection script.
    python2 $current_directory/src/outlier_detection.py $output_directory
    # Identifying the majority and anomily sets.
    echo "------------------"
    echo "Done"
fi
