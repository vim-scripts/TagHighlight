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
	if &cp || (exists('g:loaded_TagHLDebug') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLDebug = 1

let TagHighlight#Debug#DebugLevels = [
			\ "None",
			\ "Critical",
			\ "Error",
			\ "Warning",
			\ "Status",
			\ "Information",
			\ ]

function! TagHighlight#Debug#GetDebugLevel()
	try
		let debug_level = TagHighlight#Option#GetOption('DebugLevel')
	catch /Unrecognised option/
		" Probably loading the option file, so no debug level available
		" yet, so assume 'Information'
		let debug_level = 'Information'
	endtry
	let debug_num = index(g:TagHighlight#Debug#DebugLevels, debug_level)
	if debug_num != -1
		return debug_num
	else
		return index(g:TagHighlight#Debug#DebugLevels, 'Error')
	endif
endfunction

function! TagHighlight#Debug#GetDebugLevelName()
	let debug_level_num = TagHighlight#Debug#GetDebugLevel()
	return g:TagHighlight#Debug#DebugLevels[debug_level_num]
endfunction

function! TagHighlight#Debug#DebugLevelIncludes(level)
	let level_index = index(g:TagHighlight#Debug#DebugLevels, a:level)
	if level_index == -1
		let level_index = index(g:TagHighlight#Debug#DebugLevels, 'Critical')
	endif
	if level_index <= TagHighlight#Debug#GetDebugLevel()
		return 1
	else
		return 0
	endif
endfunction

function! TagHighlight#Debug#DebugUpdateTypesFile(filename)
	" Update the types file with debugging turned on
	if a:filename ==? 'None'
		" Force case to be correct
		let debug_file = 'None'
	else
		let debug_file = a:filename
	endif

	let debug_options = ["DebugFile","DebugLevel"]

	" Store the old debug options
	for dbg_option in debug_options
		let stored_option_name = 'Stored'.dbg_option
		if has_key(g:TagHighlightSettings, dbg_option)
			let g:TagHighlightSettings[stored_option_name] = g:TagHighlightSettings[dbg_option]
		else
			let g:TagHighlightSettings[stored_option_name] = 'None'
		endif
	endfor

	let g:TagHighlightSettings['DebugFile'] = debug_file
	let g:TagHighlightSettings['DebugLevel'] = 'Information'

	call TagHLDebug("========================================================", "Information")
	redir => vim_version_info
	silent version
	redir END
	call TagHLDebug("--------------------------------------------------------", "Information")
	call TagHLDebug(vim_version_info, "Information")
	call TagHighlight#Generation#UpdateAndRead(0)

	" Get rid of the 'stored' versions of the debug options
	for dbg_option in debug_options
		let stored_option_name = 'Stored'.dbg_option
		if g:TagHighlightSettings[stored_option_name] == 'None'
			unlet g:TagHighlightSettings[dbg_option]
		else
			let g:TagHighlightSettings[dbg_option] = g:TagHighlightSettings[stored_option_name]
		endif
		unlet g:TagHighlightSettings[stored_option_name]
	endfor
endfunction
