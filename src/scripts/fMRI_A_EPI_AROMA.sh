
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

##############################################################################


echo "# =========================================================="
echo "# 5.1 ICA-AROMA: Denoising. "
echo "# =========================================================="

if [[ ! -e "${EPIpath}/4_epi.nii.gz" ]]; then  

    log "WARNING File ${EPIpath}/4_epi.nii.gz does not exist. Skipping further analysis"
    exit 1 
fi 

AROMApath="${EPIpath}/AROMA"

if [[ -d "${AROMApath}" ]]; then
    # rename existing directory before creating a new one
    today=$(date +"%m_%d_%Y_%H_%M")
    cmd="mv ${AROMApath} ${AROMApath}_${today}"
    log $cmd
    eval $cmd
fi

cmd="mkdir ${AROMApath}"
log "AROMA - creating directory"
log $cmd
eval $cmd

AROMAreg_path="${AROMApath}/registration"
cmd="mkdir ${AROMAreg_path}"
log "AROMAreg - creating directory"
log $cmd
eval $cmd 

echo "## Generating Inputs"
echo "#### EPI to T1 linear transform"

fileMat="${EPIpath}/epi_2_T1_bbr_dof6.mat"
if [[ ! -e "${fileMat}" ]]; then
    log "WARNING Linear EPI -> T1 transformation not found. Please set the flag flags_EPI_RegT1=true"
    exit 1
fi 

echo "#### T1 to MNI 2mm nonlinear transform"

fileT1="${T1path}/T1_brain.nii"
fileMNI2mm="${pathFSLstandard}/MNI152_T1_2mm_brain.nii.gz"
filedof12mat="${AROMAreg_path}/T1_2_MNI2mm_dof12.mat"
filedof12img="${AROMAreg_path}/rT1_dof12_2mm.nii.gz"


cmd="flirt -in ${fileT1} \
-ref ${fileMNI2mm} \
-omat ${filedof12mat} \
-dof 12 -cost mutualinfo \
-interp spline -out ${filedof12img}"
log $cmd
eval $cmd 


fileWarpImg="${AROMAreg_path}/rT1_warped_2mm.nii.gz"
fileWarpField="${AROMAreg_path}/T1_2_MNI2mm_warpfield.nii.gz" 

cmd="fnirt \
--in=${fileT1} \
--ref=${fileMNI2mm} \
--aff=${filedof12mat} \
--iout=${fileWarpImg} \
--cout=${fileWarpField}"
log $cmd
eval $cmd 

# 6mm FWHM EPI data smoothing
echo "### Smoothing EPI data by 6mm FWHM"
fileEPI="${EPIpath}/4_epi.nii.gz"
fileSmooth="${AROMApath}/s6_4_epi.nii.gz" 

cmd="fslmaths ${fileEPI} \
-kernel gauss 2.547965400864057 \
-fmean ${fileSmooth}"
log $cmd
eval $cmd 


# mcFLIRT realignment parameters 
echo "#### mcFLIRT realignment parameters"

fileMovePar="${EPIpath}/motion.txt"
if [[ ! -e "${fileMovePar}" ]]; then
    log "WARNING Movement parameters from mcFLIRT not found. \
    Please set the flag flags_EPI_MotionCorr=true. Exiting..."
    exit 1
fi 

echo "## Starting ICA-AROMA"

AROMAout="${AROMApath}/AROMA-output"

if [[ -d "${AROMAout}" ]]; then
    cmd="rm -rf ${AROMAout}"
    log $cmd
    eval $cmd     
fi

# set number of components if user doesn't want automatic estimation
if [[ ! -z "${flag_AROMA_dim}" ]]; then

    re='^[0-9]+$'

    if [[ ${flag_AROMA_dim} =~ $re ]] ; then  # check that it is a number 
        AROMA_dim="-dim ${flag_AROMA_dim}"
    else
        log "WARNING flag_AROMA_dim should be a number; running AROMA with automatic estimation of number of components"
        AROMA_dim=" "
    fi
else
    AROMA_dim=" "
fi 

cmd="${run_ICA_AROMA} \
-in ${fileSmooth} \
-out ${AROMAout} \
-mc ${fileMovePar} \
-affmat ${fileMat} \
-warp ${fileWarpField} ${AROMA_dim}"
log $cmd 
out=`$cmd`
log "$out"

if [[ ! -e "${AROMAout}/denoised_func_data_nonaggr.nii.gz" ]]; then

    echo "# WARNING AROMA output file not found! Exiting..."
    echo "# Posible causes of failure:"
    echo "    - Files are not in AROMA directoy, but in melodic ICA direcotry"
    echo "    - There are too many components and AROMA did not filter porperly. If this is the case then fslfilt can be ran manually. "

else
    echo "### ICA-AROMA Done."
fi 


# compute percent variance removed from the data
ICstats="${AROMAout}/melodic.ica/melodic_ICstats"
motionICs="${AROMAout}/classified_motion_ICs.txt"

cmd="python ${EXEDIR}/src/func/percent_variance.py \
    ${ICstats} ${motionICs}"
log $cmd
eval $cmd