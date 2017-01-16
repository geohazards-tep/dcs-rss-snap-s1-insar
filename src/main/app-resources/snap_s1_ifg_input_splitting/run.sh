#!/bin/bash

# source the ciop functions (e.g. ciop-log, ciop-getparam)
source ${ciop_job_include}

# set the environment variables to use ESA SNAP toolbox
#export SNAP_HOME=$_CIOP_APPLICATION_PATH/common/snap
#export PATH=${SNAP_HOME}/bin:${PATH}
source $_CIOP_APPLICATION_PATH/gpt/snap_include.sh

# define the exit codes
SUCCESS=0
SNAP_REQUEST_ERROR=1
ERR_SNAP=2
ERR_NOMASTER=3
ERR_NORETRIEVEDMASTER=4
ERR_NOSLAVE=5
ERR_NORETRIEVEDSLAVE=6
ERR_WRONGSUBSWATH=7
ERR_GETDATA=8
ERR_GETDATANAME=9
ERR_GETPOLARIZATION=10
ERR_WRONGPOLARIZATION=11
ERR_NOTEQUALPOL=12
ERR_INPUTPOLWRONG=13
ERR_WRONGINPUTNUM=14
ERR_GETACQMODE=15
ERR_WRONGACQMODE=16
ERR_GETPRODTYPE=17
ERR_WRONGPRODTYPE=18


# add a trap to exit gracefully
function cleanExit ()
{
    local retval=$?
    local msg=""

    case ${retval} in
        ${SUCCESS})               msg="Processing successfully concluded";;
        ${SNAP_REQUEST_ERROR})    msg="Could not create snap request file";;
        ${ERR_SNAP})              msg="SNAP failed to process";;
        ${ERR_NOMASTER})          msg="No master reference input provided";;
        ${ERR_NORETRIEVEDMASTER}) msg="Master product not correctly downloaded";;
        ${ERR_NOSLAVE})           msg="No slave reference input provided";;
        ${ERR_NORETRIEVEDSLAVE})  msg="Slave product not correctly downloaded";;
	${ERR_WRONGSUBSWATH})     msg="Wrong subswaths couple provided (IW1,IW3), only IW1,IW2 or IW2,IW3 are allowed";;
        ${ERR_GETDATA})           msg="Error while discovering product";;
        ${ERR_GETDATANAME})       msg="Error while retrieving input product name";;
        ${ERR_GETPOLARIZATION})   msg="Error while retrieving polarization info from input product name";;
        ${ERR_WRONGPOLARIZATION}) msg="Wrong polarisation retrieved from input product name";;
        ${ERR_NOTEQUALPOL})       msg="Polarisation is not the same for master and slave";;
        ${ERR_INPUTPOLWRONG})     msg="Input polarisation is not contained in the input products";;
        ${ERR_WRONGINPUTNUM})     msg="Number of input master products not equal to 1";;
        ${ERR_GETACQMODE})        msg="Error while retrieving acquisition mode info from input product name";;
        ${ERR_WRONGACQMODE})      msg="Wrong acquisition mode retrieved from input product name, only IW is allowed";;
        ${ERR_GETPRODTYPE})       msg="Error while retrieving product type info from input product name";;
        ${ERR_WRONGPRODTYPE})     msg="Wrong product type retrieved from input product name, only SLC is allowed";;
        *)                        msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   exit ${retval}
}

trap cleanExit EXIT

function get_product_name() {

  local catalogPath=$1

  #catalogPath assumed like  "https://data2.terradue.com/eop/scihub/dataset/search?uid=<productName>"

  queryName=$( basename "${catalogPath}" )
  [ $? -ne 0 ] && return ${ERR_GETDATANAME}

  #get product name from query name
  productName=$( echo "${queryName}" | sed -n -e 's|.*uid=\(.*\)|\1|p' )
  [ $? -ne 0 ] && return ${ERR_GETDATANAME}

  echo ${productName}
}

function check_acquisition_mode() {

  local productName=$1

  #productName assumed like S1A_AA_SLC_* where AA is the acquisition mode to be extracted

  acqModeName=$( echo ${productName:4:2} )
  [ -z "${acqModeName}" ] && return ${ERR_GETACQMODE}

  #check on extracted acquisition mode
  # IW is the unique allowed acquisition mode 
  if [ "${acqModeName}" = "IW" ] ; then
     echo ${acqModeName}
  else
     return ${ERR_WRONGACQMODE}
  fi
}

