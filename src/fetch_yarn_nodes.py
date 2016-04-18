import json
import urllib2
import threading
import time
import sys
import os
import pwd
import signal
import subprocess
import shutil

## BEGIN Script classes. ##############################################

class NodeAnalyzer (threading.Thread):

    def __init__(self, node, jobIdentifier):
        threading.Thread.__init__(self)
        self.mNodeAddress = node
        self.mJobIdentifier = jobIdentifier
        self.mHasMappers = False

    def has_mappers(self):
        return self.mHasMappers

    def get_node_address(self):
        return self.mNodeAddress

    def has_integers(self, output):
        splitted = output.split('\n')
        for split in splitted:
            if( is_integer(split) ):
                return True
        return False

    def run(self):
        # Construct the command which needs to be executed.
        command = [
            "ssh",
            "-oStrictHostKeyChecking=no",
            "-T",
            "%s" % self.mNodeAddress
        ]
        process = subprocess.Popen(command,
                                   shell=False,
                                   stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE)
        process.stdin.write("ps aux | grep -v std | grep -v container-executor | grep -v pts | " + self.mJobIdentifier + " | awk '{print $2}'")
        process.stdin.flush()
        output = process.communicate()[0]
        if( self.has_integers(output) ):
            self.mHasMappers = True

## END Script classes. ################################################


def display_active_nodes(analyzers):
    numAnalyzers = len(analyzers)
    str = ""
    for i in range(0, numAnalyzers):
        analyzer = analyzers[i]
        if( not analyzer.has_mappers() ):
            continue
        str += analyzers[i].get_node_address()
        if( i < numAnalyzers - 1 ):
            str += ","
    
    print str

def get_cluster_nodes(clusterAddress):
    workers = []
    data = json.load(urllib2.urlopen(clusterAddress))
    nodes = data['nodes']['node']
    numNodes = len(nodes)
    workers.append(nodes[0]['nodeHostName'])
    for i in range(0, numNodes):
        workers.append(nodes[i]['nodeHostName'])

    return workers

def analyze_application(clusterAddress, jobIdentifier):
    nodes = get_cluster_nodes(clusterAddress)
    nodes = list(set(nodes))
    numNodes = len(nodes)
    analyzers = []
    for i in range(0, numNodes):
        analyzer = NodeAnalyzer(nodes[i], jobIdentifier)
        analyzers.append(analyzer)
        analyzer.start()
    for i in range(0, numNodes):
        analyzers[i].join()
    display_active_nodes(analyzers)

def set_user():
    uid = pwd.getpwnam('root')[2]
    os.setuid(uid)

def is_integer(string):
    try:
        int(string)
        return True
    except ValueError:
        return False

def main():
    set_user()
    # Check if an expected number of arguments have been specfied.
    if( len(sys.argv) >= 3 ):
        clusterAddress = sys.argv[1]
        # Aggregate the job identifier.
        numArguments = len(sys.argv)
        jobIdentifier = ""
        for i in range(2, numArguments):
            jobIdentifier += " " + sys.argv[i]
        jobIdentifier = jobIdentifier.strip()
        analyze_application(clusterAddress, jobIdentifier)

if __name__ == '__main__':
    main()
