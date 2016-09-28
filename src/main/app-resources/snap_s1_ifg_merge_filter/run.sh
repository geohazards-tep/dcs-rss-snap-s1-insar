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
        *)                        	msg="Unknown error";;
    esac

   [ ${retval} -ne 0 ] && ciop-log "ERROR" "Error ${retval} - ${msg}, processing aborted" || ciop-log "INFO" "${msg}"
   exit ${retval}
}

trap cleanExit EXIT

function create_snap_request_mrg_flt_ml() {

#function call: create_snap_request_mrg_flt_ml "${inputfilesDIM[@]}" "${polarisation}" "${nLooks}" "${output_Mrg_Flt_Ml}"      

    # function which creates the actual request from
    # a template and returns the path to the request
  
    # get number of inputs    
    inputNum=$#
    
    #conversion of first input to array of strings nad get all the remaining input
    local -a inputfiles
    local polarisation
    local nLooks
    local output_Mrg_Flt_Ml
 
    # first input file always equal to the first function input
    inputfiles+=("$1")
    
    if [ "$inputNum" -gt "6" ] || [ "$inputNum" -lt "4" ]; then
        return ${SNAP_REQUEST_ERROR}
    elif [ "$inputNum" -eq "4" ]; then
        polarisation=$2
        nLooks=$3
        output_Mrg_Flt_Ml=$4
    elif [ "$inputNum" -eq "5" ]; then
        inputfiles+=("$2")
        polarisation=$3
        nLooks=$4
        output_Mrg_Flt_Ml=$5
    elif [ "$inputNum" -eq "6" ]; then
        inputfiles+=("$2")
        inputfiles+=("$3")
        polarisation=$4
        nLooks=$5
        output_Mrg_Flt_Ml=$6
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

function create_snap_request_subset() {

#function call: create_snap_request_subset "${inputfileDIM}" "${SubsetBoundingBox}" "${output_subset}"      

    # function which creates the actual request from
    # a template and returns the path to the request
    
    # get number of inputs
    inputNum=$#
    # check on number of inputs
    if [ "$inputNum" -ne "3" ] ; then
        return ${SNAP_REQUEST_ERROR}
    fi
    
    #get input
    local inputfileDIM=$1
    local SubsetBoundingBox=$2    
    local output_subset=$3
    
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
  <node id="Subset">
    <operator>Subset</operator>
    <sources>
      <sourceProduct refid="Read"/>
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
  <node id="Write">
    <operator>Write</operator>
    <sources>
      <sourceProduct refid="Subset"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${output_subset}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
    </parameters>
  </node>
  <applicationData id="Presentation">
    <Description/>
    <node id="Write">
	<displayPosition x="455.0" y="135.0"/>
    </node>
    <node id="Subset">
      <displayPosition x="214.0" y="127.0"/>
    </node>
    <node id="Read">
	<displayPosition x="37.0" y="134.0"/>
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

function create_snap_request_snaphuExport_cohSelect() {

#function call: create_snap_request_snaphuExport_cohSelect "${wrappedPhaseDIM}" "${coh_band_suffix}" "${output_cohExtraction}"

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
    local coh_band_suffix=$2
    local output_cohExtraction=$3

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
  <node id="BandSelect">
    <operator>BandSelect</operator>
    <sources>
      <sourceProduct refid="Read"/>
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
      <sourceProduct refid="BandSelect"/>
    </sources>
    <parameters class="com.bc.ceres.binding.dom.XppDomElement">
      <file>${output_cohExtraction}.dim</file>
      <formatName>BEAM-DIMAP</formatName>
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
    <node id="BandSelect">
      <displayPosition x="711.0" y="91.0"/>
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

function main() {

    #get input product list and convert it into an array
    local -a inputfiles=($@)
    
    #get the number of products to be processed
    inputfilesNum=$#
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Number of input products ${inputfilesNum}"

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
    
    local performSubset
    # retrieve the parameters value from workflow or job default value
    SubsetBoundingBox="`ciop-getparam SubsetBoundingBox`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The selected subset bounding box data is: ${SubsetBoundingBox}"

    #check if empty: in such case the subset must be skipped 
    [ -z "${SubsetBoundingBox}" ] && performSubset=false || performSubset=true
    
    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The performSubset flag is set to ${performSubset}"

    # retrieve the parameters value from workflow or job default value
    performPhaseUnwrapping="`ciop-getparam performPhaseUnwrapping`"

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "The performPhaseUnwrapping flag is set to ${performPhaseUnwrapping}"

    if [ "${performPhaseUnwrapping}" = true ] && [ "${performSubset}" = false ] ; then
    	exit ${ERR_UNWRAP_NO_SUBSET}
    fi

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
        swath_pol=$( echo `basename ${retrieved}` | sed -n -e 's|target_\(.*\)_Split_Orb_Back_ESD_Ifg_Deb_DInSAR.zip|\1|p' )
    	#current subswath IFG filename, as for snap split results
    	ifgInput=$( ls "${INPUTDIR}"/target_"${swath_pol}"_Split_Orb_Back_ESD_Ifg_Deb_DInSAR.dim )
    	# check if the file was retrieved, if not exit with the error code $ERR_NODATA
   	[ $? -eq 0 ] && [ -e "${ifgInput}" ] || return ${ERR_NODATA}

    	# log the value, it helps debugging.
    	# the log entry is available in the process stderr
   	ciop-log "DEBUG" "Input Interferogram product to be processed: ${ifgInput}"

    	inputfilesDIM+=("${ifgInput}") # Array append

    done

    #get polarisation from input product name, as generated by the core IFG node
    polarisation=$( basename "${inputfilesDIM[0]}"  | sed -n -e 's|target_IW._\(.*\)_Split_Orb_Back_ESD_Ifg_Deb_DInSAR.dim|\1|p' )

    # log the value, it helps debugging.
    # the log entry is available in the process stderr
    ciop-log "DEBUG" "Polarisation extracted from input product name: ${polarisation}"

    ### MERGING - FILTERING - MULTILOOKING PROCESSING
    # output products filename
    output_Mrg_Flt_Ml=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Back_ESD_Ifg_Deb_DInSAR_Merge_Flt_ML

    # report activity in the log
    ciop-log "INFO" "Preparing SNAP request file for merging, filtering and multilooking processing"

    # prepare the SNAP request
    SNAP_REQUEST=$( create_snap_request_mrg_flt_ml "${inputfilesDIM[@]}" "${polarisation}" "${nLooks}" "${output_Mrg_Flt_Ml}" )
    [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

    # report activity in the log
    ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

    # report activity in the log
    ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for merging, filtering and multilooking processing"

    # invoke the ESA SNAP toolbox
    gpt $SNAP_REQUEST &> /dev/null
    # check the exit code
    [ $? -eq 0 ] || return $ERR_SNAP

    ### AUX: get i,q and coh source bands suffix for useful the following processing 
    # get i and coh source bands name
    local i_source_band
    local coh_source_band
    i_source_band=$( ls "${output_Mrg_Flt_Ml}".data/i_*.img )
    # check if the file was retrieved, if not exit with the error code $ERR_NODATA
    [ $? -eq 0 ] && [ -e "${i_source_band}" ] || return ${ERR_NODATA}
    coh_source_band=$( ls "${output_Mrg_Flt_Ml}".data/coh_*.img )
    # check if the file was retrieved, if not exit with the error code $ERR_NODATA
    [ $? -eq 0 ] && [ -e "${coh_source_band}" ] || return ${ERR_NODATA}
    #get i and q bands suffix name for the output product
    local i_q_band_suffix
    i_q_band_suffix=$( basename "${i_source_band}" | sed -n -e 's|^i_\(.*\).img|\1|p' )
    #get coherence band suffix name for the output product
    local coh_band_suffix=""
    coh_band_suffix=$( basename "${coh_source_band}" | sed -n -e 's|^coh_\(.*\).img|\1|p' )

    ### SUBSETTING PROCESSING    
    # perform subsection if needed, else the "output_Mrg_Flt_Ml" product is directly passed to the following processing
    local output_subset=""
    if [ "${performSubset}" = true ] ; then
        # input product name
        inputfileDIM=${output_Mrg_Flt_Ml}.dim           
    	# output products filename
    	output_subset=${TMPDIR}/target_IW_${polarisation}_Split_Orb_Back_ESD_Ifg_Deb_DInSAR_Merge_Flt_ML_Sbs
        # bounding box from csv to space separated value
        SubsetBoundingBox=$( echo "${SubsetBoundingBox}" | sed 's|,| |g' )
        #convert subset bounding box into SNAP subsetting coordinates format
        SubsetBoundingBoxArray=($SubsetBoundingBox)
        lon_min="${SubsetBoundingBoxArray[0]}"
        lat_min="${SubsetBoundingBoxArray[1]}"
        lon_max="${SubsetBoundingBoxArray[2]}"
        lat_max="${SubsetBoundingBoxArray[3]}"
        subsettingBox="(("${lon_min}" "${lat_min}", "${lon_max}" "${lat_min}", "${lon_max}" "${lat_max}", "${lon_min}" "${lat_max}", "${lon_min}" "${lat_min}"))" 
    	
        # report activity in the log
    	ciop-log "INFO" "Preparing SNAP request file for subsetting processing"

    	# prepare the SNAP request
    	SNAP_REQUEST=$( create_snap_request_subset "${inputfileDIM}" "${subsettingBox}" "${output_subset}" )
    	[ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

    	# report activity in the log
    	ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

    	# report activity in the log
    	ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for subsetting processing"

    	# invoke the ESA SNAP toolbox
    	gpt $SNAP_REQUEST &> /dev/null
    	# check the exit code
    	[ $? -eq 0 ] || return $ERR_SNAP
        
    else
        output_subset=${output_Mrg_Flt_Ml}
    fi    

    ### UNWRAPPING AND TERRAIN CORRECTION PROCESSING
    # perform the "snaphu chain" if the unwrapping is needed, else perform only the terrain correction processing
    if [ "${performPhaseUnwrapping}" = true ] ; then

	# report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for SNAPHU export and coherence band extraction"
        
        # input wrapped phase DIM product
        wrappedPhaseDIM=${output_subset}.dim	
        # build output extracted coherence product
        output_cohExtraction=${TMPDIR}/extracted_coherence
        # output of snap export is always a folder with the same name of wrappedPhaseDIM, but without any .dim or .data extension
        output_snaphuExport=${output_subset}
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_snaphuExport_cohSelect "${wrappedPhaseDIM}" "${coh_band_suffix}" "${output_cohExtraction}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for SNAPHU export and coherence band extraction"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST &> /dev/null
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
        ciop-log "INFO" "Preparing SNAP request file for SNAPHU import and phase to displacement processings"

        # input unwrapped phase product
        unwrappedPhaseSnaphuOutHDR=${output_snaphuExport}/UnwPhase_${i_q_band_suffix}.snaphu.hdr  
        # Build output name for snaphu import output
        output_snaphuImport=${TMPDIR}/Unwrapped_phase_ph2disp
        output_snaphuImportDIM=${output_snaphuImport}.dim
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_snaphuImport_ph2disp "${wrappedPhaseDIM}" "${unwrappedPhaseSnaphuOutHDR}" "${output_snaphuImport}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

        # report activity in the log
        ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for SNAPHU import and phase to displacement processings"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP        

        # report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for terrain correction processing (Input = Unwrapped phase converted into displacement)"
        
        # Build output name for terrain corrected phase
        out_tc_phase=${OUTPUTDIR}/displacement_${i_q_band_suffix}
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_terrainCorrection_individualBand "${output_snaphuImportDIM}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}"  "${out_tc_phase}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

        # report activity in the log
        ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for terrain correction processing (Input = Unwrapped phase converted into displacement)"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP
        
        # report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for terrain correction processing (Input = Coherence)"

		ouput_cohExtractionDIM=${output_cohExtraction}.dim
        # Build output name for terrain corrected coherence
        out_tc_coh=${OUTPUTDIR}/coh_${coh_band_suffix}
        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_terrainCorrection_individualBand "${ouput_cohExtractionDIM}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${out_tc_coh}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

        # report activity in the log
        ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for terrain correction processing (Input = Coherence)"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP
    else
	# input product name
        inputfileDIM=${output_subset}.dim

        # report activity in the log
        ciop-log "INFO" "Preparing SNAP request file for terrain correction processing"

        # prepare the SNAP request
        SNAP_REQUEST=$( create_snap_request_terrainCorrection "${inputfileDIM}" "${demType}" "${pixelSpacingInMeter}" "${mapProjection}" "${i_q_band_suffix}" "${coh_band_suffix}" "${OUTPUTDIR}" )
        [ $? -eq 0 ] || return ${SNAP_REQUEST_ERROR}

        # report activity in the log
        ciop-log "INFO" "Generated request file: ${SNAP_REQUEST}"

        # report activity in the log
        ciop-log "INFO" "Invoking SNAP-gpt on the generated request file for terrain correction processing"

        # invoke the ESA SNAP toolbox
        gpt $SNAP_REQUEST &> /dev/null
        # check the exit code
        [ $? -eq 0 ] || return $ERR_SNAP 
    fi

    # publish the ESA SNAP results
    ciop-log "INFO" "Publishing Output Products" 
    ciop-publish -m "${OUTPUTDIR}"/*
	
    # cleanup
    rm -rf "${INPUTDIR}"/* "${TMPDIR}"/* "${OUTPUTDIR}"/* 

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
