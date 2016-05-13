#!/bin/sh

# Clean the old flamegraph git repository.
rm -rf src/flamegraph
# Fetch the FlameGraph git repository.
git clone https://github.com/brendangregg/FlameGraph.git src/flamegraph
# Go the the perf-map-agent files.
cd src/perf-map-agent

cmake CMakeLists.txt
make

cd ../..
