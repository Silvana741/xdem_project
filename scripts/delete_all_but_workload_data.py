#!/usr/bin/env python3
import h5py  # installed from package manager
import sys
import os
import shutil
from contextlib import suppress

def main():
    
    # Check parameter
    if len(sys.argv) != 2:
        print("ONE argument required! Exit!\n")
        sys.exit(1)

    input_filename = sys.argv[1]
    if not input_filename.endswith('.h5'):
        #print "Bad filename!"
        sys.exit(1)
    
    # Prepare input file
    print("Processing file: ", input_filename)
    input_hdf5_file = h5py.File(input_filename, 'a')   # 'a' means that hdf5 file is open in append mode

    # only for rank-0
    try:
        del input_hdf5_file['/INPUT']
    except:
        pass

    # only for rank-0
    try:
        del input_hdf5_file['/OUTPUT/GLOBAL/DOMAINGRID']
    except:
        pass

    # for all ranks
    del input_hdf5_file['/OUTPUT/INTERACTION_BONDS']
    del input_hdf5_file['/OUTPUT/PILE1_Particles']
    del input_hdf5_file['/OUTPUT/PILE2_blastFurnace']
    del input_hdf5_file['/OUTPUT/PILE3_chute']
    del input_hdf5_file['/OUTPUT/PILE4_rectangularHopper']
    del input_hdf5_file['/OUTPUT/particle_pile_connectivity']

    input_hdf5_file.close()           


if __name__=="__main__":
	main()



