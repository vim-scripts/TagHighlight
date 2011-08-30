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

debug_log_levels = ('Critical', 'Error', 'Warning', 'Status', 'Information', 'None')
debug_log_file = None
debug_log_level = 'None'

def SetDebugLogFile(filename):
    global debug_log_file
    debug_log_file = filename

def SetDebugLogLevel(level):
    global debug_log_level
    debug_log_level = level

def Debug(msg, level):
    if level not in debug_log_levels:
        raise Exception("Invalid log level: " + level)
    this_index = debug_log_levels.index(level)
    current_index = debug_log_levels.index(debug_log_level)

    if this_index > current_index:
        return

    if debug_log_file is None:
        print(msg)
    else:
        fh = open(debug_log_file, 'a')
        fh.write(msg)
        fh.write("\n")
        fh.close()
