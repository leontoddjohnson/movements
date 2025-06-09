import os
from glob import glob
import sys

def ableton_rename(fpath,
                   name_by='row',
                   ftype='wav',
                   num_suffix=True):
    '''    
    num_suffix : bool
        True ==> "violin_1" is a different instrument from "violin_2"

    name_by : str
        'row' ==> each row is a different instrument
        'col' ==> each column is a different instrument
        'bank' ==> just number up to 32
    '''
    # initiate
    fpath = fpath + "/"
    rowcol = 0
    counter = 1
    inst_prev = ''
    change_names = input("Change file names? (Requires 'Yes')")

    if name_by == 'row':
        max_i = 8
    elif name_by == 'col':
        max_i = 4
    else:
        max_i = 32

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
            counter = 1
            rowcol += 1
        else:
            counter += 1

        # skip samples past the max column
        if counter > max_i:
            print(f"{inst} ... {fname} --> PAST LIMIT")
            continue

        # newname
        if name_by == 'row':
            new_name = str(rowcol) + str(counter) + ' ' + fname_.strip() + "." + ftype
        elif name_by == 'col':
            new_name = str(counter) + str(rowcol) + ' ' + fname_.strip() + "." + ftype
        else:
            new_name = str(counter).zfill(3) + ' ' + fname_.strip() + "." + ftype

        # change names
        if change_names == 'Yes':
            os.rename(fpath + fname, fpath + new_name)  ## TEST FIRST

        print(f"{inst} ... {fname} --> {new_name}")

        # new previous
        inst_prev = inst
        
    return None


if __name__ == "__main__": 
    if len(sys.argv) < 2:
        print("Usage: python filenaming.py <filepath> [name_by] [filetype]")
    else:
        filepath = sys.argv[1]
        name_by = sys.argv[2] if len(sys.argv) > 2 else 'row'
        filetype = sys.argv[3] if len(sys.argv) > 3 else 'wav'
        ableton_rename(filepath, name_by, filetype, num_suffix=True)