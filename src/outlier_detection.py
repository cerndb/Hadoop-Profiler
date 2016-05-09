#!/bin/python

import os
import sys

def detect_outliers(output_directory):
    print(output_directory)

def main():
    num_arguments = len(sys.argv)
    if(num_arguments <= 1):
        print("Please specify the output directory.")
    elif(num_arguments == 2 and is_dir(sys.argv[1])):
        detect_outliers(sys.argv[1])
    else:
        print("Please specify an existing directory.")

if(__name__ == '__main__'):
    main()
