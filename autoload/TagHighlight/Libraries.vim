" Tag Highlighter:
"   Author:  A. S. Budden <abudden _at_ gmail _dot_ com>
" Copyright: Copyright (C) 2009-2011 A. S. Budden
"            Permission is hereby granted to use and distribute this code,
"            with or without modifications, provided that this copyright
"            notice is copied with it. Like anything else that's free,
"            the TagHighlight plugin is provided *as is* and comes with no
"            warranty of any kind, either expressed or implied. By using
"            this plugin, you agree that in no event will the copyright
"            holder be liable for any damages resulting from the use
"            of this software.

" ---------------------------------------------------------------------
try
	if &cp || (exists('g:loaded_TagHLLibraries') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLLibraries = 1

function! TagHighlight#Libraries#LoadLibraries()
	if has_key(g:TagHighlightPrivate,'Libraries')
		" Already loaded
		return
	endif
	call TagHLDebug("Loading standard library information", "Information")

	let g:TagHighlightPrivate['LibraryPath'] = g:TagHighlightPrivate['PluginPath'] . '/standard_libraries'
	let g:TagHighlightPrivate['Libraries'] = {}
	let library_config_files = split(glob(g:TagHighlightPrivate['LibraryPath'] . '/*/library_types.txt'), '\n')

	let required_keys = ["LibraryName","TypesFiles","CheckMode","TypesSuffixes"]
	for library_config in library_config_files
		call TagHLDebug("Loading information for " . library_config, "Information")
		let skip = 0
		let library_details = TagHighlight#LoadDataFile#LoadFile(library_config)
		for key in required_keys
			if ! has_key(library_details, key)
				call TagHLDebug("Could not load library from " . library_config, "Warning")
				let skip = 1
				break
			endif
		endfor
		if skip
			continue
		endif
		" Config looks valid; check fields that should be lists are:
		let list_keys = ["TypesFiles","TypesSuffixes","MatchREs"]
		for key in list_keys
			if has_key(library_details,key) && type(library_details[key]) == type('')
				let value = library_details[key]
				unlet library_details[key]
				let library_details[key] = [value]
			endif
		endfor
		" Store the absolute path to the all types files
		let library_details['TypesFileFullPaths'] = []
		for types_file in library_details['TypesFiles']
			let library_details['TypesFileFullPaths'] += [fnamemodify(library_config, ':p:h') . '/' . types_file]
		endfor

		" Handle some defaults
		if ! has_key(library_details,'MatchREs')
			" Default matcher will never match on any file
			let library_details['MatchREs'] = ['.\%^']
		endif
		if ! has_key(library_details, 'CustomFunction')
			" Default custom function will always return 'Skip'
			let library_details['CustomFunction'] = 'TagHighlight#Libraries#NeverMatch'
		endif
		if ! has_key(library_details, 'MatchLines')
			" Just use a suitable default value
			let library_details['MatchLines'] = 30
		endif
		
		call TagHLDebug("Loaded library: " . string(library_details), "Information")
		let g:TagHighlightPrivate['Libraries'][library_details['LibraryName']] = library_details
	endfor
endfunction

function! TagHighlight#Libraries#FindUserLibraries()
	" Open any explicitly configured libraries
	call TagHLDebug("Searching for user libraries", "Information")
	let user_library_dir = TagHighlight#Option#GetOption('UserLibraryDir')
	let user_libraries = TagHighlight#Option#GetOption('UserLibraries')

	call TagHLDebug("Library Dir: " . user_library_dir, "Information")
	call TagHLDebug("Library List: " . string(user_libraries), "Information")

	let libraries_to_load = []

	for library in user_libraries
		" If it looks like an absolute path, just load it
		if (library[1] == ':' || library['0'] == '/') && filereadable(library)
			call TagHLDebug("User library is absolute path: " . library, "Information")
			let libraries_to_load +=
						\ [{
						\     'Name': 'User Library',
						\     'Filename': fnamemodify(library, ':t'),
						\     'Path': fnamemodify(library, '%:p'),
						\ }]
		" Otherwise, try appending to the library dir
		elseif filereadable(user_library_dir . '/' . library)
			call TagHLDebug("User library is relative path: " . library, "Information")
			let library_path = user_library_dir . '/' . library
			let libraries_to_load +=
						\ [{
						\     'Name': 'User Library',
						\     'Filename': fnamemodify(library_path, ':t'),
						\     'Path': fnamemodify(library_path, '%:p'),
						\ }]
		else
			TagHLDebug("Cannot load user library " . library, "Error")
		endif
	endfor
	return libraries_to_load
endfunction

function! TagHighlight#Libraries#FindLibraryFiles(suffix)
	" Should only actually read the libraries once
	call TagHLDebug("Finding library files for current file with suffix " . a:suffix, "Information")
	call TagHighlight#Libraries#LoadLibraries()

	let libraries_to_load = []
	let forced_standard_libraries = TagHighlight#Option#GetOption('ForcedStandardLibraries')

	if TagHighlight#Option#GetOption('DisableStandardLibraries')
		call TagHLDebug("Standard library loading disabled", "Information")
		return []
	endif

	for library in values(g:TagHighlightPrivate['Libraries'])
		call TagHLDebug("Checking " . library['LibraryName'], "Information")
		let load = 0
		if index(library['TypesSuffixes'], a:suffix) != -1
			" Suffix is in the list of acceptable ones
			if index(forced_standard_libraries, library['LibraryName']) != -1
				call TagHLDebug("Library(".library['LibraryName']."): Forced", "Information")
				let load = 1
			elseif library['CheckMode'] == 'Always'
				call TagHLDebug("Library(".library['LibraryName']."): Always", "Information")
				let load = 1
			elseif library['CheckMode'] == 'MatchStart'
				call TagHLDebug("Library(".library['LibraryName']."): Checking MatchStart", "Information")
				for matcher in library['MatchREs']
					call cursor(1,1)
					if search(matcher, 'nc',library['MatchLines'])
						call TagHLDebug("Library(".library['LibraryName']."): Match!", "Information")
						let load = 1
						break
					endif
				endfor
			elseif library['CheckMode'] == 'MatchEnd'
				call TagHLDebug("Library(".library['LibraryName']."): Checking MatchEnd", "Information")
				for matcher in library['MatchREs']
					call cursor(1000000,1000000)
					if search(matcher, 'ncb', library['MatchLines'])
						call TagHLDebug("Library(".library['LibraryName']."): Match!", "Information")
						let load = 1
						break
					endif
				endfor
			elseif library['CheckMode'] == 'Custom'
				call TagHLDebug("Library(".library['LibraryName']."): Custom (".library['CustomFunction'].")", "Information")
				" The hope is that this won't really ever be used, but
				" call the function and check that it returns the right
				" kind of thing (takes suffix as parameter)
				exe 'let result = ' . library['CustomFunction'] . '(' . a:suffix . ')'
				if result == 'Load'
					call TagHLDebug("Custom result: Load", "Information")
					let load = 1
				elseif result == 'Skip'
					call TagHLDebug("Custom result: Skip", "Information")
					" Pass
				else
					call TagHLDebug("Misconfigured library: custom function has invalid return value", "Critical")
				endif
			endif
		endif
		if load
			for full_path in library['TypesFileFullPaths']
				let libraries_to_load += 
							\ [{
							\     'Name': library['LibraryName'],
							\     'Filename': fnamemodify(full_path, ':t'),
							\     'Path': full_path,
							\ }]
			endfor
		else
			call TagHLDebug("No match:" . library['LibraryName'], "Information")
		endif
	endfor

	return libraries_to_load
endfunction

function! TagHighlight#Libraries#NeverMatch()
	return 'Skip'
endfunction
