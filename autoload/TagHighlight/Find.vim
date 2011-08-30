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
	if &cp || (exists('g:loaded_TagHLFind') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLFind = 1

" Tools for finding files.  When generating the tags and types file, we need
" to decide where to place it.  If the user has configured the mode in which
" everything is based on the current directory (which works well with the
" project plugin), the current directory is what we use.  If the user wants to
" search up for a tags file, we can look for an existing tags file and stop
" when we find one, starting either from the current directory or source
" directory.  If we don't, either use the current directory or the source file
" directory (configuration).
"
" It should also be possible to place the tags file in a remote location and
" use either the current directory, source directory or explicitly set
" directory for the base of the scan.

" Option structure:
"
" [gb]:TagHighlightSettings:
"	DefaultDirModePriority:[Explicit,UpFromCurrent,UpFromFile,CurrentDirectory,FileDirectory]
"	TagFileDirModePriority:["Default"] or as above
"	TypesFileDirModePriority:As tag file
"	ConfigFileDirModePriority:As tag file
"	DefaultDirModeSearchWildcard:'' (look for tags file) or something specific (*.uvopt)?
"	MaxDirSearchLevels: (integer)
"
" Explicit Locations:
"
"  [gb]:TagHighlightSettings:
"    TagFileDirectory:str (NONE)
"    TagFileName:str (tags)
"    TypesFileDirectory:str (NONE)
"    TypesPrefix:str (types)
"    ProjectConfigFileName:str (taghl_config.txt)
"    ProjectConfigFileDirectory:str (NONE)

function! TagHighlight#Find#LocateFile(which, suffix)
	call TagHLDebug("Locating file " . a:which . " with suffix " . a:suffix, 'Information')

	" a:which is 'TAGS', 'TYPES', 'CONFIG'
	let default_priority = TagHighlight#Option#GetOption('DefaultDirModePriority')
	call TagHLDebug("Priority: " . string(default_priority), "Information")
	let default_search_wildcards = TagHighlight#Option#GetOption('DefaultDirModeSearchWildcards')


	let file = expand('<afile>')
	if len(file) == 0
		let file = expand('%')
	endif

	if a:which == 'TAGS'
		" Suffix is ignored here
		let filename = TagHighlight#Option#GetOption('TagFileName')
		let search_priority = TagHighlight#Option#GetOption('TagFileDirModePriority')
		let explicit_location = TagHighlight#Option#GetOption('TagFileDirectory')
		let search_wildcards = TagHighlight#Option#GetOption('TagFileSearchWildcards')
	elseif a:which == 'TYPES'
		let filename = TagHighlight#Option#GetOption('TypesFilePrefix') . '_' .
					\ a:suffix . "." .
					\ TagHighlight#Option#GetOption('TypesFileExtension')
		let search_priority = TagHighlight#Option#GetOption('TypesFileDirModePriority')
		let explicit_location = TagHighlight#Option#GetOption('TypesFileDirectory')
		let search_wildcards = TagHighlight#Option#GetOption('TypesFileSearchWildcards')
	elseif a:which == 'CONFIG'
		" Suffix is ignored here
		let filename = TagHighlight#Option#GetOption('ProjectConfigFileName')
		let search_priority = TagHighlight#Option#GetOption('ProjectConfigFileDirModePriority')
		let explicit_location = TagHighlight#Option#GetOption('ProjectConfigFileDirectory')
		let search_wildcards = TagHighlight#Option#GetOption('ProjectConfigFileSearchWildcards')
	else
		throw "Unrecognised file"
	endif

	if search_wildcards[0] == 'Default'
		let search_wildcards = default_search_wildcards
	endif

	if search_priority[0] == 'Default'
		let search_priority = default_priority
	endif

	" Ensure there's no trailing slash on 'explicit location'
	if explicit_location[len(explicit_location)-1] == '/'
		let explicit_location = explicit_location[:len(explicit_location)-2]
	endif

	" Result contains 'Found','FullPath','Directory','Filename','Exists']
	let result = {}

	for search_mode in search_priority
		if search_mode == 'Explicit' && explicit_location != 'None'
			" Use explicit location, overriding everything else
			call TagHLDebug('Using explicit location', 'Information')
			let result['Directory'] = explicit_location
			let result['Filename'] = filename
		elseif search_mode == 'UpFromCurrent'
			" Start in the current directory and search up
			let dir = fnamemodify('.',':p:h')
			let result = s:ScanUp(dir, search_wildcards)
			if has_key(result, 'Directory')
				call TagHLDebug('Found location with UpFromCurrent', 'Information')
				let result['Filename'] = filename
			endif
		elseif search_mode == 'UpFromFile'
			" Start in the directory containing the current file and search up
			let dir = fnamemodify(file,':p:h')
			let result = s:ScanUp(dir, search_wildcards)
			if has_key(result, 'Directory')
				call TagHLDebug('Found location with UpFromFile', 'Information')
				let result['Filename'] = filename
			endif
		elseif search_mode == 'CurrentDirectory'
			call TagHLDebug('Using current directory', 'Information')
			let result['Directory'] = fnamemodify('.',':p:h')
			let result['Filename'] = filename
		elseif search_mode == 'FileDirectory'
			call TagHLDebug('Using file directory', 'Information')
			let result['Directory'] = fnamemodify(file,':p:h')
			let result['Filename'] = filename
		endif
		if has_key(result, 'Directory')
			let result['FullPath'] = result['Directory'] . '/' . result['Filename']
			let result['Found'] = 1
			call TagHLDebug('Found file location', 'Information')
			if filereadable(result['FullPath'])
				call TagHLDebug('File exists', 'Information')
				let result['Exists'] = 1
			else
				call TagHLDebug('File does not exist', 'Information')
				let result['Exists'] = 0
			endif
			break
		endif
	endfor

	if ! has_key(result, 'Directory')
		call TagHLDebug("Couldn't find path", 'Warning')
		let result = {'Found': 0, 'Exists': 0}
	endif

	return result
endfunction

function! s:ScanUp(dir, wildcards)
	let result = {}
	let max_levels = TagHighlight#Option#GetOption('MaxDirSearchLevels')
	let levels = 0
	let new_dir = a:dir
	let dir = ''
	let found = 0

	call TagHLDebug("Searching up from " . a:dir . " for " . string(a:wildcards), 'Information')

	" new_dir != dir check looks for the root directory
	while new_dir != dir
		let dir = new_dir
		let new_dir = fnamemodify(dir, ':h')
		
		call TagHLDebug("Trying " . dir, "Information")
		for wildcard in a:wildcards
			let glob_pattern = dir
			if glob_pattern[len(glob_pattern)-1] != '/'
				let glob_pattern .= '/'
			endif
			let glob_pattern .= wildcard
			let glob_result = split(glob(glob_pattern), "\n")
			if len(glob_result) > 0
				for r in glob_result
					if filereadable(r)
						let found = 1
					endif
				endfor
				if found
					call TagHLDebug("Found match: " . dir . " (" . glob_pattern . ")", "Information")
					let result['Directory'] = dir
					let found = 1
					break
				else
					call TagHLDebug("Wildcard matches were not readable (directory?)", "Information")
				endif
			endif
		endfor
		if found
			break
		endif

		" Check for recursion limit
		let levels += 1
		if (max_levels > 0) && (levels >= max_levels)
			call TagHLDebug("Hit recursion limit", "Information")
			break
		endif
	endwhile
	if new_dir == dir
		" Must have reached root directory
		call TagHLDebug("Reached root directory and stopped", "Information")
	endif
	return result
endfunction
