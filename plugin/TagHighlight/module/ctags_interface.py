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
import subprocess
import os
import re
import glob
from .utilities import DictDict
from .languages import Languages
from .debug import Debug

field_processor = re.compile(
r'''
    ^                 # Start of the line
    (?P<keyword>.*?)  # Capture the first field: everything up to the first tab
    \t                # Field separator: a tab character
    .*?               # Second field (uncaptured): everything up to the next tab
    \t                # Field separator: a tab character
    (?P<search>.*?)   # Any character at all, but as few as necessary (i.e. catch everything up to the ;")
    ;"                # The end of the search specifier (see http://ctags.sourceforge.net/FORMAT)
    (?=\t)            # There MUST be a tab character after the ;", but we want to match it with zero width
    .*\t              # There can be other fields before "kind", so catch them here.
                      # Also catch the tab character from the previous line as there MUST be a tab before the field
    (kind:)?          # This is the "kind" field; "kind:" is optional
    (?P<kind>\w)      # The kind is a single character: catch it
    (\t|$)            # It must be followed either by a tab or by the end of the line
    .*                # If it is followed by a tab, soak up the rest of the line; replace with the syntax keyword line
''', re.VERBOSE)
field_const = re.compile(r'\bconst\b')

def GenerateTags(options):
    Debug("Generating Tags", "Information")

    args = GetCommandArgs(options)

    os.chdir(options['source_root'])

    ctags_cmd = [options['ctags_exe_full']] + args

    #subprocess.call(" ".join(ctags_cmd), shell = (os.name != 'nt'))
    # shell=True stops the command window popping up
    # We don't use stdin, but have to define it in order
    # to get round python bug 3905
    # http://bugs.python.org/issue3905
    process = subprocess.Popen(ctags_cmd,
            stdin=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdout=subprocess.PIPE
            )#, shell=True)
    (sout, serr) = process.communicate()

    tagFile = open(os.path.join(options['ctags_file_dir'], options['ctags_file']), 'r')
    tagLines = [line.strip() for line in tagFile]
    tagFile.close()

    # Also sort the file a bit better (tag, then kind, then filename)
    tagLines.sort(key=ctags_key)

    tagFile = open(os.path.join(options['ctags_file_dir'],options['ctags_file']), 'w')
    for line in tagLines:
        tagFile.write(line + "\n")
    tagFile.close()

def ParseTags(options):
    """Function to parse the tags file and generate a dictionary containing language keys.

    Each entry is a list of tags with all the required details.
    """
    languages = options['language_handler']
    kind_list = languages.GetKindList()

    # Language: {Type: set([keyword, keyword, keyword])}
    ctags_entries = DictDict()

    lineMatchers = {}
    for key in languages.GetAllLanguages():
        lineMatchers[key] = re.compile(
                r'^.*?\t[^\t]*\.(?P<extension>' +
                languages.GetLanguageHandler(key)['PythonExtensionMatcher'] +
                ')\t')

    p = open(os.path.join(options['ctags_file_dir'],options['ctags_file']), 'r')
    while 1:
        try:
            line = p.readline()
        except UnicodeDecodeError:
            continue
        if not line:
            break

        for key, lineMatcher in list(lineMatchers.items()):
            if lineMatcher.match(line):
                # We have a match
                m = field_processor.match(line.strip())
                if m is not None:
                    try:
                        short_kind = 'ctags_' + m.group('kind')
                        kind = kind_list[key][short_kind]
                        keyword = m.group('keyword')
                        if options['parse_constants'] and \
                                (key == 'c') and \
                                (kind == 'CTagsGlobalVariable'):
                            if field_const.search(m.group('search')) is not None:
                                kind = 'CTagsConstant'
                        if short_kind not in languages.GetLanguageHandler(key)['SkipList']:
                            ctags_entries[key][kind].add(keyword)
                    except KeyError:
                        Debug("Unrecognised kind '{kind}' for language {language}".format(kind=m.group('kind'), language=key), "Error")
    p.close()

    return ctags_entries

def GetCommandArgs(options):
    args = []

    ctags_languages = [l['CTagsName'] for l in options['language_handler'].GetAllLanguageHandlers()]
    if 'c' in ctags_languages:
        ctags_languages.append('c++')
    args += ["--languages=" + ",".join(ctags_languages)]

    if options['ctags_file']:
        args += ['-f', os.path.join(options['ctags_file_dir'], options['ctags_file'])]

    if not options['include_docs']:
        args += ["--exclude=docs", "--exclude=Documentation"]

    if options['include_locals']:
        Debug("Including local variables in tag generation", "Information")
        kinds = options['language_handler'].GetKindList()
        def FindLocalVariableKinds(language_kinds):
            """Finds the key associated with a value in a dictionary.

            Assumes presence has already been checked."""
            Debug("Finding local variable types from " + repr(language_kinds), "Information")
            return "".join(key[-1] for key,val in language_kinds.items() if val == 'CTagsLocalVariable')

        for language in ctags_languages:
            if language in kinds and 'CTagsLocalVariable' in kinds[language].values():
                Debug("Finding local variables for " + language, "Information")
                args += ['--{language}-kinds=+{kind}'.format(language=language,
                    kind=FindLocalVariableKinds(kinds[language]))]
            else:
                Debug("Skipping language: " + language, "Information")

    # Must be last as it includes the file list:
    if options['recurse']:
        args += ['--recurse']
        args += ['.']
    else:
        args += glob.glob(os.path.join(options['source_root'],'*'))

    Debug("Command arguments: " + repr(args), "Information")

    return args

key_regexp = re.compile('^(?P<keyword>.*?)\t(?P<remainder>.*\t(?P<kind>[a-zA-Z])(?:\t|$).*)')

def ctags_key(ctags_line):
    match = key_regexp.match(ctags_line)
    if match is None:
        return ctags_line
    return match.group('keyword') + match.group('kind') + match.group('remainder')
