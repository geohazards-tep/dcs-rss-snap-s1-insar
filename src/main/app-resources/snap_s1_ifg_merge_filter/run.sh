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
ERR_CONVERT=12

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
        ${ERR_CONVERT})                 msg="Failed during full resolution GeoTIFF creation";;
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
      <initMethod>MCF</initMethod>
      <numberOfTileRows>1</numberOfTileRows>
      <numberOfTileCols>1</numberOfTileCols>
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


function propertiesFileCratorTIF_IFG(){
# function call propertiesFileCratorTIF_IFG "${outputProductTif}" "${description}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${pixelSpacing}" "${SNAP_VERSION}" "${processingTime}"
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "9" ]; then
        return ${ERR_PROPERTIES_FILE_CREATOR}
    fi

    # function which creates the .properties file to attach to the output tif file
    local outputProductTif=$1
    local description=$2
    local dateStart=$3
    local dateStop=$4
    local dateDiff_days=$5
    local polarisation=$6
    local pixelSpacing=$7
    local snapVersion=$8
    local processingTime=$9

    outputProductTIF_basename=$(basename "${outputProductTif}")
    properties_filename=${outputProductTif}.properties

    cat << EOF > ${properties_filename}
Title=${outputProductTIF_basename}
Service\ Name=SNAP-InSAR
Description=${description}
Master\ Date=${dateStart}
Slave\ Date=${dateStop}
Time\ Separation\ \(days\)=${dateDiff_days}
Polarisation=${polarisation}
Pixel\ Spacing=${pixelSpacing}
Snap\ Version=${snapVersion}
Processing\ Time=${processingTime}
EOF

    [ $? -eq 0 ] && {
        echo "${properties_filename}"
        return 0
    } || return ${ERR_PROPERTIES_FILE_CREATOR}

}


function create_snap_request_statsComputation(){
# function call: create_snap_request_statsComputation $tiffProduct $sourceBandName $outputStatsFile $pc_csv_list
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -lt "3" ] || [ "$inputNum" -gt "4" ]; then
        return ${SNAP_REQUEST_ERROR}
    fi

    local tiffProduct=$1
    local sourceBandName=$2
    local outputStatsFile=$3
    local pc_csv_list=""
    [ "$inputNum" -eq "3" ] && pc_csv_list="90,95" || pc_csv_list=$4
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
      <percentiles>${pc_csv_list}</percentiles>
      <accuracy>4</accuracy>
    </parameters>
  </node>
</graph>
EOF

    [ $? -eq 0 ] && {
        echo "${snap_request_filename}"
        return 0
    } || return ${SNAP_REQUEST_ERROR}

}


# function that put value labels (assumed to be 5 vlaues between min and max included)
# to the colorbar legend input depending on the provided min and max values
function colorbarCreator(){
# function call: colorbarCreator $inputColorbar $colorbarDescription $minimum $maximum $outputColorbar

# get number of inputs
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "5" ] ; then
    return ${ERR_COLORBAR_CREATOR}
fi

#get input
local inputColorbar=$1
local colorbarDescription=$2
local minimum=$3
local maximum=$4
local outputColorbar=$5

#compute colorbar values
rangeWidth=$(echo "scale=5; $maximum-($minimum)" | bc )
val_1=$(echo "scale=5; $minimum" | bc | awk '{printf "%.2f", $0}')
val_2=$(echo "scale=5; $minimum+$rangeWidth/4" | bc | awk '{printf "%.2f", $0}')
val_3=$(echo "scale=5; $minimum+$rangeWidth/2" | bc | awk '{printf "%.2f", $0}')
val_4=$(echo "scale=5; $minimum+$rangeWidth*3/4" | bc | awk '{printf "%.2f", $0}')
val_5=$(echo "scale=5; $maximum" | bc | awk '{printf "%.2f", $0}')

# add clolrbar description
convert -pointsize 15 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 9,22 \"$colorbarDescription\" " $inputColorbar $outputColorbar
# add color values
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 7,100 \"$val_1\" " $outputColorbar $outputColorbar
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 76,100 \"$val_2\" " $outputColorbar $outputColorbar
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 147,100 \"$val_3\" " $outputColorbar $outputColorbar
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 212,100 \"$val_4\" " $outputColorbar $outputColorbar
convert -pointsize 13 -font "${_CIOP_APPLICATION_PATH}/gpt/LucidaTypewriterBold.ttf" -fill black -draw "text 278,100 \"$val_5\" " $outputColorbar $outputColorbar

