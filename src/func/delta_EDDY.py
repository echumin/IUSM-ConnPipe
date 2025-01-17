import sys
import os
import nibabel as nib
import numpy as np

path_DWI_EDDY=os.environ['path_DWI_EDDY']
print('path_DWI_EDDY',path_DWI_EDDY)
DWIpath=os.environ['DWIpath']
print('DWIpath',DWIpath)
fileOut=sys.argv[1]
print('fileOut',fileOut)
dwifile=sys.argv[2]
print('dwifile',dwifile)

fname=''.join([DWIpath,'/',dwifile,'.nii.gz'])
print('DWI file is:', fname)
DWI=nib.load(fname)  
DWI_vol = DWI.get_data()

fname=''.join([fileOut,'.nii.gz'])
print('corrDWI file is:', fname)
corrDWI=nib.load(fname)
corrDWI_vol = corrDWI.get_data()

corrDWI_vol = corrDWI_vol - DWI_vol

deltaEddy = ''.join([path_DWI_EDDY,'/delta_DWI.nii.gz'])
corrDWI_new = nib.Nifti1Image(corrDWI_vol.astype(np.float32),corrDWI.affine,corrDWI.header)
nib.save(corrDWI_new,deltaEddy)
