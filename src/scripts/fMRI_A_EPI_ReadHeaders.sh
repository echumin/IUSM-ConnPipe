#!/bin/bash
#
# Script: fMRI_A adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

###############################################################################


    echo "# =================================="
    echo "# 0. Dicom Header Information"
    echo "# =================================="


    if ${flags_EPI_UseJson}; then  
        log "JSON: Using json file provided by dcm2niix to extract header information "

        ## if 0_param_dcm_hdr.sh exists, remove it
        if [ -e "${EPIpath}/0_param_dcm_hdr.sh" ]; then
            rm ${EPIpath}/0_param_dcm_hdr.sh
        fi 

        # create the file and make it executable
        touch ${EPIpath}/0_param_dcm_hdr.sh
        chmod +x ${EPIpath}/0_param_dcm_hdr.sh                      

        dcm2niix_json_loc="${EPIpath}/0_epi.json"

	#####
	export scanner=`cat ${dcm2niix_json_loc} | ${EXEDIR}/src/func/jq-linux64 ."Manufacturer"`
	export scanner=${scanner:1:-1}
	if [ ${scanner} == "Siemens" ] || [ ${scanner} == "GE" ]; then
		export scanner_param_TR="RepetitionTime"  # "RepetitionTime" for Siemens;
		export scanner_param_TE="EchoTime"  # "EchoTime" for Siemens;
		export scanner_param_FlipAngle="FlipAngle"  # "FlipAngle" for Siemens; 
		export scanner_param_EffectiveEchoSpacing="EffectiveEchoSpacing"  # "EffectiveEchoSpacing" for Siemens; 
		export scanner_param_BandwidthPerPixelPhaseEncode="BandwidthPerPixelPhaseEncode"  # "BandwidthPerPixelPhaseEncode" for Siemens;
		export scanner_param_slice_fractimes="SliceTiming"  # "SliceTiming" for Siemens;
		export scanner_param_TotalReadoutTime="TotalReadoutTime"
		export scanner_param_AcquisitionMatrix="AcquisitionMatrixPE"
		export scanner_param_PhaseEncodingDirection="PhaseEncodingDirection"
	#LEGACY TAGS FOR GE DATA. 2021 AND LATER DCM2NIIX SEEM TO HAVE STANDARDIZED JSON TAGS    	
	#elif [[ ${scanner} == "GE" ]]; then
		# export scanner_param_TR="tr"  # "tr" for GE
		# export scanner_param_TE="te"  # "te" for GE
		# export scanner_param_FlipAngle="flip_angle"  # "flip_angle" for GE
		# export scanner_param_EffectiveEchoSpacing="effective_echo_spacing"  # "effective_echo_spacing" for GE
		# export scanner_param_BandwidthPerPixelPhaseEncode="NULL"  # unknown for GE; "pixel_bandwidth is something different
		# export scanner_param_slice_fractimes="slice_timing"  # "slice_timing" for GE also possible 
		# export scanner_param_TotalReadoutTime="TotalReadoutTime"
		# export scanner_param_AcquisitionMatrix="acquisition_matrix"
		# export scanner_param_PhaseEncodingDirection="phase_encode_direction"
	elif [[ ${Scanner} == "Philips" ]]; then
		export scanner_param_TR="RepetitionTime"  
		export scanner_param_TE="EchoTime"  
		export scanner_param_FlipAngle="FlipAngle"  
		export scanner_param_EffectiveEchoSpacing="NULL"  # Philips does not provide enough info to calculate this
		export scanner_param_BandwidthPerPixelPhaseEncode="NULL"  # unknown for Philips; "pixel_bandwidth is something different 
		export scanner_param_slice_fractimes="NULL"  # Unreliable and maybe even unknown for Philips data
		export scanner_param_TotalReadoutTime="NULL" # Unreliable and maybe even unknown for Philips data
		export scanner_param_AcquisitionMatrix="AcquisitionMatrixPE"
		export scanner_param_PhaseEncodingDirection="PhaseEncodingAxis"
	else
		log "ERROR - unrecognized or missing scanner manufacturer tag in json header"
		exit 1
    	fi

        EPI_slice_fractimes=`cat ${EPIpath}/0_epi.json | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_slice_fractimes}`
        # echo "export EPI_slice_fractimes=${EPI_slice_fractimes}" >> ${EPIpath}/0_param_dcm_hdr.sh
        log "SliceTiming extracted from header is $EPI_slice_fractimes"
        TR=`cat ${EPIpath}/0_epi.json | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TR}`
        log "RepetitionTime extracted from header is $TR"
        echo "export TR=${TR}" >> ${EPIpath}/0_param_dcm_hdr.sh
        TE=`cat ${EPIpath}/0_epi.json | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_TE}`
        log "EchoTime extracted from header is $TE"
        echo "export TE=${TE}" >> ${EPIpath}/0_param_dcm_hdr.sh
        EPI_FlipAngle=`cat ${EPIpath}/0_epi.json | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_FlipAngle}`
        log "FlipAngle extracted from header is $EPI_FlipAngle"
        echo "export EPI_FlipAngle=${EPI_FlipAngle}" >> ${EPIpath}/0_param_dcm_hdr.sh
        EPI_EffectiveEchoSpacing=`cat ${EPIpath}/0_epi.json | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_EffectiveEchoSpacing}`
        log "EffectiveEchoSpacing extracted from header is $EPI_EffectiveEchoSpacing"    
        echo "export EPI_EffectiveEchoSpacing=${EPI_EffectiveEchoSpacing}" >> ${EPIpath}/0_param_dcm_hdr.sh                                                        
        EPI_BandwidthPerPixelPhaseEncode=`cat ${EPIpath}/0_epi.json | ${EXEDIR}/src/func/jq-linux64 .${scanner_param_BandwidthPerPixelPhaseEncode}`
        log "BandwidthPerPixelPhaseEncode extracted from header is $EPI_BandwidthPerPixelPhaseEncode"
        echo "export EPI_BandwidthPerPixelPhaseEncode=${EPI_BandwidthPerPixelPhaseEncode}" >> ${EPIpath}/0_param_dcm_hdr.sh
        # find TotalReadoutTime

        log "THIS IS EPIpath ${EPIpath}"

        cmd="${EXEDIR}/src/scripts/get_readout.sh ${EPIpath}/0_epi.json ${EPIpath}/DICOMS EPI" 
        log $cmd
        EPI_SEreadOutTime=`$cmd`
        log "EPI_SEreadOutTime = ${EPI_SEreadOutTime}"
        echo "export EPI_SEreadOutTime=${EPI_SEreadOutTime}" >> ${EPIpath}/0_param_dcm_hdr.sh

        # get the SliceTiming values in an array
        declare -a starr; 
        for val in $EPI_slice_fractimes; do 
            starr+=($val); 
        done                    
        starr=("${starr[@]:1:$((${#starr[@]}-2))}")    # remove [ and ] at beginning and end of array                                   
        starr=( "${starr[@]/,}" )  # remove commas at end of lines,
        
        # ########### just to test slice extraction ##################
        # starr=("${starr[@]:1:$((${#starr[@]}-36))}") ##DELETE THIS LINE                    
        # ###########################################################

        n_slice=${#starr[@]}
        log "SliceTiming extracted from header; number of slices: ${n_slice}"
        echo "export n_slice=${n_slice}" >> ${EPIpath}/0_param_dcm_hdr.sh

        printf "%f\n" "${starr[@]}" > "${EPIpath}/temp.txt"                    
                            
        while IFS= read -r num; do
            norm=$(bc <<< "scale=8 ; $num / $TR")
            norm2=$(bc <<< "scale=8 ; $norm - 0.5")
            echo $norm2
        done < "${EPIpath}/temp.txt"  > "${EPIpath}/slicetimes_frac.txt"

        rm -vf "${EPIpath}/temp.txt"

        ## Extract Slicing time
        cmd="${EXEDIR}/src/scripts/extract_slice_time.sh ${EPIpath} ${starr[@]}" 
        echo $cmd
        eval $cmd
        # exitcode=$?

    else   ## if not using JSON file, extract info from DICOMs

        path_EPIdcm=${EPIpath}/${configs_dcmFolder}

        # Identify DICOMs
        declare -a dicom_files
        while IFS= read -r -d $'\0' dicomfile; do 
            dicom_files+=( "$dicomfile" )
        done < <(find ${path_EPIdcm} -iname "*.${configs_dcmFiles}" -print0 | sort -z)

        if [ ${#dicom_files[@]} -eq 0 ]; then 
            echo "No dicom (.${configs_dcmFiles}) images found."
            echo "Please specify the correct file extension of dicom files by setting the configs_dcmFiles flag in the config file"
            echo "Skipping further analysis"
            exit 1
        else
            echo "There are ${#dicom_files[@]} dicom files in this EPI-series "
        fi

        # Extract Repetition time (TR)
        # Dicom header information --> Flag 0018,0080 "Repetition Time"
        cmd="dicom_hinfo -tag 0018,0080 ${dicom_files[0]}"                    
        log $cmd 
        out=`$cmd`                
        TR=( $out )  # make it an array
        TR=$(bc <<< "scale=2; ${TR[1]} / 1000")
        log "-HEADER extracted TR: ${TR}"
        echo "export TR=${TR}" >> ${EPIpath}/0_param_dcm_hdr.sh

    #-------------------------------------------------------------------------%
        # Slice Time Acquisition                    
        dcm_file=${dicom_files[0]}
        cmd="dicom_hinfo -no_name -tag 0019,100a ${dcm_file}"
        log $cmd
        n_slice=`$cmd`
        log "-HEADER extracted number of slices: $n_slice"
        echo "export n_slice=${n_slice}" >> ${EPIpath}/0_param_dcm_hdr.sh

        id1=6
        id2=$(bc <<< "${id1} + ${n_slice}")
        log "id2 is $id2"

        cmd="dicom_hdr -slice_times ${dcm_file}"  
        log $cmd
        out=`$cmd` 
        echo $out
        st=`echo $out | awk -F':' '{ print $2}'`
        echo $st
        starr=( $st )    

        echo ${#starr[@]}

        printf "%f\n" "${starr[@]}" > "${EPIpath}/temp.txt"                    
                            
        while IFS= read -r num; do
            val=$(bc <<< "scale=8 ; $num / 1000")
            val2=$(bc <<< "scale=8 ; $val / $TR")
            echo $val2
        done < "${EPIpath}/temp.txt"  > "${EPIpath}/slicetimes_frac.txt"

        rm -vf "${EPIpath}/temp.txt"

        cmd="${EXEDIR}/src/scripts/extract_slice_time.sh $EPIpath ${starr[@]}" # -d ${PWD}/inputdata/dwi.nii.gz \
        echo $cmd
        eval $cmd

        dcm_file=${dicom_files[0]}
        cmd="dicom_hinfo -tag 0018,0081 ${dcm_file}"
        log $cmd
        out=`$cmd`
        TE=`echo $out | awk -F' ' '{ print $2}'`
        echo "HEADER extracted TE is: ${TE}" 
        echo "export TE=${TE}" >> ${EPIpath}/0_param_dcm_hdr.sh

        ## GRAPPA acceleration factor could be used in conjunction with BWPPE   
        cmd="dicom_hinfo -tag 0051,1011 ${dcm_file}"
        log $cmd
        out=`$cmd`
        GRAPPAacc=`echo $out | awk -F' ' '{ print $2}'`
        echo "HEADER extracted Acceleration factor is: ${GRAPPAacc}" 
        echo "export GRAPPAacc=${GRAPPAacc}" >> ${EPIpath}/0_param_dcm_hdr.sh


        cmd="mrinfo -quiet -property TotalReadoutTime ${dcm_file}"
        log $cmd
        out=`$cmd`
        TotalReadoutTime=`echo $out | awk -F' ' '{ print $1}'`
        echo "HEADER extracted TotalReadoutTime is: ${TotalReadoutTime}" 
        echo "export TotalReadoutTime=${TotalReadoutTime}" >> ${EPIpath}/0_param_dcm_hdr.sh


        cmd="dicom_hinfo -tag 0051,100b ${dcm_file}"
        log $cmd
        out=`$cmd`
        MATSIZPHASE=`echo $out | awk '{ print $2}' | sed 's/*.*//'` 
        echo "HEADER extracted MATSIZPHASE is: ${MATSIZPHASE}" 
        echo "export MATSIZPHASE=${MATSIZPHASE}" >> ${EPIpath}/0_param_dcm_hdr.sh

        if [ "${MATSIZPHASE}" -ge "2" ]; then
            MSP=$(bc <<< "scale=4 ; $MATSIZPHASE - 1") 
            EPI_EffectiveEchoSpacing=$(bc <<< "scale=4 ; $TotalReadoutTime / $MSP")
            echo "CALCULATED EffectiveEchoSpacing is: ${EPI_EffectiveEchoSpacing}" 
            echo "export EPI_EffectiveEchoSpacing=${EPI_EffectiveEchoSpacing}" >> ${EPIpath}/0_param_dcm_hdr.sh
        else
            log "WARNING EffectiveEchoSpacing could not be calculated! ${MATSIZPHASE} < 2"
            exit 1
        fi

    fi

    #-------------------------------------------------------------------------%
    # Config params are all saved in ${EPIpath}/0_param_dcm_hdr.sh     
    log "Config params are saved in ${EPIpath}/0_param_dcm_hdr.sh"      



    # ##esp

# dcm_file=${dicom_files[0]}
# cmd="dicom_hinfo -tag 0043,102c ${dcm_file}"
# log $cmd
# out=`$cmd`
# esp=`echo $out | awk -F' ' '{ print $2}'`
# echo "Header extracted TE is: ${esp}" 
# echo "export esp=${esp}" >> ${EPIpath}/0_param_dcm_hdr.sh

# ## asset
# cmd="dicom_hinfo -tag 0043,1083 ${dcm_file}"                    
# log $cmd 
# out=`$cmd`                
# asset=`echo $out | awk -F' ' '{ print $2}'`
# echo "Header extracted asset is: ${asset}" 
# echo "export asset=${asset}" >> ${EPIpath}/0_param_dcm_hdr.sh
