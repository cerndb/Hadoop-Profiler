#!/bin/python

import os
import sys
import math

## BEGIN Terminal color definitions. ########################################################

GREEN = '\033[92m'
ORANGE = '\033[93m'
RED = '\033[91m'
ENDS = '\033[0m'

## END Terminal color definitions. ##########################################################

def cosine_similarity(v1, v2):
    n = len(v1)

    sumab = 0
    sumaa = 0
    sumbb = 0
    for i in range(0, n):
        sumab += v1[i] * v2[i]
        sumaa += v1[i] * v1[i]
        sumbb += v2[i] * v2[i]
    if(sumaa == 0 or sumbb == 0):
        similarity = 0
    else:
        similarity = sumab/(math.sqrt(sumaa) * math.sqrt(sumbb))

    return similarity

def obtain_vector(dimensionality, mapping, profile_dir):
    # vector = [0] * dimensionality
    vector = [0] * dimensionality
    stacksfile = profile_dir + "/aggregated/stackcollapse.data"
    # Check if the path exists.
    if(os.path.exists(stacksfile)):
        # Construct the vector specific to this aggregator.
        for line in open(stacksfile):
            data = line.split()
            nElements = len(data) - 1
            key = ""
            for i in range(0, nElements):
                key += " " + data[i]
            key = key.replace("intel", "x86")
            key = key.strip()
            value = int(data[-1])
            # Lookup the key in the mapping table.
            index = mapping[key]
            if(value > 40):
                vector[index] = value
            else:
                vector[index] = 0

    return vector

def construct_mapping(datafile):
    mapping = {}

    index = 0
    for line in open(datafile):
        data = line.split()
        nElements = len(data) - 1
        key = ""
        for i in range(0, nElements):
            key += " " + data[i]
        key = key.replace("intel", "x86")
        key = key.strip()
        mapping[key] = index
        index += 1

    return mapping

def obtain_dimensionality(datafile):
    num_dimensions = 0
    # We can do this because stackcollapse codepaths are unique.
    for line in open(datafile):
        num_dimensions += 1

    return num_dimensions

def print_similarity_matrix(matrix, directories):
    global ENDS

    print("\n")
    nElements = len(matrix[0])
    length = 0
    for dir in directories:
        n = len(dir)
        if(n > length):
            length = n

    # Draw the content of the similarity matrix.
    for i in range(0, nElements):
        line = directories[i].ljust(length + 2)
        for j in range(0, nElements):
            if(i == j):
                line += "/ "
                continue
            if(matrix[i][j] == 0):
                line += "X "
                continue
            color = get_color(matrix[i][j])
            line += color + "0 " + ENDS
        print(line)

def get_color(value):
    if(value > 0.6):
        color = GREEN
    elif(value >= 0.4 and value <= 0.6):
        color = ORANGE
    else:
        color = RED

    return color

def detect_outliers(output_directory):
    global GREEN
    global ORANGE
    global RED
    global ENDS

    if(not output_directory.endswith("/")):
        output_directory += "/"
    # Fetch all hosts on which a profile has been made.
    directories = os.listdir(output_directory)
    # Remove the aggregated folder, since this is an average, not a possible outlier.
    directories.remove('aggregated')
    directories = sorted(directories)
    aggregated_datafile = output_directory + "aggregated/stackcollapse.data"
    # However, construct the hypothesis space from the aggregated stackdata.
    num_dimensions = obtain_dimensionality(aggregated_datafile)
    mapping = construct_mapping(aggregated_datafile)
    # Initialize an empty vector list.
    vectors = {}
    for profile in directories:
        vector = obtain_vector(num_dimensions, mapping, output_directory + profile)
        # Check if a valid vector is present.
        if(not (vector == None)):
            vectors[profile] = vector
    # Fetch the longest string length for formatting.
    max_dir_length = 0
    for dir in directories:
        length = len(dir)
        if(length > max_dir_length):
            max_dir_length = length
    max_formatting_length = 2 * max_dir_length + 4 + 5
    # Print the cosine similiarty between all aggregators.
    nDirectories = len(directories)
    # Initialize the similarity matrix.
    similarityMatrix = [[0] * nDirectories for i in range(nDirectories)]
    # Compute the similarities.
    for i in range(0, nDirectories):
        d1 = directories[i]
        vd1 = vectors[d1]
        for j in range(i + 1, nDirectories):
            d2 = directories[j]
            vd2 = vectors[d2]
            sim = cosine_similarity(vd1, vd2)
            # Only possible if no data is available
            if(sim == 0):
                similarityMatrix[i][j] = int(0)
                continue
            similarityMatrix[i][j] = sim
            similarityMatrix[j][i] = sim
            info = str(d1 + " vs " + d2 + ": ").ljust(max_formatting_length)
            color = get_color(sim)
            print(color + info + ENDS + str(sim))
    print_similarity_matrix(similarityMatrix, directories)

def main():
    num_arguments = len(sys.argv)
    if(num_arguments <= 1):
        print("Please specify the output directory.")
    elif(num_arguments == 2 and os.path.exists(sys.argv[1])):
        detect_outliers(sys.argv[1])
    else:
        print("Please specify an existing directory.")

if(__name__ == '__main__'):
    main()
