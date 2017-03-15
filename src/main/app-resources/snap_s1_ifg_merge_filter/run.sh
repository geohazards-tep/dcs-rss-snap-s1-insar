#!/bin/bash

# source the ciop functions (e.g. ciop-log, ciop-getparam)
source ${ciop_job_include}

# set the environment variables to use ESA SNAP toolbox
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
ERR_UNWRAP_NO_SUBSET=8
ERR_PROPERTIES_FILE_CREATOR=9
ERR_PCONVERT=10
ERR_COLORBAR_CREATOR=11

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
        ${ERR_UNWRAP_NO_SUBSET})    	msg="The subset bounding box data must be not empty in case of phase unwrapping (i.e. when performPhaseUnwrapping=true)";;
        ${ERR_PROPERTIES_FILE_CREATOR})	msg="Could not create the .properties file";;
        ${ERR_PCONVERT})                msg="PCONVERT failed to process";;
        ${ERR_COLORBAR_CREATOR})        msg="Failed during colorbar creation";;
        *)                        	msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   if [ $DEBUG -ne 1 ] ; then
	[ ${retval} -ne 0 ] && hadoop dfs -rmr $(dirname "${inputfiles[0]}")
   fi
   exit ${retval}
}

trap cleanExit EXIT

function create_snap_request_mrg_flt_ml_sbs() {

#function call: create_snap_request_mrg_flt_ml_sbs "${inputfilesDIM[@]}" "${demType}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${output_Mrg_Flt_Ml}" "${performPhaseFiltering}" "${performSubset}" "${SubsetBoundingBox}" "${output_subset}"

    # function which creates the actual request from
    # a template and returns the path to the request

    # get number of inputs
    inputNum=$#

    #conversion of first input to array of strings nad get all the remaining input
    local -a inputfiles
    local demType
    local polarisation
    local nAzLooks
    local nRgLooks
    local output_Mrg_Flt_Ml
    local performPhaseFiltering
    local performSubset
    local SubsetBoundingBox
    local output_subset
    

    # check on number of inputs
    if [ "$inputNum" -ne "12" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi

    # first input file always equal to the first function input
    inputfiles+=("$1")
    inputfiles+=("$2")
    inputfiles+=("$3")
    demType=$4
    polarisation=$5
    nAzLooks=$6
    nRgLooks=$7
    output_Mrg_Flt_Ml=$8
    performPhaseFiltering=$9
    performSubset=${10}
    SubsetBoundingBox=${11}
    output_subset=${12}

    local commentFltBegin=""
    local commentFltEnd=""
    local commentWriteMlSourceBegin=""
    local commentWriteMlSourceEnd=""
    local commentSbsBegin=""
    local commentSbsEnd=""

    local beginCommentXML="<!--"
    local endCommentXML="-->"

    # here is the logic to enable the proper snap steps dependent on inputs
    inputFilesNum=${#inputfiles[@]}

    if [ "${performPhaseFiltering}" = true ]; then
        commentDInSARSourceBegin="${beginCommentXML}"
        commentDInSARSourceEnd="${endCommentXML}"
    else
	commentFltBegin="${beginCommentXML}"
	commentFltEnd="${endCommentXML}"
    fi

    if [ "${performSubset}" = false ]; then
	commentSbsBegin="${beginCommentXML}"
	commentSbsEnd="${endCommentXML}"
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
  <node id="Read(2)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[1]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node> 
  <node id="Read(3)">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfiles[2]}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node> 
  <node id="TOPSAR-Merge">
    <operator>TOPSAR-Merge</operator>
    <sources>
      <sourceProduct refid="Read"/>
      <sourceProduct.1 refid="Read(2)"/>
      <sourceProduct.2 refid="Read(3)"/> 
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <selectedPolarisations>${polarisation}</selectedPolarisations>
    </parameters>
  </node> 
  <node id="Multilook">
    <operator>Multilook</operator>
    <sources>
${commentFltBegin}      <sourceProduct refid="GoldsteinPhaseFiltering"/> ${commentFltEnd}
${commentDInSARSourceBegin}      <sourceProduct refid="TopoPhaseRemoval"/> ${commentDInSARSourceEnd}
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <nRgLooks>${nRgLooks}</nRgLooks>
      <nAzLooks>${nAzLooks}</nAzLooks>
      <outputIntensity>false</outputIntensity>
      <grSquarePixel>true</grSquarePixel>
    </parameters>
  </node>
  <node id="TopoPhaseRemoval">
    <operator>TopoPhaseRemoval</operator>
    <sources>
      <sourceProduct refid="TOPSAR-Merge"/> 
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <orbitDegree>3</orbitDegree>
      <demName>${demType}</demName>
      <externalDEMFile/>
      <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
      <tileExtensionPercent>100</tileExtensionPercent>
      <topoPhaseBandName>topo_phase</topoPhaseBandName>
    </parameters>
  </node>
${commentFltBegin}  <node id="GoldsteinPhaseFiltering">
    <operator>GoldsteinPhaseFiltering</operator>
    <sources>
      <sourceProduct refid="TopoPhaseRemoval"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <alpha>1.0</alpha>
      <FFTSizeString>64</FFTSizeString>
      <windowSizeString>3</windowSizeString>
      <useCoherenceMask>false</useCoherenceMask>
      <coherenceThreshold>0.2</coherenceThreshold>
    </parameters>
  </node> ${commentFltEnd}
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="Multilook"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${output_Mrg_Flt_Ml}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
${commentSbsBegin}   <node id="Subset">
    <operator>Subset</operator>
    <sources>
      <sourceProduct refid="TopoPhaseRemoval"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <region/>
      <geoRegion>POLYGON ${SubsetBoundingBox}</geoRegion>
      <subSamplingX>1</subSamplingX>
      <subSamplingY>1</subSamplingY>
      <fullSwath>false</fullSwath>
      <tiePointGridNames/>
      <copyMetadata>true</copyMetadata>
    </parameters>
  </node>
  <node id="GoldsteinPhaseFilteringSbs">
    <operator>GoldsteinPhaseFiltering</operator>
    <sources>
      <sourceProduct refid="Subset"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <alpha>1.0</alpha>
      <FFTSizeString>64</FFTSizeString>
      <windowSizeString>3</windowSizeString>
      <useCoherenceMask>false</useCoherenceMask>
      <coherenceThreshold>0.2</coherenceThreshold>
    </parameters>
  </node>
  <node id="MultilookSbs">
    <operator>Multilook</operator>
    <sources>
      <sourceProduct refid="GoldsteinPhaseFilteringSbs"/> 
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <nRgLooks>${nRgLooks}</nRgLooks>
      <nAzLooks>${nAzLooks}</nAzLooks>
      <outputIntensity>false</outputIntensity>
      <grSquarePixel>true</grSquarePixel>
    </parameters>
  </node>
  <node id="WriteSbs">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="MultilookSbs"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${output_subset}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node> ${commentSbsEnd}
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
    <node id="GoldsteinPhaseFiltering">
      <displayPosition x="291.0" y="112.0"/>
    </node>
    <node id="Write">
      <displayPosition x="810.0" y="131.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}


function create_snap_request_terrainCorrection() {

#function call: create_snap_request_terrainCorrection "${inputfileDIM}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${i_q_band_suffix}" "${coh_band_suffix}" "${OUTPUTDIR}"
     
    # function which creates the actual request from
    # a template and returns the path to the request
    
    # get number of inputs    
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "7" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi 
  
    # get input
    local inputfileDIM=$1
    local demType=$2
    local pixelSpacingInMeter=$3
    local mapProjection=$4
    local i_q_band_suffix=$5
    local coh_band_suffix=$6
    local outputdir=$7
 
    local  mapProjectionSetting=""
    if [ "$mapProjection" = "WGS84(DD)" ]; then 
        mapProjectionSetting="$mapProjection"
    elif [ "$mapProjection" = "UTM / WGS84 (Automatic)" ]; then
        mapProjectionSetting="AUTO:42001"
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
      <file>${inputfileDIM}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Terrain-Correction">
    <operator>Terrain-Correction</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <demName>${demType}</demName>
      <externalDEMFile/>
      <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
      <!-- <externalDEMApplyEGM/>  -->
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
  <node id="BandMaths">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Terrain-Correction"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>ifg_phase_${i_q_band_suffix}</name>
          <type>float32</type>
          <expression>atan2(q_${i_q_band_suffix},i_${i_q_band_suffix})</expression>
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
      <sourceBands>coh_${coh_band_suffix}</sourceBands>
      <bandNamePattern/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputdir}/phase_${i_q_band_suffix}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <node id="Write(2)">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandSelect"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputdir}/coh_${coh_band_suffix}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="70.0" y="162.0"/>
    </node>
    <node id="Terrain-Correction">
      <displayPosition x="562.0" y="111.0"/>
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

function create_snap_request_terrainCorrection_individualBand() {

#function call: create_snap_request_terrainCorrection_individualBand "${inputfileDIM}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${ouputProduct}" 

    # function which creates the actual request from
    # a template and returns the path to the request

    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "5" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi

    # get input
    local inputfileDIM=$1
    local demType=$2
    local pixelSpacingInMeter=$3
    local mapProjection=$4
    local outputProduct=$5

    local  mapProjectionSetting=""
    if [ "$mapProjection" = "WGS84(DD)" ]; then
        mapProjectionSetting="$mapProjection"
    elif [ "$mapProjection" = "UTM / WGS84 (Automatic)" ]; then
        mapProjectionSetting="AUTO:42001"
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
      <file>${inputfileDIM}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="Terrain-Correction">
    <operator>Terrain-Correction</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <sourceBands/>
      <demName>${demType}</demName>
      <externalDEMFile/>
      <externalDEMNoDataValue>0.0</externalDEMNoDataValue>
      <!-- <externalDEMApplyEGM/> -->
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
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="Terrain-Correction"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputProduct}.tif</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="70.0" y="162.0"/>
    </node>
    <node id="Terrain-Correction">
      <displayPosition x="562.0" y="111.0"/>
    </node>
    <node id="Write">
      <displayPosition x="810.0" y="131.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}

function create_snap_request_snaphuImport_ph2disp() {

#function call: create_snap_request_snaphuImport_ph2disp "${wrappedPhaseDIM}" "${unwrappedPhaseSnaphuOutHDR}" "${output_snaphuImport}"

    # function which creates the actual request from
    # a template and returns the path to the request

    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "3" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi

    # get input
    local wrappedPhaseDIM=$1
    local unwrappedPhaseSnaphuOutHDR=$2
    local output_snaphuImport=$3


    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read-Phase">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
        <file>${wrappedPhaseDIM}</file>
        <formatName>BEAM-DIMAP</formatName> 
    </parameters>
  </node>
  <node id="SnaphuImport">
    <operator>SnaphuImport</operator>
    <sources>
      <sourceProduct refid="Read-Phase"/>
      <sourceProduct.1 refid="Read-Unwrapped-Phase"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <doNotKeepWrapped>true</doNotKeepWrapped>
    </parameters>
  </node>
  <node id="Read-Unwrapped-Phase">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
        <file>${unwrappedPhaseSnaphuOutHDR}</file>
        <formatName>SNAPHU</formatName> 
    </parameters>
  </node>
  <node id="PhaseToDisplacement">
    <operator>PhaseToDisplacement</operator>
    <sources>
      <sourceProduct refid="SnaphuImport"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement"/>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="PhaseToDisplacement"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${output_snaphuImport}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
         <displayPosition x="45.0" y="96.0"/>
    </node>
    <node id="SnaphuImport">
      <displayPosition x="205.0" y="134.0"/>
    </node>
    <node id="Read(2)">
      <displayPosition x="44.0" y="167.0"/>
    </node>
    <node id="PhaseToDisplacement">
         <displayPosition x="305.0" y="133.0"/>
    </node>
    <node id="Write">
         <displayPosition x="395.0" y="133.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}

function create_snap_request_snaphuExport() {

#function call: create_snap_request_snaphuExport "${wrappedPhaseDIM}" 

    # function which creates the actual request from
    # a template and returns the path to the request

    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "1" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi

    # get input
    local wrappedPhaseDIM=$1

    #sets the output filename    
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
   <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${wrappedPhaseDIM}</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <node id="SnaphuExport">
    <operator>SnaphuExport</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetFolder>${TMPDIR}</targetFolder>
      <statCostMode>DEFO</statCostMode>
      <initMethod>MST</initMethod>
      <numberOfTileRows>10</numberOfTileRows>
      <numberOfTileCols>10</numberOfTileCols>
      <numberOfProcessors>4</numberOfProcessors>
      <rowOverlap>0</rowOverlap>
      <colOverlap>0</colOverlap>
      <tileCostThreshold>500</tileCostThreshold>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
      <displayPosition x="70.0" y="162.0"/>
    </node>
    <node id="SnaphuExport">
      <displayPosition x="562.0" y="111.0"/>
    </node>
  </applicationData>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}
}

function propertiesFileCratorPNG(){
#function call: propertiesFileCratorPNG "${outputProductTif}" "${outputProductPNG}" "${legendPng}"

    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -lt "2" ] || [ "$inputNum" -gt "3" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output png file
    local outputProductTif=$1
    local outputProductPNG=$2
    if [ "$inputNum" -eq "3" ]; then
         legendPng=$3
         legendPng_basename=$(basename "${legendPng}")
    fi 
	
    # extraction coordinates from gdalinfo
    # Example of displayed coordinates by gdalinfo: "Upper Left  (  12.1207888,  43.8139423) ( 12d 7'14.84"E, 43d48'50.19"N)"
    # extraction takes into account the second row part "( 12d 7'14.84"E, 43d48'50.19"N)"  
    poly_string="POLYGON(("
    lower_left=""
    declare -a corner_position_list=("Lower Left" "Upper Left" "Upper Right" "Lower Right")
    for corner_position in "${corner_position_list[@]}"
    do
        # get longitude string
        lon_test=$( gdalinfo "${outputProductTif}" | grep "${corner_position}"  | tr -s " " | sed 's#.*).*(\(.*\), \(.*\)).*#\1#g' | sed 's#^ *##g' )
        # get latitude string
        lat_test=$( gdalinfo "${outputProductTif}" | grep "${corner_position}"  | tr -s " " | sed 's#.*).*(\(.*\), \(.*\)).*#\2#g' | sed 's#^ *##g' )
        #get each part of longitude coordinate to convert to decimal degrees
        deg=$(echo "${lon_test}" | sed -n -e 's|^\(.*\)d.*|\1|p')
        min=$(echo "${lon_test}" | sed -n -e 's|^.*d\(.*\)'\''.*|\1|p')
        sec=$(echo "${lon_test}" | sed -n -e 's|^.*'\''\(.*\)".*|\1|p')
        dir=$(echo "${lon_test}" | sed -n -e 's|^.*"\(.*\)|\1|p')
        lon_decimal=$(echo "scale=7; $deg+($min/60)+($sec/3600)" | bc)
        # if longitude is in west direction put minus sign
        if [ "${dir}" = "W" ] ; then
                lon_decimal=-$lon_decimal
        fi
        #get each part of latitude coordinate to convert to decimal degrees
        deg=$(echo "${lat_test}" | sed -n -e 's|^\(.*\)d.*|\1|p')
        min=$(echo "${lat_test}" | sed -n -e 's|^.*d\(.*\)'\''.*|\1|p')
        sec=$(echo "${lat_test}" | sed -n -e 's|^.*'\''\(.*\)".*|\1|p')
        dir=$(echo "${lat_test}" | sed -n -e 's|^.*"\(.*\)|\1|p')
        lat_decimal=$(echo "scale=7; $deg+($min/60)+($sec/3600)" | bc)
        # if latitude is in south direction put minus sign
        if [ "${dir}" = "S" ] ; then
                lat_decimal=-$lat_decimal
        fi
        # coordinate concatenation to build polygon string
        poly_string="${poly_string} ${lon_decimal} ${lat_decimal},"
        # save lower left coordinate
        if [ "${corner_position}" == "Lower Left" ] ; then
                lower_left="${lon_decimal} ${lat_decimal}"
        fi
        # concatenate lower left coordinates to close the polygon
        if [ "${corner_position}" == "Lower Right" ] ; then
                poly_string="${poly_string} ${lower_left} ))"
        fi
    done
    
    outputProductPNG_basename=$(basename "${outputProductPNG}")
    properties_filename=${outputProductPNG}.properties
    if [ "$inputNum" -eq "2" ]; then	

	cat << EOF > ${properties_filename}
title=${outputProductPNG_basename}
geometry=${poly_string}
EOF
    else
 	cat << EOF > ${properties_filename}
image_url=./${legendPng_basename}
title=${outputProductPNG_basename}
geometry=${poly_string}
EOF
    fi

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}

function propertiesFileCratorTIF(){
# function call propertiesFileCratorTIF "${outputPhaseTIF}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}"
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "7" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output tif file
    local outputProductTif=$1
    local dateStart=$2
    local dateStop=$3
    local dateDiff_days=$4 
    local polarisation=$5
    local snapVersion=$6
    local processingTime=$7

    outputProductTIF_basename=$(basename "${outputProductTif}")
    properties_filename=${outputProductTif}.properties

    cat << EOF > ${properties_filename}
title=${outputProductTIF_basename}
dateMaster=${dateStart}
dateSlave=${dateStop}
dateDiff_days=${dateDiff_days}
polarisation=${polarisation}
snapVersion=${snapVersion}
processingTime=${processingTime}
EOF

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}

function create_snap_request_statsComputation(){
# function call: create_snap_request_statsComputation $tiffProduct $sourceBandName $outputStatsFile
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "3" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi
     
    local tiffProduct=$1
    local sourceBandName=$2
    local outputStatsFile=$3

    #sets the output filename
    snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

   cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="StatisticsOp">
    <operator>StatisticsOp</operator>
    <sources>
      <sourceProducts></sourceProducts>
    </sources>
    <parameters>
      <sourceProductPaths>${tiffProduct}</sourceProductPaths>
      <shapefile></shapefile>
      <startDate></startDate>
      <endDate></endDate>
      <bandConfigurations>
        <bandConfiguration>
          <sourceBandName>${sourceBandName}</sourceBandName>
          <expression></expression>
          <validPixelExpression></validPixelExpression>
        </bandConfiguration>
      </bandConfigurations>
      <outputShapefile></outputShapefile>
      <outputAsciiFile>${outputStatsFile}</outputAsciiFile>
      <percentiles>90,95</percentiles>
      <accuracy>3</accuracy>
    </parameters>
  </node>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}

}


function colorbarCreator(){
# function call: colorbarCreator $inputColorbar $statsFile $outputColorbar

    #function that put value labels to the JET colorbar legend input depending on the
    # provided product statistics   

     # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "3" ] ; then
        return ${ERR_COLORBAR_CREATOR}
    fi
    
    #get input
    local inputColorbar=$1
    local statsFile=$2
    local outputColorbar=$3

    # get maximum from stats file
    maximum=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 5)
    #get minimum from stats file
    minimum=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 7)
    #compute colorbar values
    rangeWidth=$(echo "scale=5; ${maximum} - ${minimum}" | bc )
    red=$(echo "scale=5; $minimum" | bc | awk '{printf "%.2f", $0}')
    yellow=$(echo "scale=5; $minimum+$rangeWidth/4" | bc | awk '{printf "%.2f", $0}')
    green=$(echo "scale=5; $minimum+$rangeWidth/2" | bc | awk '{printf "%.2f", $0}')
    cyan=$(echo "scale=5; $minimum+$rangeWidth*3/4" | bc | awk '{printf "%.2f", $0}')    
    blue=$(echo "scale=5; $maximum" | bc | awk '{printf "%.2f", $0}')
    
    #add color values
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 7,100 \"$red\" " $inputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 76,100 \"$yellow\" " $outputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 147,100 \"$green\" " $outputColorbar $outputColorbar 
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 212,100 \"$cyan\" " $outputColorbar $outputColorbar
    convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 278,100 \"$blue\" " $outputColorbar $outputColorbar

    return 0

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
    performPhaseFiltering="`ciop-getparam performPhaseFiltering`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The performPhaseFiltering flag is set to ${performPhaseFiltering}"

    # retrieve the parameters value from workflow or job default value
    nAzLooks="`ciop-getparam nAzLooks`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The Azimuth Multilook factor is: ${nAzLooks}"

    #check if not empty and integer
    [ -z "${nAzLooks}" ] && exit ${ERR_NO_NLOOKS}
    re='^[0-9]+$'
    if ! [[ $nAzLooks =~ $re ]] ; then
       exit ${ERR_NLOOKS_NO_INT}
    fi

    # retrieve the parameters value from workflow or job default value
    nRgLooks="`ciop-getparam nRgLooks`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The Range Multilook factor is: ${nRgLooks}"

    #check if not empty and integer
    [ -z "${nRgLooks}" ] && exit ${ERR_NO_NLOOKS}
    re='^[0-9]+$'
    if ! [[ $nRgLooks =~ $re ]] ; then
       exit ${ERR_NLOOKS_NO_INT}
    fi
    
    # retrieve the parameters value from workflow or job default value
    SubsetBoundingBox="`ciop-getparam SubsetBoundingBox`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The selected subset bounding box data is: ${SubsetBoundingBox}"

    # retrieve the parameters value from workflow or job default value
    performPhaseUnwrapping="`ciop-getparam performPhaseUnwrapping`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The performPhaseUnwrapping flag is set to ${performPhaseUnwrapping}"

    # retrieve the parameters value from workflow or job default value
    demType="`ciop-getparam demtype`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The DEM type used is: ${demType}"

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
        swath_pol=$( echo `basename ${retrieved}` | sed -n -e 's|target_\(.*\)_Split_Orb_Back_ESD_Ifg_Deb.zip|\1|p' )
    	#current subswath IFG filename, as for snap split results
    	ifgInput=$( ls "${INPUTDIR}"/target_"${swath_pol}"_Split_Orb_Back_ESD_Ifg_Deb.dim )
    	# check if the file was retrieved, if not exit with the error code $ERR_NODATA
   	[ $? -eq 0 ] && [ -e "${ifgInput}" ] || return ${ERR_NODATA}

    	# log the value, it helps debugging.
    	# the log entry is available in the process stderr
   	ciop-log "DEBUG" "Input Interferogram product to be processed: ${ifgInput}"

    	inputfilesDIM+=("${ifgInput}") # Array append

    done

    #get polarisation from input product name, as generated by the core IFG node
    polarisation=$( basename "${inputfilesDIM[0]}"  | sed -n -e 's|target_IW._\(.*\)_Split_Orb_Back_ESD_Ifg_Deb.dim|\1|p' )

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Polarisation extracted from input product name: ${polarisation}"

    ### SUBSETTING BOUNDING BOX DEFINITION FOR PHASE UNWRAPPING PROCESSING
    local output_subset=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Back_ESD_Ifg_Deb_DInSAR_Merge_Flt_ML_Sbs
    local subsettingBox="-180,-56,180,60"
    if [ "${performPhaseUnwrapping}" = true ] ; then
        # bounding box from csv to space separated value
        SubsetBoundingBox=$( echo "${SubsetBoundingBox}" | sed 's|,| |g' )
        #convert subset bounding box into SNAP subsetting coordinates format
        SubsetBoundingBoxArray=($SubsetBoundingBox)
        lon_min_user="${SubsetBoundingBoxArray[0]}"
        lat_min_user="${SubsetBoundingBoxArray[1]}"
        lon_max_user="${SubsetBoundingBoxArray[2]}"
        lat_max_user="${SubsetBoundingBoxArray[3]}"
        # compute center of box
        lon_center=$(echo "scale=4; ($lon_min_user+$lon_max_user)/2" | bc)
        lat_center=$(echo "scale=4; ($lat_min_user+$lat_max_user)/2" | bc)
        # fixed size in degrees of the box
        local boxWidth="0.25"
        # AOI limited by the fixed size
        lon_min_box=$(echo "scale=4; $lon_center-($boxWidth/2)" | bc)
        lon_max_box=$(echo "scale=4; $lon_center+($boxWidth/2)" | bc)
        lat_min_box=$(echo "scale=4; $lat_center-($boxWidth/2)" | bc)
        lat_max_box=$(echo "scale=4; $lat_center+($boxWidth/2)" | bc)
        local lon_min=""
        local lat_min=""
        local lon_max=""
        local lat_max=""
        # if the user AOI is contained in the limited AOI get user AOI
        if (( $(bc <<< "$lon_min_user > $lon_min_box") )) && (( $(bc <<< "$lon_max_user < $lon_max_box") )) && (( $(bc <<< "$lat_min_user > $lat_min_box") )) && (( $(bc <<< "$lat_max_user < $lat_max_box") ))
        then
                lon_min="${lon_min_user}"
                lat_min="${lat_min_user}"
                lon_max="${lon_max_user}"
                lat_max="${lat_max_user}"
        else
        # otherwise get limited AOI
                lon_min="${lon_min_box}"
                lat_min="${lat_min_box}"
                lon_max="${lon_max_box}"
                lat_max="${lat_max_box}"
        fi
        subsettingBox="(("${lon_min}" "${lat_min}", "${lon_max}" "${lat_min}", "${lon_max}" "${lat_max}", "${lon_min}" "${lat_max}", "${lon_min}" "${lat_min}"))"

        # log the value, it helps debugging.
        # the log entry is available in the process stderr
        ciop-log "INFO" "Applied subsettingBox = ${subsettingBox}"

    fi

    ### MERGING - TOPO PHASE REMOVAL - FILTERING - MULTILOOKING
    # output products filename
    output_dinsar_mrg_flt_ml=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Back_ESD_Ifg_Deb_DInSAR_Merge_Flt_ML

    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for topographic phase removal, merging, filtering and multilooking"

    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_mrg_flt_ml_sbs "${inputfilesDIM[@]}" "${demType}" "${polarisation}" "${nAzLooks}" "${nRgLooks}" "${output_dinsar_mrg_flt_ml}" "${performPhaseFiltering}" "${performPhaseUnwrapping}" "${subsettingBox}" "${output_subset}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}    
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for topographic phase removal, merging, filtering and multilooking"

    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    #clean product useless for next step
    rm -rf ${INPUTDIR}/*.data ${INPUTDIR}/*.dim
  
    ### AUX: get i,q and coh source bands suffix for useful the following processing 
    # get i and coh source bands name
    local i_source_band
    local coh_source_band
    i_source_band=$( ls "${output_dinsar_mrg_flt_ml}".data/i_*.img )
    # check if the file was retrieved, if not exit with the error code $ERR_NODATA
    [ $? -eq 0 ] && [ -e "${i_source_band}" ] || return ${ERR_NODATA}
    coh_source_band=$( ls "${output_dinsar_mrg_flt_ml}".data/coh_*.img )
    # check if the file was retrieved, if not exit with the error code $ERR_NODATA
    [ $? -eq 0 ] && [ -e "${coh_source_band}" ] || return ${ERR_NODATA}
    #get i and q bands suffix name for the output product
    local i_q_band_suffix
    i_q_band_suffix=$( basename "${i_source_band}" | sed -n -e 's|^i_\(.*\).img|\1|p' )
    #get coherence band suffix name for the output product
    local coh_band_suffix=""
    coh_band_suffix=$( basename "${coh_source_band}" | sed -n -e 's|^coh_\(.*\).img|\1|p' )

    ### TERRAIN CORRECTION PROCESSING ON WRAPPED PHASE AND COHERENCE
    # input product name
    inputfileDIM=${output_dinsar_mrg_flt_ml}.dim

    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for terrain correction processing on wrapped phase and coherence"

    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_terrainCorrection "${inputfileDIM}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${i_q_band_suffix}" "${coh_band_suffix}" "${OUTPUTDIR}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
    [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
    
    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for terrain correction processing on wrapped phase and coherence"

    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP
    ## QUICK-LOOK AND PROPERTIES FILE CREATION 
    #get output phase product filename
    outputPhaseTIF=$( ls "${OUTPUTDIR}"/phase_* )
    outputPhaseTIF_basename=$( echo `basename ${outputPhaseTIF}` )
    outputPhasePNG_basename=$( echo `basename ${outputPhaseTIF}` | sed 's|tif|png|g' )
    outputPhasePNG="${OUTPUTDIR}"/"${outputPhasePNG_basename}"

    #get output coherence product filename
    outputCohTIF=$( ls "${OUTPUTDIR}"/coh_* )
    outputCohTIF_basename=$( echo `basename ${outputCohTIF}` )
    outputCohPNG_basename=$( echo `basename ${outputCohTIF}` | sed 's|tif|png|g' )
    outputCohPNG="${OUTPUTDIR}"/"${outputCohPNG_basename}"

    # get timing info for the tif properties file
    dates=$(echo "${outputPhaseTIF_basename}" | sed -n -e 's|^.*'"$polarisation"'_\(.*\).tif|\1|p')
    dateStart=$(echo "${dates}" | sed -n -e 's|^\(.*\)_.*|\1|p')
    dateStop=$(echo "${dates}" | sed -n -e 's|^.*_\(.*\)|\1|p')
    dateStart_s=$(date -d "${dateStart}" +%s)
    dateStop_s=$(date -d "${dateStop}" +%s)
    dateDiff_s=$(echo "scale=0; $dateStop_s-$dateStart_s" | bc )
    secondsPerDay="86400"
    dateDiff_days=$(echo "scale=0; $dateDiff_s/$secondsPerDay" | bc )
    processingTime=$( date )    

    # create properties file for phase tif product
    outputPhaseTIF_properties=$( propertiesFileCratorTIF "${outputPhaseTIF}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Phase properties file created: ${outputPhaseTIF_properties}"

    # create properties file for coherence tif product
    outputCohTIF_properties=$( propertiesFileCratorTIF "${outputCohTIF}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Coherence properties file created: ${outputCohTIF_properties}"

    # report activity in the log
    ciop-log "INFO" "Creating png quick-look file for phase and coherence output products"

    # create png for phase product
    pconvert -f png -b 1 -c $_CIOP_APPLICATION_PATH/gpt/cubehelix_cycle.cpd -W 2048 -o "${OUTPUTDIR}" "${outputPhaseTIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # create png for coherence product
    pconvert -f png -b 1 -W 2048 -o "${OUTPUTDIR}" "${outputCohTIF}" &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT

    #create .properties file for phase png quick-look
    outputPhasePNG_properties=$( propertiesFileCratorPNG "${outputPhaseTIF}" "${outputPhasePNG}" )
    # report activity in the log
    ciop-log "DEBUG" "Phase properties file created: ${outputPhasePNG_properties}"

    #create .properties file for coherence png quick-look
    outputCohPNG_properties=$( propertiesFileCratorPNG "${outputCohTIF}" "${outputCohPNG}" )
    # report activity in the log
    ciop-log "DEBUG" "Coherence properties file created: ${outputCohPNG_properties}"

    ### PHASE UNWRAPPING PROCESSING
    if [ "${performPhaseUnwrapping}" = true ] ; then
	# input wrapped phase DIM product
        wrappedPhaseDIM=${output_subset}.dim
        # output of snap export is always a folder with the same name of wrappedPhaseDIM, but without any .dim or .data extension
        output_snaphuExport=${output_subset}
	        
	## SNAPHU CHAIN PROCESSING
	# report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for SNAPHU export"
        
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_snaphuExport "${wrappedPhaseDIM}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
        [ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for SNAPHU export" 

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP
        
        # report activity in the log
        ciop-log "INFO" "Invoking SNAPHU to perform the phase unwrapping"

        #save current dir path
        currentDir=$( pwd )
        #go to the snaphu export product folder
        cd ${output_snaphuExport}
        # put the comment on the LOGFILE row of the snaphu.conf file to avoid SNAPHU crash (due to SNAP/SNAPHU issue)
        sed -i -- 's/LOGFILE/#LOGFILE/g' snaphu.conf
        # get the command line call to run snaphu from the snaphu.conf file
        snaphuCallCommand=$( cat snaphu.conf | grep "snaphu -f" )
        # remove the initial comment form the snaphu command line call (beacuse it is commented in the snaphu.conf file)
        snaphuCallCommand=$( echo "${snaphuCallCommand}" | sed 's/#//g' ) 
        # SNAPHU run
        ${snaphuCallCommand} &> /dev/null
        # Come back to the previous path 
        cd ${currentDir}      
        
        # report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for SNAPHU import and phase to displacement processing"

        # input unwrapped phase product
        unwrappedPhaseSnaphuOutHDR=${output_snaphuExport}/UnwPhase_${i_q_band_suffix}.snaphu.hdr  
        # Build output name for snaphu import output
        output_snaphuImport=${TMPDIR}/Unwrapped_phase_ph2disp
        output_snaphuImportDIM=${output_snaphuImport}.dim
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_snaphuImport_ph2disp "${wrappedPhaseDIM}" "${unwrappedPhaseSnaphuOutHDR}" "${output_snaphuImport}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
	[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
        # report activity in the log
        ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
       
        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for SNAPHU import and phase to displacement processing"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP        

        # report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for terrain correction processing (Input = Unwrapped phase converted into displacement)"
        
        # Build output name for terrain corrected phase
        out_tc_phase=${OUTPUTDIR}/displacement_${i_q_band_suffix}
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_terrainCorrection_individualBand "${output_snaphuImportDIM}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}"  "${out_tc_phase}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
	[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
        # report activity in the log
        ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
        
        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for terrain correction processing (Input = Unwrapped phase converted into displacement)"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP
	
	## QUICK-LOOK CREATION
	#get output displacement product filename
	outDisplacementTIF=$( ls "${OUTPUTDIR}"/displacement_* )
	outDisplacementPNG_basename=$( echo `basename ${outDisplacementTIF}` | sed 's|tif|png|g' )
	outDisplacementPNG="${OUTPUTDIR}"/"${outDisplacementPNG_basename}"
 
        #get processing time info useful to properties file creation for displacemenmt tif product      
        processingTime=$( date )
        # create properties file for coherence tif product
        outputDisplacementTIF_properties=$( propertiesFileCratorTIF "${outDisplacementTIF}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${SNAP_VERSION}" "${processingTime}" )
        # report activity in the log
        ciop-log "DEBUG" "Displacement properties file created: ${outputDisplacementTIF_properties}"

	# report activity in the log
	ciop-log "INFO" "Creating png quick-look file for displacement output product"

	# create png for displacement phase product
	pconvert -f png -b 1 -c $_CIOP_APPLICATION_PATH/gpt/JET.cpd -W 2048 -o "${OUTPUTDIR}" "${outDisplacementTIF}" &> /dev/null
	# check the exit code
	[ $? -eq 0 ] || return $ERR_PCONVERT

        ## STATISTICS EXTRACTION AND COLOR LEGEND CREATION
        # report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for statistics extraction from displacement product"

        # Build source bvand name for statistics computation
        displacementSourceBand=displacement_${polarisation}
        # Build statistics file name
        displacementStatsFile=${TMPDIR}/displacement.stats
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_statsComputation "${outDisplacementTIF}" "${displacementSourceBand}" "${displacementStatsFile}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
	[ $DEBUG -eq 1 ] && cat ${SNAP_REQUEST}
        # report activity in the log
        ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction from displacement product"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP

        #Colorbar legend to be customized with product statistics
        colorbarInput=$_CIOP_APPLICATION_PATH/gpt/displacement_legend.png #sample JET (as used for quick-look generationwith pconvert) colorbar image
        #Output name of customized colorbar legend
        colorbarOutput="${OUTPUTDIR}"/displacement_legend.png
        #Customize colorbar with product statistics
        retVal=$(colorbarCreator "${colorbarInput}" "${displacementStatsFile}" "${colorbarOutput}" )
        
        colorbarOutput_basename=$( echo `basename ${colorbarOutput}`)

	# report activity in the log
	ciop-log "INFO" "Creating properties file for displacement quick-look product"

	#create .properties file for displacement png quick-look
	outDisplacementPNG_properties=$( propertiesFileCratorPNG "${outDisplacementTIF}" "${outDisplacementPNG}" "${colorbarOutput}")
	# report activity in the log
	ciop-log "DEBUG" "Displacement properties file created: ${outDisplacementPNG_properties}"
    fi

    # publish the ESA SNAP results
    ciop-log "INFO" "Publishing Output Products" 
    ciop-publish -m "${OUTPUTDIR}"/*
	
    # cleanup
    rm -rf "${INPUTDIR}"/* "${TMPDIR}"/* "${OUTPUTDIR}"/*
    if [ $DEBUG -ne 1 ] ; then
    	for index in `seq 0 $inputfilesNum`;
    	do
    		hadoop dfs -rmr "${inputfiles[$index]}"     	
    	done
    fi

    return ${SUCCESS}
}

# create the output folder to store the output products and export it
mkdir -p ${TMPDIR}/output
export OUTPUTDIR=${TMPDIR}/output
mkdir -p ${TMPDIR}/input
export INPUTDIR=${TMPDIR}/input
export DEBUG=0

declare -a inputfiles

while read inputfile; do
    inputfiles+=("${inputfile}") # Array append
done

main ${inputfiles[@]}
res=$?
[ ${res} -ne 0 ] && exit ${res}

exit $SUCCESS
