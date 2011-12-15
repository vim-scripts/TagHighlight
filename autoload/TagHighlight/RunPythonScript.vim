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
	if &cp || (exists('g:loaded_TagHLRunPythonScript') && (g:plugin_development_mode != 1))
		throw "Already loaded"
	endif
catch
	finish
endtry
let g:loaded_TagHLRunPythonScript = 1

let s:python_variant = 'None'

" A simply python script that will try to import the print function
" and will fail gracefully if the python version is too old.  It's
" unlikely that the sys.hexversion check will ever fail as if the version
" is older than 2.6, the import_check will have failed.  I've left it in,
" however, in case I ever need to depend on 2.7
let s:version_and_future_check = 
			\ "try:\n" .
			\ "    import import_check\n" .
			\ "    import vim\n" .
			\ "    import sys\n" .
			\ "    vim.command('''let g:taghl_python_version = '%s' ''' % sys.version)\n" .
			\ "    if sys.hexversion < 0x02060000:\n" .
			\ "        raise ValueError('Incorrect python version')\n" .
			\ "    vim.command('let g:taghl_python_operational = 1')\n" .
			\ "except:\n" .
			\ "    pass\n"

" This script is responsible for finding a means of running the python app.
" If vim is compiled with python support (and we can run a simple test
" command), use that method.  If not, but python is in the path, use it to
" run the script.  If python is not in path, we'll have to rely on a compiled
" executable version.

function! s:GetPath()
	if has("win32")
		let path = substitute($PATH, '\\\?;', ',', 'g')
	else
		let path = substitute($PATH, ':', ',', 'g')
	endif
	return path
endfunction

function! s:RunShellCommand(args)
	let syscmd = ""
	for arg in a:args
		if len(syscmd) > 0
			let syscmd .= " "
		endif
		if stridx(arg, " ") != -1
			let syscmd .= shellescape(arg)
		else
			let syscmd .= arg
		endif
	endfor
	call TagHLDebug(syscmd, "Information")
	let result = system(syscmd)
	echo result
	return result
endfunction

function! TagHighlight#RunPythonScript#RunGenerator(options)
	" Will only actually load the options once
	call TagHighlight#Option#LoadOptions()

	" This will only search for python the first time or if
	" the variant priority or forced variant preferences have
	" changed.
	call TagHighlight#RunPythonScript#FindPython()

	call TagHLDebug("Using variant: " .s:python_variant, "Information")

	if index(["if_pyth","if_pyth3"], s:python_variant) != -1
		let PY = s:python_cmd[0]
		exe PY 'from module.utilities import TagHighlightOptionDict' 
		exe PY 'from module.worker import RunWithOptions'
		exe PY 'options = TagHighlightOptionDict()'
		let handled_options = []
		" We're using the custom interpreter: create an options object
		" All options supported by both Vim and the Python script must
		" have VimOptionMap and CommandLineSwitches keys
		for option in g:TagHighlightPrivate['PluginOptions']
			if has_key(option, 'VimOptionMap') && 
						\ has_key(option, 'CommandLineSwitches') &&
						\ has_key(a:options, option['VimOptionMap'])
				" We can handle this one automatically
				let pyoption = 'options["'.option['Destination'].'"]'
				if option['Type'] == 'bool'
					let handled_options += [option['VimOptionMap']]
					let value = a:options[option['VimOptionMap']]
					if (value == 1) || (value == 'True')
						exe PY pyoption '= True'
					else
						exe PY pyoption '= False'
					endif
				elseif option['Type'] == 'string'
					let handled_options += [option['VimOptionMap']]
					exe PY pyoption '= r"""'.a:options[option['VimOptionMap']].'"""'
				elseif option['Type'] == 'int'
					let handled_options += [option['VimOptionMap']]
					exe PY pyoption '= ' . a:options[option['VimOptionMap']]
				elseif option['Type'] == 'list'
					let handled_options += [option['VimOptionMap']]
					exe PY pyoption '= []'
					for entry in a:options[option['VimOptionMap']]
						exe PY pyoption '+= [r"""' . entry . '"""]'
					endfor
				endif
			endif
		endfor
		for check_opt in keys(a:options)
			if index(handled_options, check_opt) == -1
				call TagHLDebug("Unhandled run option: " . check_opt, "Information")
			endif
		endfor
		exe PY 'RunWithOptions(options)'
	elseif index(["python","compiled"], s:python_variant) != -1
		let args = s:python_cmd[:]
		" We're calling the script externally, build a list of arguments
		for option in g:TagHighlightPrivate['PluginOptions']
			if has_key(option, 'VimOptionMap') && 
						\ has_key(option, 'CommandLineSwitches') &&
						\ has_key(a:options, option['VimOptionMap'])
				if type(option['CommandLineSwitches']) == type([])
					let switch = option['CommandLineSwitches'][0]
				else
					let switch = option['CommandLineSwitches']
				endif
				if switch[:1] == "--"
					let as_one = 1
				elseif switch[:0] == "-"
					let as_one = 0
				else
					call TagHLDebug("Invalid configuration for option " . option['VimOptionMap'], "Error")
				endif
				" We can handle this one automatically
				if option['Type'] == 'bool'
					if (a:options[option['VimOptionMap']] == 1) || (a:options[option['VimOptionMap']] == 'True')
						let bvalue = 1
					else
						let bvalue = 0
					endif
					if (((bvalue == 1) && option['Default'] == 'False')
								\ || ((bvalue == 0) && option['Default'] == 'True'))
						let args += [switch]
					endif
				elseif option['Type'] == 'string'
					if as_one == 1
						let args += [switch . '=' . a:options[option['VimOptionMap']]]
					else
						let args += [switch, a:options[option['VimOptionMap']]]
					endif
				elseif option['Type'] == 'int'
					if as_one == 1
						let args += [switch . '=' . a:options[option['VimOptionMap']]]
					else
						let args += [switch, a:options[option['VimOptionMap']]]
					endif
				elseif option['Type'] == 'list'
					for entry in a:options[option['VimOptionMap']]
						if as_one == 1
							let args += [switch . '=' . entry]
						else
							let args += [switch, entry]
						endif
					endfor
				endif
			endif
		endfor
		let sysoutput = s:RunShellCommand(args)
	else
		throw "Tag highlighter: invalid or not implemented python variant"
	endif
