
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

function demean_detrend() {
fileIn="$1" fileOut="$2" python - <<END
import os
import nibabel as nib
import numpy as np
from scipy import signal
from scipy.io import savemat


fileIn=os.environ['fileIn']
fileOut=os.environ['fileOut']

dvars_scrub=os.environ['flags_EPI_DVARS']
print("dvars_scrub ", dvars_scrub)

# with load(fileIn) as data:
data = np.load(fileIn)
resid=data['resid']
print("loading resid_DVARS for Demean and Detrend")

volBrain_vol=data['volBrain_vol']

resting_vol=data['resting_vol']
print("resting_vol.shape: ",resting_vol.shape)
[sizeX,sizeY,sizeZ,numTimePoints] = resting_vol.shape


# demean and detrend

print("len(resid): ",len(resid))
print("resid.shape: ",resid.shape)


for pc in range(0,len(resid)):
    for i in range(0,sizeX):
        for j in range(0,sizeY):
            for k in range(0,sizeZ):
                if volBrain_vol[i,j,k] > 0:
                    TSvoxel = resid[pc][i,j,k,:].reshape(numTimePoints,1)
                    #TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),type='linear')
                    TSvoxel_detrended = signal.detrend(TSvoxel-np.mean(TSvoxel),axis=0,type='linear')
                    resid[pc][i,j,k,:] = TSvoxel_detrended.reshape(1,1,1,numTimePoints)
                # else:
                #     resid[pc][i,j,k,:] = np.zeros((1,1,1,numTimePoints));
        if i % 25 == 0:
            print(i/sizeX)  ## change this to percentage progress 
    
    # zero-out voxels that are outside the GS mask
    for t in range(0,numTimePoints):
        rv = resid[pc][:,:,:,t]
        rv[volBrain_vol==0]=0
        resid[pc][:,:,:,i] = rv


## save data 
ff = ''.join([fileOut,'.npz'])
np.savez(ff,resid=resid)
print("Saved demeaned and detrended residuals")

ff = ''.join([fileOut,'.mat'])
print("savign MATLAB file ", ff)
mdic = {"resid" : resid}
savemat(ff, mdic)

END
}


###################################################################################


log "# =========================================================="
log "# 6. Demean and Detrend. "
log "# =========================================================="


PhReg_path="${EPIpath}/${regPath}"
fileIn="${PhReg_path}/NuisanceRegression_${nR}.npz"
fileOut="${PhReg_path}/NuisanceRegression_${nR}_dmdt"

if [[ ! -e "${fileIn}" ]]; then  
    log " WARNING ${fileIn} not found. Exiting..."
    exit 1    
fi 

# read data, demean and detrend
log "demean_detrend ${fileIn} ${fileOut}"
demean_detrend ${fileIn} ${fileOut}





