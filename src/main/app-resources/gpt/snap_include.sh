#!/bin/bash

# set the environment variables to use ESA SNAP toolbox
export SNAP_HOME=/opt/snap-3.0
export PATH=${SNAP_HOME}/bin:${PATH}
export SNAP_VERSION=$( cat ${SNAP_HOME}/VERSION.txt )