endfunction

function! TagHighlight#RunPythonScript#FindExeInPath(file)
	let full_file = a:file
	if has("win32") || has("win32unix")
		if a:file !~ '.exe$'
			let full_file = a:file . '.exe.'
		endif
	endif
	let short_file = fnamemodify(full_file, ':p:t')
	let file_exe_list = split(globpath(s:GetPath(), short_file), '\n')
	
	if len(file_exe_list) > 0 && executable(file_exe_list[0])
		let file_exe = file_exe_list[0]
	else
		return 'None'
	endif
	"let file_exe = substitute(file_exe, '\\', '/', 'g')
	return file_exe
endfunction

function! TagHighlight#RunPythonScript#FindPython()
	let forced_variant = TagHighlight#Option#GetOption('ForcedPythonVariant')
	" Supported variants
	let supported_variants = ['if_pyth3', 'if_pyth', 'python', 'compiled']
	" Priority of those variants (default is that specified above)
	let variant_priority = TagHighlight#Option#GetOption('PythonVariantPriority')

	" If we've run before and nothing has changed, just return
	if s:python_variant != 'None'
		if forced_variant == s:stored_forced_variant
					\ && s:stored_variant_priority == variant_priority
					\ && s:python_path == TagHighlight#Option#GetOption("PathToPython")
			return s:python_variant
		endif
	endif

	let s:python_variant = 'None'
	let s:python_version = 'Unknown'
	let s:python_cmd = []
	let s:python_path = ""

	" Make sure that the user specified variant is supported
	if index(supported_variants, forced_variant) == -1
		let forced_variant = 'None'
	endif

	let s:stored_forced_variant = forced_variant
	let s:stored_variant_priority = variant_priority

	let add_to_py_path = substitute(g:TagHighlightPrivate['PluginPath'], '\\', '/','g')

	" Make sure that all variants in the priority list are supported
	call filter(variant_priority, 'index(supported_variants, v:val) != -1')

	" Try each variant in the priority list until we find one that works
	for variant in variant_priority
		if forced_variant == variant || forced_variant == 'None'
			try " Fix for bug in Vim versions before 7.3-388
				if variant == 'if_pyth3' && has('python3')
					" Check whether the python 3 interface works
					let g:taghl_findpython_testvar = 0
					try
						py3 import sys
						exe 'py3 sys.path = ["'.add_to_py_path.'"] + sys.path'
						let g:taghl_python_operational = 0
						exe 'py3' s:version_and_future_check
						py3 import vim

						if g:taghl_python_operational != 1
							throw "Python doesn't seem to be working"
						endif
						let s:python_version = g:taghl_python_version
						unlet g:taghl_python_operational
						unlet g:taghl_python_version

						" If we got this far, it should be working
						let s:python_variant = 'if_pyth3'
						let s:python_cmd = ['py3']
					catch
						call TagHLDebug("Cannot use python3 interface", "Status")
					endtry
				elseif variant == 'if_pyth' && has('python')
					" Check whether the python 2 interface works
					let g:taghl_findpython_testvar = 0
					try
						py import sys
						exe 'py sys.path = ["'.add_to_py_path.'"] + sys.path'
						let g:taghl_python_operational = 0
						exe 'py' s:version_and_future_check
						py import vim

						if g:taghl_python_operational != 1
							throw "Python doesn't seem to be working"
						endif
						let s:python_version = g:taghl_python_version
						unlet g:taghl_python_operational
						unlet g:taghl_python_version

						" If we got this far, it should be working
						let s:python_variant = 'if_pyth'
						let s:python_cmd = ['py']
					catch
						call TagHLDebug("Cannot use python2 interface", "Status")
					endtry
				elseif variant == 'python'
					" Try calling an external python

					" Has a specific path to python been set?
					let python_path = TagHighlight#Option#GetOption('PathToPython')
					if python_path != 'None' && executable(python_path)
						" We've found python, it's probably usable
						let s:python_variant = 'python'
						let s:python_path = python_path
						let s:python_cmd = [python_path, g:TagHighlightPrivate['PluginPath'] . '/TagHighlight.py']
					else
						" See if it's in the path
						let python_path = TagHighlight#RunPythonScript#FindExeInPath('python')
						if python_path != 'None'
							let s:python_variant = 'python'
							let s:python_path = python_path
							let s:python_cmd = [python_path, g:TagHighlightPrivate['PluginPath'] . '/TagHighlight.py']
						endif
					endif

					" Now run some simple test code to make sure it works correctly and
					" is a reasonable version
					let result = s:RunShellCommand([s:python_path, g:TagHighlightPrivate['PluginPath'] . '/version_check.py'])
					let lines = split(result, '\n')
					let s:python_version = lines[1]
					if lines[0] != 'OK'
						let s:python_variant = 'None'
						let s:python_path = ''
						let s:python_cmd = []
					endif
				elseif variant == 'compiled'
					" See if there's a compiled executable version of the
					" highlighter
					if has("win32")
						let compiled_highlighter = split(globpath(&rtp, "plugin/TagHighlight/Compiled/Win32/TagHighlight.exe"), "\n")
						if len(compiled_highlighter) > 0  && executable(compiled_highlighter[0])
							let s:python_variant = 'compiled'
							let s:python_version = 'Compiled Highlighter'
							let s:python_cmd = [compiled_highlighter[0]]
						endif
					elseif has("unix")
						let compiled_highlighter = split(globpath(&rtp, "plugin/TagHighlight/Compiled/Linux/TagHighlight"), "\n")
						if len(compiled_highlighter) > 0  && executable(compiled_highlighter[0])
							let s:python_variant = 'compiled'
							let s:python_version = 'Compiled Highlighter'
							let s:python_cmd = [compiled_highlighter[0]]
						endif
					endif
				endif
			catch /^Vim\%((\a\+)\)\=:E83[67]/
				call TagHLDebug("Attempted to use conflicting pythons in pre-7.3-288 Vim", "Status")
			endtry
		endif
		
		if s:python_variant != 'None'
			" Found one!
			break
		endif
	endfor

	if s:python_variant != 'None'
		call TagHLDebug("Python variant is " . s:python_variant, "Information")
		call TagHLDebug("Python Command is " . join(s:python_cmd, " "), "Information")
		call TagHLDebug("Python Path is " . s:python_path, "Information")
		call TagHLDebug("Python version reported as: " . s:python_version,
					\ 'Information')
	else
		throw "Tag highlighter: could not find python (2.6+) or the compiled version of the highlighter."
	endif

	return s:python_variant
endfunction

