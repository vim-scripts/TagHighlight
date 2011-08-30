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
import os
import glob

from .config import config
from .loaddata import LoadDataFile, LoadFile, GlobData
from .debug import Debug

class Languages():
    registry = {}

    def __init__(self, options):
        self.options = options
        self.kinds = None

        language_list_entries = ['SkipList','Priority']

        # Import language specific modules: this will make them be parsed
        # and will add to the registry
        self.defaults = LoadDataFile('language_defaults.txt', language_list_entries)

        for language_file in GlobData('languages/*.txt'):
            language_dict = LoadDataFile(language_file, language_list_entries)
            language_dict['Filename'] = language_file
            language_dict = self.VerifyLanguage(language_dict)
            self.registry[language_dict['FriendlyName']] = language_dict

    def ReadConfigFile(self, filename):
        result = {}
        fh = open(filename, 'r')
        list_entries = ['SkipList','Priority']
        key = None
        for line in fh:
            if line.strip().endswith(':') and line[0] not in [' ','\t',':','#']:
                key = line.strip()[:-1]
                result[key] = []
            elif key is not None and line.startswith('\t'):
                result[key] += [line.strip()]
            elif ':' in line and line[0] not in [' ','\t',':','#']:
                # End of the previous list, so reset key
                key = None
                parts = line.strip().split(':',1)
                if parts[0] in list_entries:
                    if ',' in parts[1]:
                        result[parts[0]] = parts[1].split(',')
                    else:
                        result[parts[0]] = [parts[1]]
                else:
                    result[parts[0]] = parts[1]
        fh.close()
        return result

    def VerifyLanguage(self, language_dict):
        required_keys = [
                'FriendlyName',
                'CTagsName',
                'PythonExtensionMatcher',
                'VimExtensionMatcher',
                'Suffix',
                'SkipList',
                'IsKeyword',
                'Priority',
                ]
        for key in required_keys:
            if key not in language_dict:
                if key in self.defaults:
                    language_dict[key] = self.defaults[key]
                else:
                    raise Exception("Language data from file {filename} is " \
                            "missing required key {key} (no default " \
                            "available).".format(filename=language_dict['Filename'],
                                key=key))
        return language_dict

    def GetAllLanguages(self):
        return list(self.registry.keys())

    def GetAllLanguageHandlers(self):
        return list(self.registry.values())

    def GetLanguageHandler(self, name):
        return self.registry[name]

    def GenerateExtensionTable(self):
        results = {}
        for handler in list(self.registry.values()):
            extensions = handler.GetVimMatcher()
            suffix = handler.GetSuffix()
            results[extensions] = suffix
        return results

    def GenerateFullKindList(self):
        self.LoadKindList()
        kinds = set()
        for language in list(self.kinds.keys()):
            kinds |= set(self.kinds[language].values())
        return sorted(list(kinds))

    def GetKindList(self, language=None):
        """Explicit list of kinds exported from ctags help."""
        if self.kinds is None:
            kind_import = LoadDataFile('kinds.txt')
            # Generate the kind database with 'ctags_' prefix on the keys
            self.kinds = {}
            for key in kind_import:
                self.kinds[key] = {}
                for kind in kind_import[key]:
                    self.kinds[key]['ctags_'+kind] = kind_import[key][kind]

        if language is None:
            return self.kinds
        elif language in self.kinds:
            return self.kinds[language]
        else:
            return None

