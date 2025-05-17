import os
from glob import glob
import sys

def ableton_rename(fpath,
                   ftype='wav',
                   num_suffix=True,
                   include_row=True,
                   max_col=8,
                   row_start=1,
                   col_start=1):
    '''    
    num_suffix : bool
        True ==> "violin_1" is a different instrument from "violin_2"
    '''
    # initiate
    fpath = fpath + "/"
    row = row_start - 1
    counter = col_start
    inst_prev = ''
    change_names = input("Change file names? (Requires 'Yes')")

    if change_names == 'Yes':
        print("Changing file names!\n")
    else:
        print("NOT changing file names.\n")
        
    crops = sorted(glob(fpath + '*.' + ftype),
               key=lambda s: s.replace('-', ''))
    
    for crop in crops:
        # filename
        fname = crop[crop.rfind('/') + 1:]
        fname_ = fname[:fname.find('[')-1]

        # get instrument name
        if num_suffix:
            inst = ''.join(c for c in fname_ if c.isalnum())
        else:
            inst = ''.join(c for c in fname_ if c.isalpha())

        # row count
        if inst != inst_prev:
            counter = col_start
            row += 1
        else:
            counter += 1

        # skip samples past the max column
        if max_col > 0 and counter > max_col:
            print(f"{inst} ... {fname} --> PAST LIMIT")
            continue

        # newname
        if include_row:
            new_name = str(row) + str(counter) + ' ' + fname_.strip() + "." + ftype
        else:
            new_name = str(counter) + ' ' + fname_.strip() + "." + ftype

        # change names
        if change_names == 'Yes':
            os.rename(fpath + fname, fpath + new_name)  ## TEST FIRST

        print(f"{inst} ... {fname} --> {new_name}")

        # new previous
        inst_prev = inst
        
    return None


if __name__ == "__main__": 
    if len(sys.argv) < 2:
        print("Usage: python filenaming.py <filepath> [filetype]")
    else:
        filepath = sys.argv[1]
        filetype = sys.argv[2] if len(sys.argv) > 2 else 'wav'
        ableton_rename(filepath, filetype, include_row=True)