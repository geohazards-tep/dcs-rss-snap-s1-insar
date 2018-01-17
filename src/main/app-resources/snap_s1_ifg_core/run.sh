#!/bin/bash

# source the ciop functions (e.g. ciop-log, ciop-getparam)
source ${ciop_job_include}

# set the environment variables to use ESA SNAP toolbox
#export SNAP_HOME=$_CIOP_APPLICATION_PATH/common/snap
#export PATH=${SNAP_HOME}/bin:${PATH}
source $_CIOP_APPLICATION_PATH/gpt/snap_include.sh

# define the exit codes
SUCCESS=0
ERR_NODATA=1
SNAP_REQUEST_ERROR=2
ERR_SNAP=3
ERR_NOCOH_WIN_SIZE=4
ERR_COH_WIN_SIZE_NO_INT=5

# add a trap to exit gracefully
function cleanExit ()
{
    local retval=$?
    local msg=""

    case ${retval} in
        ${SUCCESS})               	msg="Processing successfully concluded";;
        ${ERR_NODATA})            	msg="Could not retrieve the input data";;
        ${SNAP_REQUEST_ERROR})    	msg="Could not create snap request file";;
        ${ERR_SNAP})              	msg="SNAP failed to process";;
        ${ERR_NOCOH_WIN_SIZE})    	msg="Coherence window size is empty";;
        ${ERR_COH_WIN_SIZE_NO_INT})    	msg="Coherence window size is not an integer";;
        *)                        	msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   [ ${retval} -ne 0 ] && hadoop dfs -rmr $(dirname "${inputfile}")
   exit ${retval}
}

trap cleanExit EXIT

function create_snap_request_ifg() {
    # function which creates the actual request from
    # a template and returns the path to the request
    local mastername
    local slavename
    local orbitType
    local demType
    local cohWinAz
    local cohWinRg
    local outputnameIfg

    mastername="$1"
    slavename="$2"
    orbitType="$3"
    demType="$4"
    cohWinAz="$5"
    cohWinRg="$6"
    outputnameIfg="$7"

    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${mastername}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Read(2)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${slavename}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Apply-Orbit-File">
    <operator>Apply-Orbit-File</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <orbitType>${orbitType}</orbitType>
      <polyDegree>3</polyDegree>
      <continueOnFail>true</continueOnFail>
    </parameters>
  </node>
  <node id="Apply-Orbit-File(2)">
    <operator>Apply-Orbit-File</operator>
    <sources>
      <sourceProduct refid="Read(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <orbitType>${orbitType}</orbitType>
      <polyDegree>3</polyDegree>
      <continueOnFail>true</continueOnFail>
    </parameters>
  </node>
  <node id="Back-Geocoding">
    <operator>Back-Geocoding</operator>
    <sources>
      <sourceProduct refid="Apply-Orbit-File"/>
      <sourceProduct.1 refid="Apply-Orbit-File(2)"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <demName>${demType}</demName>
      <demResamplingMethod>BICUBIC_INTERPOLATION</demResamplingMethod>
      <externalDEMFile/>
      <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
      <resamplingType>BISINC_5_POINT_INTERPOLATION</resamplingType>
      <maskOutAreaWithoutElevation>true</maskOutAreaWithoutElevation>
      <outputRangeAzimuthOffset>false</outputRangeAzimuthOffset>
      <outputDerampDemodPhase>true</outputDerampDemodPhase>
      <disableReramp>false</disableReramp>
    </parameters>
  </node>
  <node id="Interferogram">
    <operator>Interferogram</operator>
    <sources>
      <sourceProduct refid="Enhanced-Spectral-Diversity"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <subtractFlatEarthPhase>true</subtractFlatEarthPhase>
      <srpPolynomialDegree>5</srpPolynomialDegree>
      <srpNumberPoints>501</srpNumberPoints>
      <orbitDegree>3</orbitDegree>
      <includeCoherence>true</includeCoherence>
      <cohWinAz>${cohWinAz}</cohWinAz>
      <cohWinRg>${cohWinRg}</cohWinRg>
      <squarePixel>true</squarePixel>
    </parameters>
  </node>
  <node id="TOPSAR-Deburst">
    <operator>TOPSAR-Deburst</operator>
    <sources>
      <sourceProduct refid="Interferogram"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
    </parameters>
  </node>
  <node id="Enhanced-Spectral-Diversity">
    <operator>Enhanced-Spectral-Diversity</operator>
    <sources>
      <sourceProduct refid="Back-Geocoding"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <fineWinWidthStr>512</fineWinWidthStr>
      <fineWinHeightStr>512</fineWinHeightStr>
      <fineWinAccAzimuth>16</fineWinAccAzimuth>
      <fineWinAccRange>16</fineWinAccRange>
      <fineWinOversampling>128</fineWinOversampling>
      <xCorrThreshold>0.1</xCorrThreshold>
      <cohThreshold>0.15</cohThreshold>
      <numBlocksPerOverlap>10</numBlocksPerOverlap>
      <useSuppliedShifts>false</useSuppliedShifts>
      <overallAzimuthShift>0.0</overallAzimuthShift>
      <overallRangeShift>0.0</overallRangeShift>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="TOPSAR-Deburst"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputnameIfg}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="25.0" y="13.0"/>
    </node>
    <node id="Read(2)">
      <displayPosition x="28.0" y="229.0"/>
    </node>
    <node id="Apply-Orbit-File">
      <displayPosition x="12.0" y="84.0"/>
    </node>
    <node id="Apply-Orbit-File(2)">
      <displayPosition x="6.0" y="160.0"/>
    </node>
    <node id="Back-Geocoding">
      <displayPosition x="116.0" y="123.0"/>
    </node>
    <node id="Interferogram">
      <displayPosition x="427.0" y="123.0"/>
    </node>
    <node id="TOPSAR-Deburst">
      <displayPosition x="538.0" y="123.0"/>
    </node>
    <node id="Enhanced-Spectral-Diversity">
      <displayPosition x="241.0" y="123.0"/>
    </node>
    <node id="Write">
      <displayPosition x="743.0" y="197.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}


