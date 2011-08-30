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
import sys
import os

from optparse import Values
from .utilities import TagHighlightOptionDict
from .loaddata import LoadFile, LoadDataFile, SetLoadDataDirectory
from .debug import SetDebugLogFile, SetDebugLogLevel, Debug

config = TagHighlightOptionDict()

def SetDataDirectories():
    global config
    if hasattr(sys, 'frozen'):
        # Compiled variant, executable should be in
        # plugin/TagHighlight/Compiled/Win32, so data
        # is in ../../data relative to executable
        config['data_directory'] = os.path.abspath(
                os.path.join(os.path.dirname(sys.executable),
                '../../data'))
        config['version_info_dir'] = os.path.abspath(os.path.dirname(sys.executable))
    else:
        # Script variant: this file in
        # plugin/TagHighlight/module, so data is in
        # ../data relative to this file
        config['data_directory'] = os.path.abspath(
                os.path.join(os.path.dirname(__file__),
                '../data'))
        config['version_info_dir'] = config['data_directory']

    SetLoadDataDirectory(config['data_directory'])

    if not os.path.exists(config['data_directory']):
        raise IOError("Data directory doesn't exist, have you installed the main distribution?")

def LoadVersionInfo():
    global config
    data = LoadDataFile('release.txt')
    config['release'] = data['release']

    try:
        config['version'] = LoadFile(os.path.join(config['version_info_dir'],'version_info.txt'))
    except IOError:
        config['version'] = {
                'clean': 'Unreleased',
                'date': 'Unreleased',
                'revision_id': 'Unreleased',
                }

def SetInitialOptions(new_options):
    global config
    for key in new_options:
        config[key] = new_options[key]
    if 'debug_level' in config:
        SetDebugLogLevel(config['debug_level'])
    if 'debug_file' in config:
        SetDebugLogFile(config['debug_file'])

def LoadLanguages():
    global config
    if 'language_handler' in config:
        return
    from .languages import Languages
    config['language_handler'] = Languages(config)

    full_language_list = config['language_handler'].GetAllLanguages()
    if len(config['languages']) == 0:
        # Include all languages
        config['language_list'] = full_language_list
    else:
        config['language_list'] = [i for i in full_language_list if i in config['languages']]
    Debug("Languages:\n\t{0!r}\n\t{1!r}".format(full_language_list, config['language_list']), "Information")

SetDataDirectories()
LoadVersionInfo()