return 0

}


# function that creates a full resolution tif product that can be correctly shown on GEP
function visualization_product_creator_one_band(){
# function call visualization_product_creator_one_band ${inputTif} ${sourceBandName} ${min_val} ${max_val} ${outputTif} ${outputPNG}
inputNum=$#
inputTif=$1
sourceBandName=$2
min_val=$3
max_val=$4
outputTif=$5
createPNG=0
outputPNG=""
# check on number of inputs for png creation
if [ "$inputNum" -eq "6" ] ; then
    createPNG=1
    outputPNG=$6
fi
# check if min_val and max_val are absolute values or percentiles
# pc values are assumed like pc<value> with <value> it's an integer between 0 and 100
pc_test=$(echo "${min_val}" | grep "pc")
[ "${pc_test}" = "" ] && pc_test="false"
# extract coefficient for linear stretching (min and max out are related to a tiff with 8bit uint precision, 0 is kept for alpha band)
min_out=1
max_out=255
if [ "${pc_test}" = "false" ]; then
# min_val and max_val are absolute values
    $_CIOP_APPLICATION_PATH/snap_s1_ifg_merge_filter/linearEquationCoefficients.py ${min_val} ${max_val} ${min_out} ${max_out} > ab.txt
else
# min_val and max_val are percentiles
    #min max percentiles to be used in histogram stretching
    pc_min=$( echo $min_val | sed -n -e 's|^.*pc\(.*\)|\1|p')
    pc_max=$( echo $max_val | sed -n -e 's|^.*pc\(.*\)|\1|p')
    pc_min_max=$( extract_pc1_pc2 $inputTif $sourceBandName $pc_min $pc_max )
    [ $? -eq 0 ] || return ${ERR_CONVERT}
    $_CIOP_APPLICATION_PATH/snap_s1_ifg_merge_filter/linearEquationCoefficients.py ${pc_min_max} ${min_out} ${max_out} > ab.txt
fi
a=$( cat ab.txt | grep a | sed -n -e 's|^.*a=\(.*\)|\1|p')
b=$( cat ab.txt | grep b |  sed -n -e 's|^.*b=\(.*\)|\1|p')

ciop-log "INFO" "Linear stretching for image: $inputTif"
SNAP_REQUEST=$( create_snap_request_linear_stretching "${inputTif}" "${sourceBandName}" "${a}" "${b}" "${min_out}" "${max_out}" "temp-outputfile.tif" )
[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
# invoke the ESA SNAP toolbox
gpt ${SNAP_REQUEST} -c "${CACHE_SIZE}" &> /dev/null
# check the exit code
[ $? -eq 0 ] || return $ERR_SNAP

ciop-log "INFO" "Reprojecting and alpha band addition to image: $inputTif"
gdalwarp -ot Byte -srcnodata 0 -dstnodata 0 -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "ALPHA=YES" -t_srs EPSG:3857 temp-outputfile.tif ${outputTif} &> /dev/null
returnCode=$?
[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
#add overlay
gdaladdo -r average ${outputTif} 2 4 8 16 &> /dev/null
returnCode=$?
[ $returnCode -eq 0 ] || return ${ERR_CONVERT}
# create PNG case
if [ "$createPNG" -eq "1" ] ; then
    ciop-log "INFO" "Creating PNG of source image: $inputTif"
    # convert tiff in png 
    gdal_translate -ot Byte -of png temp-outputfile.tif temp-outputfile.png &> /dev/null
    # remove black background
    convert temp-outputfile.png -alpha set -channel O -fill none -opaque black ${outputPNG}
fi
#remove temp file
rm -f temp-outputfile*
# echo of input min max values (usefule mainly when pc_test=true but provided in both cases)
if [ "${pc_test}" = "false" ]; then
    echo ${min_val} ${max_val}
else
    echo ${pc_min_max}
fi

return 0
}


#function that extracts a couple of percentiles from an input TIFF for the selected source band contained in it
function extract_pc1_pc2(){
# function call: extract_pc1_pc2 $tiffProduct $sourceBandName $pc1 $pc2

# get number of inputs
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "4" ] ; then
    return ${SNAP_REQUEST_ERROR}
fi

local tiffProduct=$1
local sourceBandName=$2
local pc1=$3
local pc2=$4
local pc_csv_list=${pc1},${pc2}
# report activity in the log
ciop-log "INFO" "Extracting percentiles ${pc1} and ${pc2} from ${sourceBandName} contained in ${tiffProduct}"
# Build statistics file name
statsFile=${TMPDIR}/temp.stats
# prepare the SNAP request
SNAP_REQUEST=$( create_snap_request_statsComputation "${tiffProduct}" "${sourceBandName}" "${statsFile}" "${pc_csv_list}" )
[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}
# report activity in the log
ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"
# report activity in the log
ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for statistics extraction"
# invoke the ESA SNAP toolbox
gpt $SNAP_REQUEST -c "${CACHE_SIZE}" &> /dev/null
# check the exit code
[ $? -eq 0 ] || return $ERR_SNAP

# get maximum from stats file
percentile_1=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 8)
#get minimum from stats file
percentile_2=$(cat "${statsFile}" | grep world | tr '\t' ' ' | tr -s ' ' | cut -d ' ' -f 9)

rm ${statsFile}
echo ${percentile_1} ${percentile_2}
return 0

}


