
#!/bin/bash
#
# Script: DWI_A adaptaion from Matlab script 
#

###############################################################################
#
# Environment set up
#
###############################################################################

shopt -s nullglob # No-match globbing expands to null

source ${EXEDIR}/src/func/bash_funcs.sh

###############################################################################

if [[ -d ${DWIpath} ]]; then

    log "DWI_B processing for subject ${SUBJ}"

    # if two DICOM directories exist 
    if [[ ! -z "${configs_DWI_dcmFolder1}" ]] && [[ ! -z "${configs_DWI_dcmFolder2}" ]]; then

        DWIdir1="${DWIpath}/${configs_DWI_dcmFolder1}"
        DWIdir2="${DWIpath}/${configs_DWI_dcmFolder2}"

        if [[ -d "${DWIdir1}" ]] && [[ -d "${DWIdir2}" ]]; then
            export nscanmax=2 # DWI acquired in two phase directions (e.g., AP and PA)
        else
            log "WARNING ${DWIdir1} and/or ${DWIdir2} not found!. Exiting..."
            exit 1
        fi 
    else
        DWIdir1="${DWIpath}/${configs_DWI_dcmFolder}"

        if [[ -d "${DWIdir1}" ]]; then
            export nscanmax=1 
        else
            log "WARNING ${DWIdir1} not found!. Exiting..."
            exit 1
        fi 
    fi 

    log "Number of scans is ${nscanmax}"

    for ((nscan=1; nscan<=nscanmax; nscan++)); do  #1 or 2 DWI scans
    
        # set paths
        if [[ "${nscanmax}" -eq "1" ]]; then 
            export path_DWI_EDDY="${DWIpath}/EDDY"
            export path_DWI_DTIfit="${DWIpath}/DTIfit"
            export path_DWI_mrtrix="${DWIpath}/MRtrix"
            export path_DWI_matrices="${DWIpath}/CONNmats"

        elif [[ "${nscanmax}" -eq "2" ]]; then 
            export path_DWI_EDDY="${DWIpath}/EDDY${nscan}"
            export path_DWI_DTIfit="${DWIpath}/DTIfit${nscan}"
            export path_DWI_mrtrix="${DWIpath}/MRtrix${nscan}"
            export path_DWI_matrices="${DWIpath}/CONNmats${nscan}"

        fi 

        if [[ ! -d "${path_DWI_EDDY}" ]]; then
            log "Path to EDDY directory does not exist. Exiting..."
            exit 1
        else 
            if [[ ! -d "${path_DWI_DTIfit}" ]]; then
                log "Path to DTIfit directory does not exist. Exiting..."
                exit 1
            fi
        fi

        #### Registration of B0 to T1
        if ${flags_DWI_regT1_2DWI}; then

            cmd="${EXEDIR}/src/scripts/DWI_B_regT12DWI.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at DWI_B_regT12DWI. exiting."
                exit 1
            fi  
        fi

        #### MRtrix
        if ${flags_DWI_MRtrix}; then

            cmd="${EXEDIR}/src/scripts/DWI_B_MRtrix.sh ${nscan}"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at DWI_B_MRtrix. exiting."
                exit 1
            fi  
        fi

        #### Connectivity Matrix
        if ${flags_DWI_connMatrix}; then

            cmd="${EXEDIR}/src/scripts/DWI_B_connMatrix.sh"
            echo $cmd
            eval $cmd
            exitcode=$?

            if [[ ${exitcode} -ne 0 ]] ; then
                echoerr "problem at DWI_B_connMatrix. exiting."
                exit 1
            fi  
        fi

    done

else 

    log "WARNING Subject DWI directory does not exist; skipping DWI processing for subject ${SUBJ}"

fi 