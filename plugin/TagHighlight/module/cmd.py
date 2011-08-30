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
import optparse

from .config import SetInitialOptions, LoadLanguages
from .options import AllOptions

def ProcessCommandLine():
    parser = optparse.OptionParser()

    for dest in AllOptions.keys():
        if 'CommandLineSwitches' not in AllOptions[dest]:
            # Vim-only option
            continue
        if AllOptions[dest]['Type'] == 'bool':
            if AllOptions[dest]['Default'] == True:
                action = 'store_false'
            else:
                action = 'store_true'
            parser.add_option(*AllOptions[dest]['CommandLineSwitches'],
                    action=action,
                    default=AllOptions[dest]['Default'],
                    dest=dest,
                    help=AllOptions[dest]['Help'])
        else:
            optparse_type='string'
            if AllOptions[dest]['Type'] in ['string', 'int']:
                action='store'
            elif AllOptions[dest]['Type'] == 'list':
                action='append'
            else:
                raise Exception('Unrecognised option type: ' + AllOptions[dest]['Type'])
            parser.add_option(*AllOptions[dest]['CommandLineSwitches'],
                    action=action,
                    default=AllOptions[dest]['Default'],
                    type=optparse_type,
                    dest=dest,
                    help=AllOptions[dest]['Help'])

    options, remainder = parser.parse_args()

    return vars(options)
