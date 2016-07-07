# How can you use hprofiler to profile your (distributed) applications?

Currently, hprofiler requires root permissions, so if you are running this on your cluster be sure that you have access to the root account. Furthermore, since hprofiler relies on SSH connections, it could be of use to share the SSH keys between the machines. However, CERN users do not need to worry about this, since Keberos handles this for them. HProfiler is currently available on GitHub (link is external) (for CERN users also available on AFS).

In order to profile a certain distributed application, one needs to devise a selector. A selector is a pipe of, e.g., grep's in order to filter out the required PID's from ps -elf. Let's say that we have a Hadoop job with the name application_123456789. Using the information, we can construct the selector "grep 123456789 | grep -v root". This enables hprofiler to search on the cluster for the related PID's in order to start the profiling process. Note that we omit "application_", since Hadoop uses different prefixes for it's mappers. Furthermore, more complex selectors are possible as well (e.g., for non-Hadoop applications) by adding more grep commands to the pipe.

Once a user constructed a selector which is able to resolve the correct PID's, one needs to run the sampling frequency, sampling duration, and the hosts he or she wants to profile. One could also specify the YARN cluster address. Hprofiler would then automatically fetch the cluster nodes and initiate SSH connections to them in order to determine if PID's related to the user-provided selector are available and thus marking a host as "in use". Taking the example from above, running hprofiler could be as simple as this:

`sh hprofiler.sh -f 300 -t 60 -c [cluster address] -j "grep 123456789" -o results`

This command will sample the PID's obtained with the selector with a frequency of 300 Hz for 60 seconds. When the profiler is done sampling the program stacks, it will aggregate them, build a FlameGraph and put the results of all host in the results folder. Finally, it will do a final aggregation on a cluster level, in order to provide the user with a "cluster average" utilisation. However, in order to profile an application, one needs to add some JVM flags in order to enable stack walking on the JVM (-XX:+PreserveFramePointer -XX:MaxInlineSize=0), as discussed in the "Hadoop Profiler" section above.

The [cluster address] option in the example above is actually the URI of the nodes API provided by the YARN Resource Manager. A more complete example of a command which makes use of this option is shown below.

`sh hprofiler.sh ... -c http://[host]:[port]/ws/v1/cluster/nodes ...`

In contrast to specifying the address of the YARN Resource Manager which is used to fetch the cluster nodes, one can also specify a list of hosts (in the case, for example, YARN is not available). This is by done by specifiying the -h (hosts) option and separating the hosts with a ','. For example:

`sh hprofiler.sh ... -h host1,host2,host3,host4 ...`