function check_product_type() {

  local productName=$1

  #productName assumed like S1A_IW_TTT_* where TTT is the acquisition mode to be extracted

  prodTypeName=$( echo ${productName:7:3} )
  [ -z "${prodTypeName}" ] && return ${ERR_GETPRODTYPE}

  #check on extracted acquisition mode
  # IW is the unique allowed acquisition mode
  if [ "${prodTypeName}" = "SLC" ] ; then
     echo ${prodTypeName}
  else
     return ${ERR_WRONGPRODTYPE}
  fi
}

function get_polarization() {

  local productName=$1

  #productName assumed like S1A_IW_SLC__1SPP_* where PP is the polarization to be extracted

  polarizationName=$( echo ${productName:14:2} )
  [ -z "${polarizationName}" ] && return ${ERR_GETPOLARIZATION}

  #check on extracted polarization
  # allowed values are: SH SV DH DV
  if [ "${polarizationName}" = "DH" ] || [ "${polarizationName}" = "DV" ] || [ "${polarizationName}" = "SH" ] || [ "${polarizationName}" = "SV" ]; then
     echo ${polarizationName}
  else
     return ${ERR_WRONGPOLARIZATION}
  fi
}


function get_data() {
  
  local ref=$1
  local target=$2
  local local_file
  local enclosure
  local res

  #get product url from input catalogue reference
  enclosure="$( opensearch-client -f atom "${ref}" enclosure)"
  # opensearh client doesn't deal with local paths
  res=$?
  [ $res -eq 0 ] && [ -z "${enclosure}" ] && return ${ERR_GETDATA}
  [ $res -ne 0 ] && enclosure=${ref}

  #substitution of "apihub" with "dhus"
  #because the new new sci hub accounts are not good for api hub
  #enclosure=$(echo "${enclosure}" | sed 's|apihub|dhus|g')

  enclosure=$(echo "${enclosure}" | tail -1)

  #download data and get data name
  #local_file="$( echo ${enclosure} | ciop-copy -C rssGTEP:Pa554R55GTEP -f -U -O ${target} - 2> /dev/null )"
  #local_file="$( echo ${enclosure} | ciop-copy -f -U -O ${target} - 2> /dev/null )"
  local_file="$( echo ${enclosure} | ciop-copy -f -U -O ${target} - 2> ${TMPDIR}/ciop_copy.stderr )"
  res=$?
  
  [ ${res} -ne 0 ] && return ${res}
  echo ${local_file}
}