function create_snap_request_linear_stretching(){
# function call: create_snap_request_linear_stretching "${inputfileTIF}" "${sourceBandName}" "${linearCoeff}" "${offset}" "${min_out}" "${max_out}" "${outputfileTIF}"

# function which creates the actual request from
# a template and returns the path to the request

# get number of inputs
inputNum=$#
# check on number of inputs
if [ "$inputNum" -ne "7" ] ; then
    return ${SNAP_REQUEST_ERROR}
fi

local inputfileTIF=$1
local sourceBandName=$2
local linearCoeff=$3
local offset=$4
local min_out=$5
local max_out=$6
local outputfileTIF=$7

#sets the output filename
snap_request_filename="${TMPDIR}/$( uuidgen ).xml"

cat << EOF > ${snap_request_filename}
<graph id="Graph">
  <version>1.0</version>
  <node id="Read">
    <operator>Read</operator>
    <sources/>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${inputfileTIF}</file>
    </parameters>
  </node>
  <node id="BandMaths">
    <operator>BandMaths</operator>
    <sources>
      <sourceProduct refid="Read"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <targetBands>
        <targetBand>
          <name>quantized</name>
          <type>uint8</type>
          <expression>if fneq(${sourceBandName},0) then max(min(floor(${sourceBandName}*${linearCoeff}+${offset}),${max_out}),${min_out}) else 0</expression>
          <description/>
          <unit/>
          <noDataValue>0</noDataValue>
        </targetBand>
      </targetBands>
      <variables/>
    </parameters>
  </node>
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="BandMaths"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${outputfileTIF}</file>
      <formatName>GeoTIFF-BigTIFF</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Read">
            <displayPosition x="37.0" y="134.0"/>
    </node>
    <node id="BandMaths">
      <displayPosition x="472.0" y="131.0"/>
    </node>
    <node id="Write">
            <displayPosition x="578.0" y="133.0"/>
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
    bBoxSize="`ciop-getparam bBoxSize`"
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The bounding box size for subsetting is: ${bBoxSize}"

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
    local lon_min=""
    local lat_min=""
    local lon_max=""
    local lat_max=""
    # compute bounding box for subsetting
    if [ "${performPhaseUnwrapping}" = true ] && [ "${bBoxSize}" != "Inf" ] ; then
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
        local boxWidth=${bBoxSize}
        # AOI limited by the fixed size
        lon_min_box=$(echo "scale=4; $lon_center-($boxWidth/2)" | bc)
        lon_max_box=$(echo "scale=4; $lon_center+($boxWidth/2)" | bc)
        lat_min_box=$(echo "scale=4; $lat_center-($boxWidth/2)" | bc)
        lat_max_box=$(echo "scale=4; $lat_center+($boxWidth/2)" | bc)
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

    # set bounding box of the whole Earth to have the whole scene
    elif [ "${performPhaseUnwrapping}" = true ] && [ "${bBoxSize}" = "Inf" ] ; then
        lon_min="-180"
        lat_min="-90"
        lon_max="180"
        lat_max="90"       
    fi
    
    subsettingBox="(("${lon_min}" "${lat_min}", "${lon_max}" "${lat_min}", "${lon_max}" "${lat_max}", "${lon_min}" "${lat_max}", "${lon_min}" "${lat_min}"))"
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "INFO" "Applied subsettingBox = ${subsettingBox}"

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
    
    ## BROWSE PRODUCT AND PROPERTIES FILE CREATION 
    #get output phase product filename
    outputPhaseTIF=$( ls "${OUTPUTDIR}"/phase_* )
    outputPhaseTIF_basename=$( echo `basename ${outputPhaseTIF}` )
    outputPhaseBrowse_basename=$( echo `basename ${outputPhaseTIF}` | sed 's|tif|rgb.tif|g' )
    outputPhaseBrowse="${OUTPUTDIR}"/"${outputPhaseBrowse_basename}"
    #get output coherence product filename
    outputCohTIF=$( ls "${OUTPUTDIR}"/coh_* )
    outputCohTIF_basename=$( echo `basename ${outputCohTIF}` )
    outputCohBrowse_basename=$( echo `basename ${outputCohTIF}` | sed 's|tif|rgb.tif|g' )
    outputCohBrowse="${OUTPUTDIR}"/"${outputCohBrowse_basename}"
    outputCohBrowsePNG_basename=$( echo `basename ${outputCohTIF}` | sed 's|tif|png|g' )
    outputCohBrowsePNG="${OUTPUTDIR}"/"${outputCohBrowsePNG_basename}"
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
    description="Interferometric phase"
    outputProduct_no_ext_basename=$( echo `basename ${outputPhaseTIF}` | sed 's|.tif||g' )
    outputPhaseProduct_no_ext="${OUTPUTDIR}"/"${outputProduct_no_ext_basename}"
    outputPhaseTIF_properties=$( propertiesFileCratorTIF_IFG "${outputPhaseProduct_no_ext}" "${description}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${pixelSpacingInMeter}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Phase properties file created: ${outputPhaseTIF_properties}"
    # create properties file for coherence tif product
    description="Interferometric coherence"
    outputProduct_no_ext_basename=$( echo `basename ${outputCohTIF}` | sed 's|.tif||g' )
    outputCohProduct_no_ext="${OUTPUTDIR}"/"${outputProduct_no_ext_basename}"
    outputCohTIF_properties=$( propertiesFileCratorTIF_IFG "${outputCohProduct_no_ext}" "${description}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${pixelSpacingInMeter}" "${SNAP_VERSION}" "${processingTime}" )
    # report activity in the log
    ciop-log "DEBUG" "Coherence properties file created: ${outputCohTIF_properties}"
    # report activity in the log
    ciop-log "INFO" "Creating Browse products for phase and coherence output"
    # PHASE BROWSE PRODUCT
    pconvert -b 1 -f tif -s 0,0 -c $_CIOP_APPLICATION_PATH/gpt/cubehelix_cycle.cpd -o ${TMPDIR} ${outputPhaseTIF} &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_PCONVERT
    # output of pconvert
    pconvertOutTIF=${TMPDIR}/${outputPhaseTIF_basename}
    # reprojection
    gdalwarp -ot Byte -t_srs EPSG:3857 -srcalpha -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${pconvertOutTIF} ${outputPhaseBrowse}
    #Add overviews
    gdaladdo -r average ${outputPhaseBrowse} 2 4 8 16
    returnCode=$?
    [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
    rm $pconvertOutTIF
    # PNG product generation
    pconvert -b 1 -f png -s 0,0 -c $_CIOP_APPLICATION_PATH/gpt/cubehelix_cycle.cpd -o ${OUTPUTDIR} ${outputPhaseTIF} &> /dev/null 
    # colorbar genereation: it is static since 
    #    the values' range is always [-pi,+pi]
    #    the color palette is always cubehelix_cycle
    colorbarInput=$_CIOP_APPLICATION_PATH/gpt/ifg_phase_legend.png
    phaseColorbarOutput=${outputPhaseProduct_no_ext}.tif.legend.png
    cp ${colorbarInput} ${phaseColorbarOutput} 
    # COHERENCE BROWSE PRODUCT
    # Build source band name for statistics computation
    sourceBand=coh_${coh_band_suffix}
    # define percentiles min max values for coherence visualization
    min_val="pc2"
    max_val="pc96"
    # call function for visualization product generator
    min_max_val=$( visualization_product_creator_one_band "${outputCohTIF}" "${sourceBand}" "${min_val}" "${max_val}" "${outputCohBrowse}" "${outputCohBrowsePNG}" )
    retCode=$?
    [ $DEBUG -eq 1 ] && echo min_max_val $min_max_val
    [ $retCode -eq 0 ] || return $retCode
    # Colorbar legend to be customized with product statistics
    colorbarInput=$_CIOP_APPLICATION_PATH/gpt/colorbar_gray.png #sample Gray Colorbar (as used by pconvert with single band products) colorbar image
    # Output name of customized colorbar legend
    coherenceColorbarOutput=${outputCohProduct_no_ext}.tif.legend.png
    # colorbar description
    colorbarDescription="Coherence"
    # Customize colorbar with product statistics
    retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${coherenceColorbarOutput}" )

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
        # properties file creation	
	# get output displacement product filename
	outDisplacementTIF=$( ls "${OUTPUTDIR}"/displacement_* )
        outDisplacementTIF_basename=$( echo `basename ${outDisplacementTIF}`)
       	outDisplacement_no_ext_basename=$( echo ${outDisplacementTIF_basename} | sed 's|.tif||g' )
        outDisplacement_no_ext="${OUTPUTDIR}"/"${outDisplacement_no_ext_basename}"
        outDisplacementBrowse=${outDisplacement_no_ext}.rgb.tif
        #get processing time info useful to properties file creation for displacemenmt tif product      
        processingTime=$( date )
        # create properties file for coherence tif product
        description="LOS displacement [m]"
        outputDisplacementTIF_properties=$( propertiesFileCratorTIF_IFG "${outDisplacement_no_ext}" "${description}" "${dateStart}" "${dateStop}" "${dateDiff_days}" "${polarisation}" "${pixelSpacingInMeter}" "${SNAP_VERSION}" "${processingTime}" )
        # report activity in the log
        ciop-log "DEBUG" "Displacement properties file created: ${outputDisplacementTIF_properties}"
	# DISPLACEMENT BROWSE PRODUCT GENERATION
        # report activity in the log
	ciop-log "INFO" "Creating Browse Product for displacement output"
	# create browse tif for displacement phase product
	pconvert -f tif -b 1 -c $_CIOP_APPLICATION_PATH/gpt/JET.cpd -o "${TMPDIR}" "${outDisplacementTIF}" &> /dev/null
	# check the exit code
	[ $? -eq 0 ] || return $ERR_PCONVERT
        # create browse png for displacement phase product
        pconvert -f png -b 1 -c $_CIOP_APPLICATION_PATH/gpt/JET.cpd -o "${OUTPUTDIR}" "${outDisplacementTIF}" &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_PCONVERT
        # output of pconvert
        pconvertOutTIF=${TMPDIR}/${outDisplacementTIF_basename}
        # reprojection
        gdalwarp -ot Byte -t_srs EPSG:3857 -srcalpha -dstalpha -co "TILED=YES" -co "BLOCKXSIZE=512" -co "BLOCKYSIZE=512" -co "PHOTOMETRIC=RGB" -co "ALPHA=YES" ${pconvertOutTIF} ${outDisplacementBrowse}
        # Add overviews
        gdaladdo -r average ${outputPhaseBrowse} 2 4 8 16
        returnCode=$?
        [ $returnCode -eq 0 ] || return ${ERR_CONVERT}
        rm $pconvertOutTIF

        ## STATISTICS EXTRACTION AND COLOR LEGEND CREATION
        # report activity in the log
        ciop-log "INFO" "Statistics extraction from displacement product and colorabar legend creation"
        # Build source bvand name for statistics computation
        displacementSourceBand=displacement_${polarisation}
        # default percentiles values used by pconvert
        pc_min=2
        pc_max=96
        min_max_val=$( extract_pc1_pc2 $outDisplacementTIF $displacementSourceBand $pc_min $pc_max )
        #Colorbar legend to be customized with product statistics
        colorbarInput=$_CIOP_APPLICATION_PATH/gpt/displacement_legend.png #sample JET (as used for browse product generation with pconvert) colorbar image
	# Output name of customized colorbar legend
        displacementColorbarOutput=${outDisplacement_no_ext}.tif.legend.png
        # colorbar description
        colorbarDescription="Displacement [meters]"
        # Customize colorbar with product statistics
        retVal=$(colorbarCreator "${colorbarInput}" "${colorbarDescription}" ${min_max_val} "${displacementColorbarOutput}" )
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
