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
	if &cp || (exists('g:loaded_TagHLLoadDataFile') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLLoadDataFile = 1

function! TagHighlight#LoadDataFile#LoadDataFile(filename)
	let filename = g:TagHighlightPrivate['PluginPath'] . '/data/' . a:filename
	return TagHighlight#LoadDataFile#LoadFile(filename)
endfunction

function! TagHighlight#LoadDataFile#LoadFile(filename)
	let result = {}
	let entries = readfile(a:filename)
	
	let top_key = ''
	for entry in entries
		if entry[0] == '#'
		elseif entry[0] =~ '\k'
			" Keyword character, so not sub entry or comment
			if entry[len(entry)-1:] == ":"
				" Beginning of a field, but we don't know whether
				" it's a list of a dict yet
				let top_key = entry[:len(entry)-2]
			elseif stridx(entry, ':') != -1
				" This is key:value, so it's a simple dictionary entry
				let parts = split(entry, ':')
				" Rather coarse replacement of split(x,y,n)
				if len(parts) > 2
					let parts[1] = join(parts[1:], ':')
				endif
				if stridx(parts[1], ',') != -1
					" This entry is a list
					let result[parts[0]] = split(parts[1], ',')
				else
					let result[parts[0]] = parts[1]
				endif
				" Clear the top key as this isn't a multi-line entry
				let top_key = ''
			else
				call TagHLDebug("  Unhandled line: '" . entry . "'", "Error")
			endif
		elseif entry[0] == "\t" && top_key != ''
			" This is a continuation of a top level key
			if stridx(entry, ':') != -1
				" The key is a dictionary, check for mismatch:
				if has_key(result, top_key)
					if type(result[top_key]) != type({})
						call TagHLDebug("Type mismatch on line '".entry."': expected key:value", "Error")
					endif
				else
					let result[top_key] = {}
				endif
				" Handle the entry (without the preceding tab)
				let parts = split(entry[1:], ':')
				" Rather coarse replacement of split(x,y,n)
				if len(parts) > 2
					let parts[1] = join(parts[1:], ':')
				endif
				if stridx(parts[1], ',') != -1
					" This entry is a list
					let result[top_key][parts[0]] = split(parts[1], ',')
				else
					let result[top_key][parts[0]] = parts[1]
				endif
			else
				" This is a list of strings, check for mismatch
				if has_key(result, top_key)
					if type(result[top_key]) != type([])
						call TagHLDebug("Type mismatch on line '".entry."': didn't expect key:value", "Error")
					endif
				else
					let result[top_key] = []
				endif
				" Add to the list (without the preceding tag)
				let result[top_key] += [entry[1:]]
			endif
		else
			" Probably a comment or blank line
		endif
	endfor
	return result
endfunction
