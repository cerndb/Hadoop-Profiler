#
# This script will aggregate collapsed stacks. It will do it in the following manner: the first user specified argument
# will be the destination file, all files following after this argument will be threated as a file that
# needs to be aggregated into the destination file.
#
# Author:   Joeri Hermans
# Version:  0.1
# Since:    17 March 2016
#

import sys
import os

def aggregate(destinationFile, aggregators):
    numAggregators = len(aggregators)
    stackcounts = {}
    for i in range(0, numAggregators):
        path = aggregators[i]
        for line in open(path):
            data = line.split()
            nElements = len(data) - 1
            key = ""
            for j in range(0, nElements):
                key += " " + data[j]
            key = key.strip()
            value = int(data[-1])
            if( not key in stackcounts ):
                stackcounts[key] = value
            else:
                stackcounts[key] += value
    lines = []
    for key, value in stackcounts.items():
        lines.append(key + " " + `value`)
    lines.sort()
    f = open(destinationFile, "w")
    for line in lines:
        f.write(line + '\n')
    f.close()

def main():
    numArguments = len(sys.argv)
    # Check if a sufficient number of arguments has been specified.
    if( numArguments >= 3 ):
        destinationFile = sys.argv[1]
        aggregators = []
        for i in range(2, numArguments):
            aggregators.append(sys.argv[i])
    aggregate(destinationFile, aggregators)

if __name__ == '__main__':
    main()