function main() { 

   local splittedCouple="$1"

   # retrieve the parameters value from workflow or job default value
   orbitType="`ciop-getparam orbittype`"

   # log the value, it helps debugging. 
   # the log entry is available in the process stderr 
   ciop-log "DEBUG" "The Orbit type used is: ${orbitType}" 

   # retrieve the parameters value from workflow or job default value
   demType="`ciop-getparam demtype`"

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The DEM type used is: ${demType}"

   # retrieve the parameters value from workflow or job default value
   cohWinAz="`ciop-getparam cohWinAz`"

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The coeherence azimuth window size is: ${cohWinAz}"

   #check if not empty and integer
   [ -z "${cohWinAz}" ] && exit ${ERR_NOCOH_WIN_SIZE}
  
   re='^[0-9]+$'
   if ! [[ $cohWinAz =~ $re ]] ; then
      exit ${ERR_COH_WIN_SIZE_NO_INT}
   fi

   # retrieve the parameters value from workflow or job default value
   cohWinRg="`ciop-getparam cohWinRg`"

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The coeherence range window size is: ${cohWinRg}"

   #check if not empty and integer
   [ -z "${cohWinRg}" ] && exit ${ERR_NOCOH_WIN_SIZE}

   re='^[0-9]+$'
   if ! [[ $cohWinRg =~ $re ]] ; then
      exit ${ERR_COH_WIN_SIZE_NO_INT}
   fi

   # report activity in log
   ciop-log "INFO" "Retrieving $splittedCouple from storage"

   retrieved=$( ciop-copy -U -o $INPUTDIR "$splittedCouple" )
   # check if the file was retrieved, if not exit with the error code $ERR_NODATA
   [ $? -eq 0 ] && [ -e "${retrieved}" ] || return ${ERR_NODATA}

   # report activity in the log
   ciop-log "INFO" "Retrieved ${retrieved}"
   
   cd $INPUTDIR
   unzip `basename ${retrieved}` &> /dev/null
   # let's check the return value
   [ $? -eq 0 ] || return ${ERR_NODATA}
   cd - &> /dev/null

   #splitted master filename, as for snap split results
   masterSplitted=$( ls "${INPUTDIR}"/target_*_Split_Master.dim ) 
   # check if the file was retrieved, if not exit with the error code $ERR_NODATA
   [ $? -eq 0 ] && [ -e "${masterSplitted}" ] || return ${ERR_NODATA}

   # log the value, it helps debugging. 
   # the log entry is available in the process stderr 
   ciop-log "DEBUG" "The master product to be processed is: ${masterSplitted}"

   #splitted slave filename, as for snap split results
   slaveSplitted=$( ls "${INPUTDIR}"/target_*_Split_Slave.dim )
   # check if the file was retrieved, if not exit with the error code $ERR_NODATA
   [ $? -eq 0 ] && [ -e "${slaveSplitted}" ] || return ${ERR_NODATA}

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The slave product to be processed is: ${slaveSplitted}"
   
   # report activity in the log
   ciop-log "INFO" "Preparing SNAP request file for Interferogram"

   # output products filenames
   masterSplittedBasename=$( basename $masterSplitted )
   swath_pol=$( echo $masterSplittedBasename | sed -n -e 's|target_\(.*\)_Split_Master.dim|\1|p' )
   outputnameIfg=${OUTPUTDIR}/target_${swath_pol}_Split_Orb_Back_ESD_Ifg_Deb
   outputnameIfgBasename=$( basename $outputnameIfg )

   # log the value, it helps debugging.
   # the log entry is available in the process stderr
   ciop-log "DEBUG" "The output product name is: ${outputnameIfg}"

   #prepare snap request file for input splitting
   # prepare the SNAP request
   SNAP_REQUEST=$( create_snap_request_ifg "${masterSplitted}" "${slaveSplitted}" "${orbitType}" "${demType}" "${cohWinAz}" "${cohWinRg}" "${outputnameIfg}" )
   [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

   # report activity in the log
   ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
 
   # report activity in the log
   ciop-log "INFO" "Invoking SNAP-gpt Interferogram using the generated request file"
   
   # invoke the ESA SNAP toolbox
   gpt ${SNAP_REQUEST} -c "${CACHE_SIZE}"

   # check the exit code
   [ $? -eq 0 ] || return $ERR_SNAP

   # compress splitting results for the current subswath
   cd ${OUTPUTDIR}
   zip -r ${outputnameIfgBasename}.zip ${outputnameIfgBasename}.data ${outputnameIfgBasename}.dim  &> /dev/null
   cd - &> /dev/null

   # publish the ESA SNAP result
   ciop-log "INFO" "Publishing generated Interferogram"
   ciop-publish  ${outputnameIfg}.zip    

   # cleanup
   rm -rf ${SNAP_REQUEST} "${INPUTDIR}"/* "${OUTPUTDIR}"/*  
   hadoop dfs -rmr "${splittedCouple}"

}

# create the output folder to store the output products and export it
mkdir -p ${TMPDIR}/output
export OUTPUTDIR=${TMPDIR}/output
mkdir -p ${TMPDIR}/input
export INPUTDIR=${TMPDIR}/input

while read inputfile
do 
    main "${inputfile}"
    res=$?
    [ ${res} -ne 0 ] && exit ${res}
done

exit $SUCCESS

