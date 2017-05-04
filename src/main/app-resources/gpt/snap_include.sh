#!/bin/bash

# set the environment variables to use ESA SNAP toolbox
export SNAP_HOME=/opt/snap
export PATH=${SNAP_HOME}/bin:${PATH}
export SNAP_VERSION=$( cat ${SNAP_HOME}/VERSION.txt )
export CACHE_SIZE=2048M
