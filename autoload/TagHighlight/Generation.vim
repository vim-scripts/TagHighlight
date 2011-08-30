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
	if &cp || (exists('g:loaded_TagHLGeneration') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLGeneration = 1

function! TagHighlight#Generation#UpdateTypesFile()
	" Load the version information if we haven't already
	call TagHighlight#Version#LoadVersionInfo()

	" Debug information for configuration
	if TagHighlight#Debug#DebugLevelIncludes('Information')
		call TagHLDebug("Running UpdateTypesFile function at " . strftime("%Y%m%d-%H%M%S"), "Information")
		call TagHLDebug("Current directory is " . getcwd(), "Information")
		call TagHLDebug("Current file is " . expand('%:p'), "Information")
		call TagHLDebug("Release Info:" . string(g:TagHighlightPrivate['PluginVersion']), "Information")
		call TagHLDebug("Global options (g:TagHighlightSettings): " . string(g:TagHighlightSettings), "Information")
		if exists('b:TagHighlightSettings')
			call TagHLDebug("Buffer options (b:TagHighlightSettings): " . string(b:TagHighlightSettings), "Information")
		else
			call TagHLDebug("No buffer options set", "Information")
		endif
	endif

	" Load the option file
	let option_file_info = TagHighlight#Option#LoadOptionFileIfPresent()
	" Debug information for configuration
	if TagHighlight#Debug#DebugLevelIncludes('Information') && option_file_info['Exists']
		call TagHLDebug("Project config file options: " . string(b:TagHighlightConfigFileOptions), "Information")
	else
		call TagHLDebug("Project config file does not exist", "Information")
	endif
	
	" Call any PreUpdate hooks
	let preupdate_hooks = TagHighlight#Option#GetOption('PreUpdateHooks')
	for preupdate_hook in preupdate_hooks
		call TagHLDebug("Calling pre-update hook " . preupdate_hook, "Information")
		exe 'call' preupdate_hook . '()'
	endfor
	
	" Most simple options are automatic.  The options below are
	" handled manually.
	
	" Find the ctags path
	let ctags_option = TagHighlight#Option#GetOption('CtagsExecutable')
	if ctags_option == 'None'
		" Option not set: search for 'ctags' in the path
		call TagHLDebug("CtagsExecutable not set, searching for 'ctags' in path", "Information")
		let b:TagHighlightSettings['CtagsExeFull'] = TagHighlight#RunPythonScript#FindExeInPath('ctags')
	elseif ctags_option =~ '[\\/]'
		" Option set and includes '/' or '\': must be explicit
		" path to named executable: just pass to mktypes
		call TagHLDebug("CtagsExecutable set with path delimiter, using as explicit path", "Information")
		let b:TagHighlightSettings['CtagsExeFull'] = ctags_option
	else
		" Option set but doesn't include path separator: search
		" in the path
		call TagHLDebug("CtagsExecutable set without path delimiter, searching in path", "Information")
		let b:TagHighlightSettings['CtagsExeFull'] = TagHighlight#RunPythonScript#FindExeInPath(ctags_option)
	endif

	let tag_file_info = TagHighlight#Find#LocateFile('TAGS', '')
	if tag_file_info['Found'] == 1
		let b:TagHighlightSettings['CtagsFileLocation'] = tag_file_info['Directory']
	endif

	let types_file_info = TagHighlight#Find#LocateFile('TYPES', '*')
	if types_file_info['Found'] == 1
		let b:TagHighlightSettings['TypesFileLocation'] = types_file_info['Directory']
	endif

	if TagHighlight#Option#GetOption('SourceDir') =~ 'None'
		" The source directory has not been set.  If a project config file was
		" found, use that directory.  If not, but a types file was found,
		" use that directory.  If not, but a tag file was found, use that
		" directory.  If not, use the current directory.
		call TagHLDebug("No source dir set", "Information")
		call TagHLDebug("Current directory is now " . getcwd(), "Information")
		if ! TagHighlight#Option#GetOption('Recurse')
			call TagHLDebug("Non-recursive mode, using file directory", "Information")
			let file = expand('<afile>')
			if len(file) == 0
				let file = expand('%')
			endif
			call TagHLDebug("File is " . file . "(" . fnamemodify(file, ':p:h') . ")", "Information")
			let b:TagHighlightSettings['SourceDir'] = fnamemodify(file, ':p:h')
		elseif option_file_info['Found'] == 1 && option_file_info['Exists'] == 1
			call TagHLDebug("Using project config file directory", "Information")
			let b:TagHighlightSettings['SourceDir'] = option_file_info['Directory']
		elseif types_file_info['Found'] == 1 && types_file_info['Exists'] == 1
			call TagHLDebug("Using types file directory", "Information")
			let b:TagHighlightSettings['SourceDir'] = types_file_info['Directory']
		elseif tag_file_info['Found'] == 1 && tag_file_info['Exists'] == 1
			call TagHLDebug("Using tags file directory", "Information")
			let b:TagHighlightSettings['SourceDir'] = tag_file_info['Directory']
		else
			call TagHLDebug("Using current directory", "Information")
			let b:TagHighlightSettings['SourceDir'] = '.'
		endif
	else
		call TagHLDebug("Source dir set explicitly to " . TagHighlight#Option#GetOption("SourceDir"), "Information")
	endif
	
	call TagHLDebug("Running generator with options:", "Information")
	for var in ["g:TagHighlightSettings","b:TagHighlightConfigFileOptions","b:TagHighlightSettings"]
		if exists(var)
			call TagHLDebug(" - " . var . ": " . string(eval(var)), "Information")
		else
			call TagHLDebug(" - " . var . ": UNSET", "Information")
		endif
	endfor
	let RunOptions = TagHighlight#Option#CopyOptions()
	call TagHighlight#RunPythonScript#RunGenerator(RunOptions)

	let postupdate_hooks = TagHighlight#Option#GetOption('PostUpdateHooks')
	for postupdate_hook in postupdate_hooks
		call TagHLDebug("Calling post-update hook " . postupdate_hook, "Information")
		exe 'call' postupdate_hook . '()'
	endfor

	call TagHLDebug("UpdateTypesFile() complete, current directory is now " . getcwd(), "Information")
endfunction

function! TagHighlight#Generation#UpdateAndRead(skiptags)
	call TagHLDebug("UpdateAndRead() called with parameter " . a:skiptags, "Information")
	let restore_options = 0
	if exists('b:TagHighlightSettings')
		let stored_options = deepcopy(b:TagHighlightSettings)
		let restore_options = 1
	else
		let b:TagHighlightSettings = {}
	endif

	" Start with a copy of the settings so that we can tweak things
	if a:skiptags
		call TagHLDebug("Skipping tag generation", "Information")
		let b:TagHighlightSettings['DoNotGenerateTags'] = 1
	endif
	
	call TagHighlight#Generation#UpdateTypesFile()
	let SavedTabNr = tabpagenr()
	let SavedWinNr = winnr()
	tabdo windo call TagHighlight#ReadTypes#ReadTypesByOption()
	exe 'tabn' SavedTabNr
	exe SavedWinNr . 'wincmd w'

	unlet b:TagHighlightSettings
	if restore_options
		let b:TagHighlightSettings = deepcopy(stored_options)
	endif
	call TagHLDebug("UpdateAndRead() complete", "Information")
endfunction
