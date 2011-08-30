#!/usr/bin/env python
# Tag Highlighter:
#   Author:  A. S. Budden <abudden _at_ gmail _dot_ com>
# Copyright: Copyright (C) 2009-2011 A. S. Budden
#            Permission is hereby granted to use and distribute this code,
#            with or without modifications, provided that this copyright
#            notice is copied with it. Like anything else that's free,
#            the TagHighlight plugin is provided *as is* and comes with no
#            warranty of any kind, either expressed or implied. By using
#            this plugin, you agree that in no event will the copyright
#            holder be liable for any damages resulting from the use
#            of this software.

# ---------------------------------------------------------------------
from __future__ import print_function
import os
import glob

data_directory = None

def SetLoadDataDirectory(directory):
    global data_directory
    data_directory = directory

def LoadFile(filename, list_entries=[]):
    results = {}
    fh = open(filename, 'r')
    key = None
    for line in fh:
        if line.strip().endswith(':') and line[0] not in [' ','\t',':','#']:
            key = line.strip()[:-1]
        elif key is not None and line.startswith('\t'):
            if ':' in line:
                # Dict entry, split onto multiple lines
                parts = line.strip().split(':',1)
                if key not in results:
                    results[key] = {}
                elif not isinstance(results[key], dict):
                    raise ValueError("Mixed data types in data file {file} for entry {key}".format(filename, key))
                if parts[0] in list_entries:
                    results[key][parts[0]] = parts[1].split(',')
                else:
                    results[key][parts[0]] = parts[1]
            else:
                # List entry, split onto multiple lines
                if key not in results:
                    results[key] = []
                elif not isinstance(results[key], list):
                    raise ValueError("Mixed data types in data file {file} for entry {key}".format(filename, key))
                results[key].append(line.strip())
        elif ':' in line and line[0] not in [' ','\t',':','#']:
            # End of previous list: was it a real list or
            # an empty entry?
            if key not in results:
                # Empty entry: add as such
                if key in list_entries:
                    results[key] = []
                else:
                    results[key] = ''
            key = None
            parts = line.strip().split(':',1)
            if parts[0] in list_entries:
                # Registered list entry: split on commas
                results[parts[0]] = parts[1].split(',')
            else:
                # Treat as a string
                results[parts[0]] = parts[1]
    return results


def LoadDataFile(relative, list_entries=[]):
    filename = os.path.join(data_directory,relative)
    return LoadFile(filename, list_entries)

def GlobData(matcher):
    files = glob.glob(os.path.join(data_directory, matcher))
    return [os.path.relpath(i,data_directory) for i in files]
