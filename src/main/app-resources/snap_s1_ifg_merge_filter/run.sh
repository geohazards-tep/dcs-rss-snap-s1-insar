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
ERR_NO_NLOOKS=4
ERR_NLOOKS_NO_INT=5
ERR_NO_PIXEL_SPACING=6
ERR_PIXEL_SPACING_NO_NUM=7

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
        ${ERR_NO_NLOOKS})         	msg="Multilook factor is empty";;
        ${ERR_NLOOKS_NO_INT})     	msg="Multilook factor is not an integer number";;
        ${ERR_NO_PIXEL_SPACING})  	msg="Pixel spacing is empty";;
        ${ERR_PIXEL_SPACING_NO_NUM})	msg="Pixel spacing is not a number";;
        *)                        	msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   exit ${retval}
}

trap cleanExit EXIT

function create_snap_request_merge_filter() {

#function call: create_snap_request_merge_filter "${inputfilesDIM[@]}" "${polarisation}" "${nLooks}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${i_q_band_suffix}" "${OUTPUTDIR}"     

    # function which creates the actual request from
    # a template and returns the path to the request
  
    # get number of inputs    
    inputNum=$#
    
    #conversion of first input to array of strings nad get all the remaining input
    local -a inputfiles
    local polarisation
    local nLooks
    local demType
    local pixelSpacingInMeter
    local mapProjection
    local i_q_band_suffix
    local outputdir
 
    # first input file always equal to the first function input
    inputfiles+=("$1")
    
    if [ "$inputNum" -gt "10" ] || [ "$inputNum" -lt "8" ]; then
        return ${SNAP_REQUEST_ERROR}
    elif [ "$inputNum" -eq "8" ]; then
        polarisation=$2
        nLooks=$3
        demType=$4
        pixelSpacingInMeter=$5
        mapProjection=$6
        i_q_band_suffix=$7
        outputdir=$8
    elif [ "$inputNum" -eq "9" ]; then
        inputfiles+=("$2")
        polarisation=$3
        nLooks=$4
        demType=$5
        pixelSpacingInMeter=$6
        mapProjection=$7
        i_q_band_suffix=$8
        outputdir=$9
    elif [ "$inputNum" -eq "10" ]; then
        inputfiles+=("$2")
        inputfiles+=("$3")
        polarisation=$4
        nLooks=$5
        demType=$6
        pixelSpacingInMeter=$7
        mapProjection=$8
        i_q_band_suffix=$9
        outputdir=${10}
    fi
    
    local commentRead2Begin=""
    local commentRead2End=""
    local commentRead3Begin=""
    local commentRead3End=""
    local commentMergeBegin=""
    local commentMergeEnd=""
    local commentMergeSource3Begin=""
    local commentMergeSource3End=""
    local commentRead1SourceBegin=""
    local commentRead1SourceEnd=""
    
    local beginCommentXML="<!--"
    local endCommentXML="-->"

    # here is the logic to enable the proper snap steps dependent on the number of inputs
    inputFilesNum=${#inputfiles[@]}

    if [ "$inputFilesNum" -gt "3" ] || [ "$inputFilesNum" -lt "1" ]; then
        return ${SNAP_REQUEST_ERROR}
    elif [ "$inputFilesNum" -eq "1" ]; then
    	commentMergeBegin="${beginCommentXML}"
        commentMergeEnd="${endCommentXML}"
        commentRead2Begin="${beginCommentXML}"
        commentRead2End="${endCommentXML}"
        commentRead3Begin="${beginCommentXML}"
        commentRead3End="${endCommentXML}"
    elif [ "$inputFilesNum" -eq "2" ]; then
        commentRead1SourceBegin="${beginCommentXML}"
        commentRead1SourceEnd="${endCommentXML}"
        commentRead3Begin="${beginCommentXML}"
        commentRead3End="${endCommentXML}"
        commentMergeSource3Begin="${beginCommentXML}"
        commentMergeSource3End="${endCommentXML}"
    elif [ "$inputFilesNum" -eq "3" ]; then
        commentRead1SourceBegin="${beginCommentXML}"
        commentRead1SourceEnd="${endCommentXML}"
    fi    

    local mapProjectionSetting=""
    if [ "$mapProjection" = "WGS84(DD)" ]; then 
        mapProjectionSetting="$mapProjection"
    #	mapProjectionSetting="GEOGCS[&quot;WGS84(DD)&quot;, &#xd;
    #		DATUM[&quot;WGS84&quot;, &#xd;
    # 		SPHEROID[&quot;WGS84&quot;, 6378137.0, 298.257223563]], &#xd;
    # 		PRIMEM[&quot;Greenwich&quot;, 0.0], &#xd;
    #		UNIT[&quot;degree&quot;, 0.017453292519943295], &#xd;
    # 		AXIS[&quot;Geodetic longitude&quot;, EAST], &#xd;
    # 		AXIS[&quot;Geodetic latitude&quot;, NORTH]]"
    elif [ "$mapProjection" = "UTM / WGS84 (Automatic)" ]; then
        mapProjectionSetting="PROJCS[&quot;UTM Zone 31 / World Geodetic System 1984&quot;, &#xd;
  		GEOGCS[&quot;World Geodetic System 1984&quot;, &#xd;
    		DATUM[&quot;World Geodetic System 1984&quot;, &#xd;
      		SPHEROID[&quot;WGS 84&quot;, 6378137.0, 298.257223563, AUTHORITY[&quot;EPSG&quot;,&quot;7030&quot;]], &#xd;
      		AUTHORITY[&quot;EPSG&quot;,&quot;6326&quot;]], &#xd;
    		PRIMEM[&quot;Greenwich&quot;, 0.0, AUTHORITY[&quot;EPSG&quot;,&quot;8901&quot;]], &#xd;
    		UNIT[&quot;degree&quot;, 0.017453292519943295], &#xd;
    		AXIS[&quot;Geodetic longitude&quot;, EAST], &#xd;
    		AXIS[&quot;Geodetic latitude&quot;, NORTH]], &#xd;
  		PROJECTION[&quot;Transverse_Mercator&quot;], &#xd;
  		PARAMETER[&quot;central_meridian&quot;, 3.0], &#xd;
  		PARAMETER[&quot;latitude_of_origin&quot;, 0.0], &#xd;
  		PARAMETER[&quot;scale_factor&quot;, 0.9996], &#xd;
  		PARAMETER[&quot;false_easting&quot;, 500000.0], &#xd;
  		PARAMETER[&quot;false_northing&quot;, 0.0], &#xd;
  		UNIT[&quot;m&quot;, 1.0], &#xd;
  		AXIS[&quot;Easting&quot;, EAST], &#xd;
  		AXIS[&quot;Northing&quot;, NORTH]]"
    else 
       return ${SNAP_REQUEST_ERROR}
    fi
	
    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[0]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
${commentRead2Begin}  <node id="Read(2)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[1]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node> ${commentRead2End}
${commentRead3Begin}  <node id="Read(3)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[2]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node> ${commentRead3End}
${commentMergeBegin}  <node id="TOPSAR-Merge">
    <operator>TOPSAR-Merge</operator>
    <sources>
      <sourceProduct refid="Read"/>
      <sourceProduct.1 refid="Read(2)"/> 
${commentMergeSource3Begin}      <sourceProduct.2 refid="Read(3)"/> ${commentMergeSource3End}
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations>${polarisation}</selectedPolarisations>
    </parameters>
  </node> ${commentMergeEnd}
  <node id="Multilook">
    <operator>Multilook</operator>
    <sources>
      <sourceProduct refid="GoldsteinPhaseFiltering"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <nRgLooks>${nLooks}</nRgLooks>
      <nAzLooks>${nLooks}</nAzLooks>
      <outputIntensity>false</outputIntensity>
      <grSquarePixel>true</grSquarePixel>
    </parameters>
  </node>
  <node id="Terrain-Correction">
    <operator>Terrain-Correction</operator>
    <sources>
      <sourceProduct refid="Multilook"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <demName>${demType}</demName>
      <externalDEMFile/>
      <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
      <demResamplingMethod>BILINEAR_INTERPOLATION</demResamplingMethod>
      <imgResamplingMethod>BILINEAR_INTERPOLATION</imgResamplingMethod>
      <pixelSpacingInMeter>${pixelSpacingInMeter}</pixelSpacingInMeter>
      <!-- <pixelSpacingInDegree>1.3474729261792824E-4</pixelSpacingInDegree> -->
      <mapProjection>${mapProjectionSetting}</mapProjection>
      <nodataValueAtSea>true</nodataValueAtSea>
      <saveDEM>false</saveDEM>
      <saveLatLon>false</saveLatLon>
      <saveIncidenceAngleFromEllipsoid>false</saveIncidenceAngleFromEllipsoid>
      <saveLocalIncidenceAngle>false</saveLocalIncidenceAngle>
      <saveProjectedLocalIncidenceAngle>false</saveProjectedLocalIncidenceAngle>
      <saveSelectedSourceBand>true</saveSelectedSourceBand>
      <outputComplex>true</outputComplex>
      <applyRadiometricNormalization>false</applyRadiometricNormalization>
      <saveSigmaNought>false</saveSigmaNought>
      <saveGammaNought>false</saveGammaNought>
      <saveBetaNought>false</saveBetaNought>
      <incidenceAngleForSigma0>Use projected local incidence angle from DEM</incidenceAngleForSigma0>
      <incidenceAngleForGamma0>Use projected local incidence angle from DEM</incidenceAngleForGamma0>
      <auxFile>Latest Auxiliary File</auxFile>
      <externalAuxFile/>
    </parameters>
  </node>
  <node id="GoldsteinPhaseFiltering">
    <operator>GoldsteinPhaseFiltering</operator>
    <sources>
${commentMergeBegin}      <sourceProduct refid="TOPSAR-Merge"/> ${commentMergeEnd}
${commentRead1SourceBegin} <sourceProduct refid="Read"/> ${commentRead1SourceEnd}
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <alpha>1.0</alpha>
      <FFTSizeString>64</FFTSizeString>
      <windowSizeString>3</windowSizeString>
      <useCoherenceMask>false</useCoherenceMask>
      <coherenceThreshold>0.2</coherenceThreshold>
    </parameters>
  </node>
  <node id="BandMaths">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Terrain-Correction"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>ifg_srd_phase_${i_q_band_suffix}</name>
          <type>float32</type>
          <expression>atan2(q_ifg_srd_${i_q_band_suffix},i_ifg_srd_${i_q_band_suffix})</expression>
          <description/>
          <unit>phase</unit>
          <noDataValue>0.0</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="BandSelect">
    <operator>BandSelect</operator>
    <sources>
      <sourceProduct refid="Terrain-Correction"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations/>
      <sourceBands>coh_${i_q_band_suffix}</sourceBands>
      <bandNamePattern/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputdir}/ifg_srd_phase_${i_q_band_suffix}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="Write(2)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandSelect"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputdir}/coh_${i_q_band_suffix}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="70.0" y="162.0"/>
    </node>
    <node id="Read(2)">
      <displayPosition x="70.0" y="112.0"/>
    </node>
    <node id="Read(3)">
      <displayPosition x="70.0" y="62.0"/>
    </node>
    <node id="TOPSAR-Merge">
      <displayPosition x="162.0" y="112.0"/>
    </node>
    <node id="Multilook">
      <displayPosition x="472.0" y="112.0"/>
    </node>
    <node id="Terrain-Correction">
      <displayPosition x="562.0" y="111.0"/>
    </node>
    <node id="GoldsteinPhaseFiltering">
      <displayPosition x="291.0" y="112.0"/>
    </node>
    <node id="BandMaths">
      <displayPosition x="714.0" y="131.0"/>
    </node>
    <node id="BandSelect">
      <displayPosition x="711.0" y="91.0"/>
    </node>
    <node id="Write">
      <displayPosition x="810.0" y="131.0"/>
    </node>
    <node id="Write(2)">
      <displayPosition x="810.0" y="90.0"/>
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
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Number of input products ${inputfilesNum}"

    # retrieve the parameters value from workflow or job default value
    demType="`ciop-getparam demtype`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The DEM type used is: ${demType}"

    # retrieve the parameters value from workflow or job default value
    nLooks="`ciop-getparam nLooks`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The multilook factor is: ${nLooks}"

    #check if not empty and integer
    [ -z "${nLooks}" ] && exit ${ERR_NO_NLOOKS}

    re='^[0-9]+$'
    if ! [[ $nLooks =~ $re ]] ; then
       exit ${ERR_NLOOKS_NO_INT}
    fi

    # retrieve the parameters value from workflow or job default value
    pixelSpacingInMeter="`ciop-getparam pixelSpacingInMeter`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The pixel spacing in meters is: ${pixelSpacingInMeter}"

    #check if not empty and a real number
    [ -z "${pixelSpacingInMeter}" ] && exit ${ERR_NO_PIXEL_SPACING}

    re='^[0-9]+([.][0-9]+)?$'
    if ! [[ $pixelSpacingInMeter =~ $re ]] ; then
       exit ${ERR_PIXEL_SPACING_NO_NUM}
    fi

    # retrieve the parameters value from workflow or job default value
    mapProjection="`ciop-getparam mapProjection`"
     
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The Map projection used is: ${mapProjection}"

    # loop on input products to retrieve them and fill list for snap req file
    declare -a inputfilesDIM
    #i source band, get only from the first product
    local i_source_band

    let "inputfilesNum-=1"    

    for index in `seq 0 $inputfilesNum`;
    do
    	# report activity in log
    	ciop-log "INFO" "Retrieving ${inputfiles[$index]} from storage"

    	retrieved=$( ciop-copy -U -o $INPUTDIR "${inputfiles[$index]}" )
    	# check if the file was retrieved, if not exit with the error code $ERR_NODATA
    	[ $? -eq 0 ] && [ -e "${retrieved}" ] || return ${ERR_NODATA}

    	# report activity in the log
    	ciop-log "INFO" "Retrieved ${retrieved}"

    	cd $INPUTDIR
    	unzip `basename ${retrieved}` &> /dev/null
    	# let's check the return value
    	[ $? -eq 0 ] || return ${ERR_NODATA}
    	cd - &> /dev/null
        
        # current swath and polarization, as for SNAP core IFG output product name
        swath_pol=$( echo `basename ${retrieved}` | sed -n -e 's|target_\(.*\)_Split_Orb_Back_ESD_Ifg_Deb_DInSAR.zip|\1|p' )

    	#current subswath IFG filename, as for snap split results
    	ifgInput=$( ls "${INPUTDIR}"/target_"${swath_pol}"_Split_Orb_Back_ESD_Ifg_Deb_DInSAR.dim )
    	# check if the file was retrieved, if not exit with the error code $ERR_NODATA
   	[ $? -eq 0 ] && [ -e "${ifgInput}" ] || return ${ERR_NODATA}

    	# log the value, it helps debugging.
    	# the log entry is available in the process stderr
   	ciop-log "DEBUG" "Input Interferogram product to be processed: ${ifgInput}"

    	inputfilesDIM+=("${ifgInput}") # Array append

        # get i source band name
        if [ "$index" -eq "0" ]; then
            i_source_band=$( ls "${INPUTDIR}"/target_"${swath_pol}"_Split_Orb_Back_ESD_Ifg_Deb_DInSAR.data/i_ifg_srd_*.img )
            # check if the file was retrieved, if not exit with the error code $ERR_NODATA
            [ $? -eq 0 ] && [ -e "${i_source_band}" ] || return ${ERR_NODATA}
        fi
    done

    #get polarisation from input product name, as generated by the core IFG node
    polarisation=$( basename "${inputfilesDIM[0]}"  | sed -n -e 's|target_IW._\(.*\)_Split_Orb_Back_ESD_Ifg_Deb_DInSAR.dim|\1|p' )

    #get i and q bands suffix name for the output product
    local i_q_band_suffix=""
    #if there is only 1 subswath, the whole suffix that contains the subswath name must be saved
    if [ "$inputfilesNum" -eq "0" ]; then 
       i_q_band_suffix=$( basename "${i_source_band}" | sed -n -e 's|^i_ifg_srd_\(.*\).img|\1|p' )
    else
       #if there are more than 1 subswath, the output suffix must be saved without the subswath name
       i_q_band_suffix=$( basename "${i_source_band}" | sed -n -e 's|^i_ifg_srd_IW._\(.*\).img|\1|p' )
    fi

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Polarisation extracted from input product name: ${polarisation}"

    # output products filename	
    #outputMergeFilter=${OUTPUTDIR}/target_IW_${polarisation}_Split_Orb_Back_ESD_Ifg_Deb_DInSAR_Merge_Flt_ML_TC15

    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for producut merging and filtering"

    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_merge_filter "${inputfilesDIM[@]}" "${polarisation}" "${nLooks}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${i_q_band_suffix}" "${OUTPUTDIR}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for producut merging and filtering"
   
    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST &> /dev/null
    
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP

    # publish the ESA SNAP results
    ciop-log "INFO" "Publishing Output Products" 
    ciop-publish -m "${OUTPUTDIR}"/*
	
    # cleanup
    rm -rf "${INPUTDIR}"/* ${SNAP_REQUEST} "${OUTPUTDIR}"/* 

    return ${SUCCESS}
}

# create the output folder to store the output products and export it
mkdir -p ${TMPDIR}/output
export OUTPUTDIR=${TMPDIR}/output
mkdir -p ${TMPDIR}/input
export INPUTDIR=${TMPDIR}/input

declare -a inputfiles

while read inputfile; do
    inputfiles+=("${inputfile}") # Array append
done

main ${inputfiles[@]}
res=$?
[ ${res} -ne 0 ] && exit ${res}

exit $SUCCESS
