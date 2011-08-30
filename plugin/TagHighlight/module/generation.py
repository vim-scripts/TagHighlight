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
import re
from .utilities import GenerateValidKeywordRange, IsValidKeyword
from .debug import Debug

vim_synkeyword_arguments = [
        'contains',
        'oneline',
        'fold',
        'display',
        'extend',
        'contained',
        'containedin',
        'nextgroup',
        'transparent',
        'skipwhite',
        'skipnl',
        'skipempty'
        ]

def CreateTypesFile(options, language, tags):
    tag_types = list(tags.keys())
    tag_types.sort()

    Debug("Writing types file", "Information")

    language_handler = options['language_handler'].GetLanguageHandler(language)

    if options['check_keywords']:
        iskeyword = GenerateValidKeywordRange(language_handler['IsKeyword'])
        Debug("Is Keyword is {0!r}".format(iskeyword), "Information")

    matchEntries = set()
    vimtypes_entries = []


    typesUsedByLanguage = list(options['language_handler'].GetKindList(language).values())
    # TODO: This may be included elsewhere, but we'll leave it in for now
    #clear_string = 'silent! syn clear ' + " ".join(typesUsedByLanguage)

    vimtypes_entries = []
    #vimtypes_entries.append(clear_string)

    # Get the priority list from the language handler
    priority = language_handler['Priority'][:]
    # Reverse the priority such that highest priority
    # is last.
    priority.reverse()

    fullTypeList = list(reversed(sorted(tags.keys())))
    # Reorder type list according to priority sort order
    allTypes = []
    for thisType in priority:
        if thisType in fullTypeList:
            allTypes.append(thisType)
            fullTypeList.remove(thisType)
    # Add the ones not specified in priority
    allTypes = fullTypeList + allTypes

    Debug("Type priority list: " + repr(allTypes), "Information")

    patternREs = []
    for pattern in options['skip_patterns']:
        patternREs.append(re.compile(pattern))

    for thisType in allTypes:
        keystarter = 'syn keyword ' + thisType
        keycommand = keystarter
        for keyword in tags[thisType]:
            skip_this = False
            for pattern in patternREs:
                if pattern.search(keyword) != None:
                    skip_this = True
                    break
            if skip_this:
                continue

            if options['check_keywords']:
                # In here we should check that the keyword only matches
                # vim's \k parameter (which will be different for different
                # languages).  This is quite slow so is turned off by
                # default; however, it is useful for some things where the
                # default generated file contains a lot of rubbish.  It may
                # be worth optimising IsValidKeyword at some point.
                if not IsValidKeyword(keyword, iskeyword):
                    matchDone = False
                    if options['include_matches']:

                        patternCharacters = "/@#':"
                        charactersToEscape = '\\' + '~[]*.$^'

                        for patChar in patternCharacters:
                            if keyword.find(patChar) == -1:
                                escapedKeyword = keyword
                                for ch in charactersToEscape:
                                    escapedKeyword = escapedKeyword.replace(ch, '\\' + ch)
                                if options['include_matches']:
                                    matchEntries.add('syn match ' + thisType + ' ' + patChar + escapedKeyword + patChar)
                                matchDone = True
                                break

                    if not matchDone:
                        Debug("Skipping keyword '" + keyword + "'", "Information")

                    continue


            if keyword.lower() in vim_synkeyword_arguments:
                if not options['skip_vimkeywords']:
                    matchEntries.add('syn match ' + thisType + ' /' + keyword + '/')
                continue

            temp = keycommand + " " + keyword
            if len(temp) >= 512:
                vimtypes_entries.append(keycommand)
                keycommand = keystarter
            keycommand = keycommand + " " + keyword
        if keycommand != keystarter:
            vimtypes_entries.append(keycommand)

    # Sort the matches
    matchEntries = sorted(list(matchEntries))

    if (len(matchEntries) + len(vimtypes_entries)) == 0:
        # All keywords have been filtered out, give up
        return

    vimtypes_entries.append('')
    vimtypes_entries += matchEntries

    if options['include_locals']:
        LocalTagType = ',CTagsLocalVariable'
    else:
        LocalTagType = ''

    if options['types_file_name_override'] is not None and options['types_file_name_override'] != 'None':
        type_file_name = options['types_file_name_override']
    else:
        type_file_name = options['types_file_prefix'] + '_' + language_handler['Suffix'] + '.' + options['types_file_extension']
    filename = os.path.join(options['types_file_location'], type_file_name)
    Debug("Filename is {0}\n".format(filename), "Information")

    try:
        # Have to open in binary mode as we want to write with Unix line endings
        # The resulting file will then work with any Vim (Windows, Linux, Cygwin etc)
        fh = open(filename, 'wb')
    except IOError:
        Debug("ERROR: Couldn't create {file}\n".format(file=outfile), "Error")
        sys.exit(1)

    try:
        for line in vimtypes_entries:
            try:
                fh.write(line.encode('ascii'))
            except UnicodeDecodeError:
                Debug("Error decoding line '{0!r}'".format(line), "Error")
                fh.write('echoerr "Types generation error"\n'.encode('ascii'))
            fh.write('\n'.encode('ascii'))
    except IOError:
        Debug("ERROR: Couldn't write {file} contents\n".format(file=outfile), "Error")
        sys.exit(1)
    finally:
        fh.close()
