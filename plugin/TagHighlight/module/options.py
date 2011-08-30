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
from .config import config
import os
from .loaddata import LoadDataFile

AllOptions = {}

def LoadOptionSpecification():
    ListKeys = ['CommandLineSwitches']
    RequiredKeys = ['CommandLineSwitches', 'Type', 'Default', 'Help']

    global AllOptions
    AllOptions = LoadDataFile('options.txt', ListKeys)

    for dest in AllOptions.keys():
        # Check we've got all of the required keys
        for key in RequiredKeys:
            if key not in AllOptions[dest]:
                if 'VimOptionMap' in AllOptions[dest]:
                    # This is probably just a Vim option: ignore
                    pass
                else:
                    raise Exception("Missing option {key} in option {dest}".format(key=key,dest=dest))
        # Handle special types of options
        if AllOptions[dest]['Type'] == 'bool':
            if AllOptions[dest]['Default'] == 'True':
                AllOptions[dest]['Default'] = True
            else:
                AllOptions[dest]['Default'] = False
        elif AllOptions[dest]['Type'] == 'list':
            if AllOptions[dest]['Default'] == '[]':
                AllOptions[dest]['Default'] = []
            else:
                AllOptions[dest]['Default'] = AllOptions[dest]['Default'].split(',')

LoadOptionSpecification()