function create_snap_request_split() {
    
    # function which creates the actual request from
    # a template and returns the path to the request
    local mastername
    local slavename
    local subswath
    local polarisation
    local outMasterSplitted
    local outSlaveSplitted

    mastername="$1"
    slavename="$2"
    subswath="$3"
    polarisation="$4"
    outMasterSplitted="$5"
    outSlaveSplitted="$6"    

    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

    cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read-Master">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${mastername}</file>
    </parameters>
  </node>
  <node id="Read-Slave">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${slavename}</file>
    </parameters>
  </node>
  <node id="TOPSAR-Split-Master">
    <operator>TOPSAR-Split</operator>
    <sources>
      <sourceProduct refid="Read-Master"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <subswath>${subswath}</subswath>
      <selectedPolarisations>${polarisation}</selectedPolarisations>
      <firstBurstIndex>1</firstBurstIndex>
      <lastBurstIndex>9</lastBurstIndex>
      <wktAoi/>
    </parameters>
  </node>
  <node id="TOPSAR-Split-Slave">
    <operator>TOPSAR-Split</operator>
    <sources>
      <sourceProduct refid="Read-Slave"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <subswath>${subswath}</subswath>
      <selectedPolarisations>${polarisation}</selectedPolarisations>
      <firstBurstIndex>1</firstBurstIndex>
      <lastBurstIndex>9</lastBurstIndex>
      <wktAoi/>
    </parameters>
  </node>
  <node id="Write-IW-Master">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="TOPSAR-Split-Master"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outMasterSplitted}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Write-IW-Slave">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="TOPSAR-Split-Slave"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outSlaveSplitted}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read-Master">
      <displayPosition x="211.0" y="17.0"/>
    </node>
    <node id="Read-Slave">
      <displayPosition x="194.0" y="145.0"/>
    </node>
    <node id="TOPSAR-Split-Master">
      <displayPosition x="6.0" y="58.0"/>
    </node>
    <node id="TOPSAR-Split-Slave">
      <displayPosition x="161.0" y="191.0"/>
    </node>
    <node id="Write-IW-Master">
      <displayPosition x="371.0" y="106.0"/>
    </node>
    <node id="Write-IW-Slave">
      <displayPosition x="339.0" y="245.0"/>
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

    #get input product list and convert it into an array
    local -a inputfiles=($@)

    #get the number of products to be processed
    inputfilesNum=$# 
 
    [ "$inputfilesNum" -ne "1" ] && exit $ERR_WRONGINPUTNUM
      
    #defines the inputs (i.e. master and slave products, where the master assumed to be provided as first)
    local master="${inputfiles[0]}"        

    local slave="`ciop-getparam slave`"

    # run a check on the master value, it can't be empty
    [ -z "$master" ] && exit $ERR_NOMASTER

    # run a check on the slave value, it can't be empty
    [ -z "$slave" ] && exit $ERR_NOSLAVE  

    # log the value, it helps debugging. 
    # the log entry is available in the process stderr 
    ciop-log "DEBUG" "The master product reference to be used is: ${master}"

    masterNameDebug=$( get_product_name "${master}" )
    [ $? -ne 0 ] && return $ERR_GETDATANAME
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Master product name extracted from input: ${masterNameDebug}"
	
    # log the value, it helps debugging. 
    # the log entry is available in the process stderr 
    ciop-log "DEBUG" "The slave product reference to be used is: ${slave}"

    slaveNameDebug=$( get_product_name "${slave}" )
    [ $? -ne 0 ] && return $ERR_GETDATANAME
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Slave product name extracted from input: ${slaveNameDebug}"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Getting acquisition mode from master product name"
    #get acquisition mode from master name product
    masterAcqMode=$( check_acquisition_mode "${masterNameDebug}" )
    res=$?
    [ $res -eq $ERR_GETACQMODE ] && return $ERR_GETACQMODE
    [ $res -eq $ERR_WRONGACQMODE ] && return $ERR_WRONGACQMODE
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Acquisition mode extracted from master product name: ${masterAcqMode}"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Getting acquisition mode from slave product name"
    #get acquisition mode from slave name product
    slaveAcqMode=$( check_acquisition_mode "${slaveNameDebug}" )
    res=$?
    [ $res -eq $ERR_GETACQMODE ] && return $ERR_GETACQMODE
    [ $res -eq $ERR_WRONGACQMODE ] && return $ERR_WRONGACQMODE
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Acquisition mode extracted from slave product name: ${slaveAcqMode}"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Getting product type from master product name"
    #get product type from master name product
    masterProdType=$( check_product_type "${masterNameDebug}" )
    res=$?
    [ $res -eq $ERR_GETPRODTYPE ] && return $ERR_GETPRODTYPE
    [ $res -eq $ERR_WRONGPRODTYPE ] && return $ERR_WRONGPRODTYPE
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Product type extracted from master product name: ${masterProdType}"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Getting product type from slave product name"
    #get product type from slave name product
    slaveProdType=$( check_product_type "${slaveNameDebug}" )
    res=$?
    [ $res -eq $ERR_GETPRODTYPE ] && return $ERR_GETPRODTYPE
    [ $res -eq $ERR_WRONGPRODTYPE ] && return $ERR_WRONGPRODTYPE
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Product type extracted from slave product name: ${slaveProdType}"

    # retrieve the parameters value from workflow or job default value
    subswath="`ciop-getparam subswath`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The subswath(s) to be processed is(are): ${subswath}"

    #check on input subswath: only contiguous subswaths are allowed, so IW1 and IW3 couple is not permitted
    [ "${subswath}" = "IW1,IW3" ] && exit $ERR_WRONGSUBSWATH
    [ "${subswath}" = "IW3,IW1" ] && exit $ERR_WRONGSUBSWATH
    
    # swath list from csv to space separated value
    inputSubswathList=$( echo "${subswath}" | sed 's|,| |g' )

    # retrieve the parameters value from workflow or job default value
    polarisation="`ciop-getparam polarisation`"

    # run a check on the polarisation value, it can't be empty
    [ -z "$polarisation" ] && exit $ERR_NOPOLARISATION
	
    # log the value, it helps debugging. 
    # the log entry is available in the process stderr 
    ciop-log "DEBUG" "The product polarisation to be processed is: ${polarisation}"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Getting polarisation from master product name"
    #get polarization from master name product
    masterPolarization=$( get_polarization "${masterNameDebug}" )
    res=$?
    [ $res -eq $ERR_GETPOLARIZATION ] && return $ERR_GETPOLARIZATION
    [ $res -eq $ERR_WRONGPOLARIZATION ] && return $ERR_WRONGPOLARIZATION
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Polarisation extracted from master product name: ${masterPolarization}"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Getting polarisation from slave product name"
    #get polarization from slave name product
    slavePolarization=$( get_polarization "${slaveNameDebug}" )
    res=$?
    [ $res -eq $ERR_GETPOLARIZATION ] && return $ERR_GETPOLARIZATION
    [ $res -eq $ERR_WRONGPOLARIZATION ] && return $ERR_WRONGPOLARIZATION
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Polarisation extracted from slave product name: ${slavePolarization}"

    #check on polarization: input polarisation must be contained in the input products
    # master product check
    if [ "${polarisation}" = "HH"  ]; then
       if [ "${masterPolarization}" != "DH" ] && [ "${masterPolarization}" != "SH" ]; then
          return $ERR_INPUTPOLWRONG  
       fi
    fi
    if [ "${polarisation}" = "VV"  ]; then
       if [ "${masterPolarization}" != "DV" ] && [ "${masterPolarization}" != "SV" ]; then
          return $ERR_INPUTPOLWRONG
       fi
    fi
    if [ "${polarisation}" = "HV"  ]; then
       if [ "${masterPolarization}" != "DH" ]; then
          return $ERR_INPUTPOLWRONG
       fi
    fi
    if [ "${polarisation}" = "VH"  ]; then
       if [ "${masterPolarization}" != "DV" ]; then
          return $ERR_INPUTPOLWRONG
       fi
    fi
    # slave product check
    if [ "${polarisation}" = "HH"  ]; then
       if [ "${slavePolarization}" != "DH" ] && [ "${slavePolarization}" != "SH" ]; then
          return $ERR_INPUTPOLWRONG
       fi
    fi
    if [ "${polarisation}" = "VV"  ]; then
       if [ "${slavePolarization}" != "DV" ] && [ "${slavePolarization}" != "SV" ]; then
          return $ERR_INPUTPOLWRONG
       fi
    fi
    if [ "${polarisation}" = "HV"  ]; then
       if [ "${slavePolarization}" != "DH" ]; then
          return $ERR_INPUTPOLWRONG
       fi
    fi
    if [ "${polarisation}" = "VH"  ]; then
       if [ "${slavePolarization}" != "DV" ]; then
          return $ERR_INPUTPOLWRONG
       fi
    fi

    # report Master retrieving activity in log
    ciop-log "INFO" "Retrieving ${master}"

    # retrieve the MASTER product to the local temporary folder TMPDIR provided by the framework (this folder is only used by this process)
    # the utility returns the local path so the variable $retrievedMaster contains the local path to the MASTER product
    retrievedMaster=$( get_data "${master}" "${TMPDIR}" ) 
     
    #masterTmp=/tmp/snap/S1A_IW_SLC__1SDV_20151103T101314_20151103T101341_008439_00BED5_B751.SAFE.zip
    #retrievedMaster=$( ciop-copy -U -o $TMPDIR "$masterTmp" )

    # check if the file was retrievedMaster, if not exit with the error code $ERR_NORETRIEVEDMASTER
    #[ $? -eq 0 ] && [ -e "${retrievedMaster}" ] || return ${ERR_NORETRIEVEDMASTER}
    if [ $? -ne 0  ] ; then
         cat ${TMPDIR}/ciop_copy.stderr
         return $ERR_NORETRIEVEDMASTER
    fi
    mastername=$( basename "$retrievedMaster" )

    # report activity in the log
    ciop-log "INFO" "Master product correctly retrieved: ${mastername}"
	
    # report Slave retrieving activity in log
    ciop-log "INFO" "Retrieving ${slave}"

    # retrieve the SLAVE product to the local temporary folder TMPDIR provided by the framework (this folder is only used by this process)
    # the utility returns the local path so the variable $retrievedSlave contains the local path to the SLAVE product
    retrievedSlave=$( get_data "${slave}" "${TMPDIR}" )

    #slaveTmp=/tmp/snap/S1A_IW_SLC__1SDV_20151127T101308_20151127T101335_008789_00C888_2D21.SAFE.zip
    #retrievedSlave=$( ciop-copy -U -o $TMPDIR "$slaveTmp" )

    # check if the file was retrievedSlave, if not exit with the error code $ERR_NORETRIEVEDSLAVE
    #[ $? -eq 0 ] && [ -e "${retrievedSlave}" ] || return ${ERR_NORETRIEVEDSLAVE}
    if [ $? -ne 0  ] ; then
          cat ${TMPDIR}/ciop_copy.stderr
          return $ERR_NORETRIEVEDSLAVE
    fi

    slavename=$( basename "$retrievedSlave" )

    # report activity in the log
    ciop-log "INFO" "Slave product correctly retrieved: ${slavename}"

    #loop on subswath to create a snap request file for each subwath and invoke topsar split
    subswathList=($inputSubswathList)
    subswathNum=${#subswathList[@]}
    let "subswathNum-=1"
    
    for swathIndex in `seq 0 $subswathNum`;
    do
        #current subswath
        currentSubswath=${subswathList[$swathIndex]}
        
        #input product filenames, as per snap split request file
        outMasterSplitted=${OUTPUTDIR}/target_${currentSubswath}_${polarisation}_Split_Master
        outMasterSplittedBasename=$( basename "$outMasterSplitted" )
        outSlaveSplitted=${OUTPUTDIR}/target_${currentSubswath}_${polarisation}_Split_Slave
        outSlaveSplittedBasename=$( basename "$outSlaveSplitted" )
        outSplittedCouple=${OUTPUTDIR}/target_${currentSubswath}_${polarisation}_Split_Couple
        outSplittedCoupleBasename=$( basename "$outSplittedCouple" )    

        # report activity in the log
    	ciop-log "INFO" "Preparing SNAP request file for Master and Slave ${currentSubswath} splitting"

    	#prepare snap request file for input splitting
    	# prepare the SNAP request
    	SNAP_REQUEST=$( create_snap_request_split "${retrievedMaster}" "${retrievedSlave}" "${currentSubswath}" "${polarisation}" "${outMasterSplitted}" "${outSlaveSplitted}" )
    	[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

    	# report activity in the log
    	ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

    	# report activity in the log
    	ciop-log "INFO" "Invoking SNAP-gpt on request file for Master and Slave ${currentSubswath} splitting"

    	# invoke the ESA SNAP toolbox
    	gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null

    	# check the exit code
    	[ $? -eq 0 ] || return $ERR_SNAP            
        
        # compress splitting results for the current subswath
        cd ${OUTPUTDIR}
        zip -r ${outSplittedCoupleBasename}.zip ${outMasterSplittedBasename}.data ${outMasterSplittedBasename}.dim ${outSlaveSplittedBasename}.data ${outSlaveSplittedBasename}.dim &> /dev/null       
        cd - &> /dev/null

  	# publish the ESA SNAP results
    	ciop-log "INFO" "Publishing splitting results for ${currentSubswath}" 
   	ciop-publish ${outSplittedCouple}.zip
	
        #cleanup current intermediate products
     	rm -rf ${SNAP_REQUEST} ${outMasterSplitted}.data ${outMasterSplitted}.dim ${outSlaveSplitted}.data ${outSlaveSplitted}.dim ${outSplittedCouple}.zip

    done

    # cleanup
    rm -rf ${retrievedMaster} ${retrievedSlave}

    return ${SUCCESS}
}

# create the output folder to store the output products and export it
mkdir -p ${TMPDIR}/output
export OUTPUTDIR=${TMPDIR}/output

declare -a inputfiles

while read inputfile; do
    inputfiles+=("${inputfile}") # Array append
done

main ${inputfiles[@]}
res=$?
[ ${res} -ne 0 ] && exit ${res}

exit $SUCCESS
