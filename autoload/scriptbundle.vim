" Vim-script-bundle: A simple vim.org scripts manager plugin for Vim
" Author: BeyondIM <lypdarling at gmail dot com>
" HomePage: https://github.com/BeyondIM/vim-script-bundle
" License: MIT license
" Version: 0.3a

let s:save_cpo = &cpo
set cpo&vim

" Prepare {{{1

" EchoMessage {{{2
function! s:EchoMsg(message,type)
    if a:type == 'warn'
        echohl WarningMsg | echo a:message | echohl None
    elseif a:type == 'error'
        echohl ErrorMsg | echo a:message | echohl None
    endif
endfunction
" }}}2

" RmDir {{{2
function! s:RmDir(dir)
    let rmdir = s:isWin ? 'rmdir /S /Q' : 'rm -rf'
    call system(rmdir . ' ' . shellescape(expand(a:dir), 1))
endfunction
" }}}2

" MkDir {{{2
function! s:MkDir(dir)
    if exists('*mkdir')
        call mkdir(a:dir, 'p')
    return
    let mkdir = s:isWin ? 'mkdir' : 'mkdir -p'
    call system(mkdir . ' ' . shellescape(expand(a:dir), 1))
    if !isdirectory(a:dir)
        call s:EchoMsg("can't create " . a:dir . " directory, please create it manually.",'warn')
    endif
endfunction
" }}}2

" Move {{{2
function! s:Move(source,target)
   let move = s:isWin ? 'move /Y' : 'mv -f'
   call system(move . ' ' . shellescape(expand(a:source), 1) . ' ' . shellescape(expand(a:target), 1))
endfunction
" }}}2

" InstallVimball {{{2
function! s:InstallVimball(vimball,targetdir)
    silent! execute 'keepalt botright 1new'
    silent! execute 'edit ' . a:vimball
    silent! execute 'UseVimball ' . a:targetdir
    silent! execute 'bwipeout!'
    for b in range(1, bufnr('$'))
        if match(bufname(b), 'VimballRecord') != -1
            silent! execute 'bwipeout! '.b
        endif
    endfor
    silent! execute 'close!'
endfunction
" }}}2

" CreateScriptInfoFile {{{2
function! s:CreateScriptInfoFile()
    silent! execute 'keepalt botright 1new'
    silent! execute 'edit ' . s:scriptInfoFile
    silent! execute 'write!'
    silent! execute 'bwipeout!'
    silent! execute 'close!'
    if !filereadable(s:scriptInfoFile)
        call s:EchoMsg("can't read " . s:scriptInfoFile, 'error')
        return
    endif
endfunction
" }}}2

" ShellESC {{{2
function! s:ShellESC(str)
    return '"' . a:str . '"'
endfunction
" }}}2

" RmAllRtp {{{2
function s:RmAllRtp()
    let paths = map(copy(g:scriptList), 'v:val.rtp')
    let prepends = join(paths, ',')
    let appends = join(paths, '/after,').'/after'
    silent! execute 'set runtimepath-='.fnameescape(prepends)
    silent! execute 'set runtimepath-='.fnameescape(appends)
endfunction
" }}}2

" AddAllRtp {{{2
function s:AddAllRtp()
    let paths = map(copy(g:scriptList), 'v:val.rtp')
    let temp = map(copy(g:scriptList), "v:val.rtp . '/after'")
    let afterPaths = filter(temp, "isdirectory(v:val)")
    let prepends = join(paths, ',')
    let appends = join(afterPaths, ',')
    silent! execute 'set runtimepath^='.fnameescape(prepends)
    silent! execute 'set runtimepath+='.fnameescape(appends)
endfunction
" }}}2

" }}}1


" Scripts object {{{1

let s:script = {}

" new {{{2
function! s:script.new(ID)
    let newScript = copy(self)
    let newScript.ID = a:ID
    let newScript.rtp = expand(s:scriptsDir . '/' . a:ID, 1)
    return newScript
endfunction
" }}}2

" crawlHtml {{{2
function! s:script.crawlHtml() abort
    let tmp1 = s:tmp . '/' . self.ID
    silent! execute '!curl ' . s:curlProxy . ' ' . s:ShellESC(s:vimSiteUrl . '/scripts/script.php?script_id=' . self.ID) . ' -o ' . s:ShellESC(tmp1)
    " get script src_id, package name and version number
    let pageHtml = readfile(tmp1)
    let idx = -1
    for line in pageHtml
        if match(line, 'download_script.php?src_id=') != -1
            let idx = index(pageHtml, line)
            break
        endif
    endfor
    if idx == -1
        return
    endif
    let srcID = substitute(pageHtml[idx], '.*download_script.php?src_id=\(\d\+\).*', '\1', '')
    let packageName = substitute(pageHtml[idx], '.*<a.*>\(.*\)</a>.*', '\1', '')
    let ver = substitute(pageHtml[idx+1], '.*<b>\(.*\)</b>.*', '\1', '')
    let temp = filter(copy(pageHtml), "v:val =~ '<span class=\"txth1\">'")
    let name = substitute(temp[0], '.*<span class="txth1">\(.*\) : .*</span>.*', '\1', '')
    " delete temporary file
    call delete(tmp1)
    let self.srcID = srcID
    let self.packageName = packageName
    let self.name = name
    let self.ver = ver
endfunction
" }}}2

" installScript {{{2
function! s:script.installScript() abort
    call self.crawlHtml()
    if !exists('self.packageName')
        call s:EchoMsg("can't find download link or can't download, please check whether you can access vim.org.", 'error')
        return
    endif
    call self.extractScript()
    if empty(glob(self.rtp . '/*', 1))
        call s:EchoMsg("can't download or extract file error, please check whether you can access vim.org if 7zip works properly.", 'error')
        return
    endif
    redraw
    echo 'Installing ' . self.name . ' done'
    " update script info file
    let info = {'ID':self.ID, 'name':self.name, 'ver':self.ver}
    if !filereadable(s:scriptInfoFile)
        call s:CreateScriptInfoFile()
    endif
    let file = readfile(s:scriptInfoFile)
    let idx = -1
    for line in file
        if eval(line)['ID'] == self.ID
            let idx = index(file, line)
            break
        endif
    endfor
    if idx == -1
        call add(file, string(info))
    else
        call remove(file, idx)
        call add(file, string(info))
    endif
    call writefile(file, s:scriptInfoFile)
    " build help tags if need
    if isdirectory(self.rtp.'/doc') && (!filereadable(self.rtp.'/doc/tags') || filewritable(self.rtp.'/doc/tags'))
        silent! execute 'helptags '.self.rtp.'/doc'
    endif
endfunction
" }}}2

" extractScript {{{2
function! s:script.extractScript() abort
    call s:RmDir(self.rtp)
    call s:MkDir(self.rtp)
    " download script package file
    let tmp1 = s:tmp . '/' . self.packageName
    silent! execute '!curl ' . s:curlProxy . ' ' . s:ShellESC(s:vimSiteUrl . '/scripts/download_script.php?src_id=' . self.srcID) . ' -o ' . s:ShellESC(tmp1)
    " install script
    if match(self.packageName, '\(tar.gz\|tgz\|tar.bz2\|tbz2\)$') != -1
        silent! execute s:extractApp . ' x ' . s:ShellESC(tmp1) . ' -o' . s:ShellESC(s:tmp) . ' -aoa'
        let tmp2 = s:tmp . '/' . substitute(self.packageName,'^\(.*\).\(tar.gz\|tgz\|tar.bz2\|tbz2\)$', '\1', '') . '.tar'
        silent! execute s:extractApp . ' x ' . s:ShellESC(tmp2) . ' -ttar -o' . s:ShellESC(self.rtp) . ' -aoa'
        call delete(tmp2)
    elseif match(self.packageName, '\(vba\|vmb\).\(gz\|bz2\)$') != -1
        silent! execute s:extractApp . ' x ' . s:ShellESC(tmp1) . ' -o' . s:ShellESC(s:tmp) . ' -aoa'
        let tmp2 = s:tmp . '/' . substitute(self.packageName,'^\(.*\).\(vba\|vmb\).\(gz\|bz2\)$', '\1.\2', '')
        call s:InstallVimball(tmp2,self.rtp)
        call delete(tmp2)
    elseif match(self.packageName, '\(zip\|gz\|bz2\)$') != -1
        silent! execute s:extractApp . ' x ' . s:ShellESC(tmp1) . ' -o' . s:ShellESC(self.rtp) . ' -aoa'
    elseif match(self.packageName, 'tar$') != -1
        silent! execute s:extractApp . ' x ' . s:ShellESC(tmp1) . ' -ttar -o' . s:ShellESC(self.rtp) . ' -aoa'
    elseif match(self.packageName, '\(vba\|vmb\)$') != -1
        call s:InstallVimball(tmp1,self.rtp)
    elseif match(self.packageName, 'vim$') != -1
        if exists('self.subdir')
            call s:MkDir(expand(self.rtp.'/'.self.subdir, 1))
            call s:Move(tmp1, expand(self.rtp.'/'.self.subdir, 1))
        else
            call s:Move(tmp1, self.rtp)
        endif
    endif
    " move extracted subdirectory as installDir
    let paths = glob(self.rtp . '/*', 1) . "\n" . glob(self.rtp . '/.[^.]*', 1)
    let pathList = split(paths, "\n")
    if len(pathList) == 1 && isdirectory(pathList[0])
        let name = fnamemodify(pathList[0], ":t")
        if match(name, '^\(colors\|plugin\|ftdetect\|ftplugin\|indent\|compiler|\after\|autoload\)$') == -1
            call s:Move(pathList[0], s:scriptsDir)
            call s:RmDir(self.rtp)
            call s:Move(s:scriptsDir . '/' . name, self.rtp)
        endif
    endif
    " delete temporary files
    call delete(tmp1)
endfunction
" }}}2

" updateScript {{{2
function! s:script.updateScript() abort
    call self.crawlHtml()
    if !exists('self.rtp')
        call s:EchoMsg("can't find download link or can't download, please check whether you can access vim.org.", 'error')
        return
    endif
    " update script info file
    let info = {'ID':self.ID, 'name':self.name, 'ver':self.ver}
    if !filereadable(s:scriptInfoFile)
        call s:CreateScriptInfoFile()
    endif
    let file = readfile(s:scriptInfoFile)
    let idx = -1
    for line in file
        if eval(line)['ID'] == self.ID
            let idx = index(file, line)
            let oldVer = eval(line)['ver']
            break
        endif
    endfor
    if idx == -1
        call self.extractScript()
        if empty(glob(self.rtp . '/*', 1))
            call s:EchoMsg("can't download or extract file error, please check whether you can access vim.org if 7zip works properly.", 'error')
            return
        endif
        redraw
        echo 'Installing ' . self.name . ' done'
    elseif self.ver > oldVer
        call remove(file, idx)
        call add(file, string(info))
        call writefile(file, s:scriptInfoFile)
        call self.extractScript()
        if empty(glob(self.rtp . '/*', 1))
            call s:EchoMsg("can't download or extract file error, please check whether you can access vim.org if 7zip works properly.", 'error')
            return
        endif
        redraw
        echo 'Upgrading ' . self.name . ' from ' . oldVer . ' to ' . self.ver . ' done'
    endif
endfunction
" }}}2

" uninstallScript {{{2
function! s:script.uninstallScript() abort
    if !filereadable(s:scriptInfoFile)
        call s:CreateScriptInfoFile()
    endif
    let file = readfile(s:scriptInfoFile)
    let idx = -1
    for line in file
        if eval(line)['ID'] == self.ID
            let idx = index(file, line)
            let name = eval(line)['name']
            break
        endif
    endfor
    if idx != -1
        call remove(file, idx)
        call writefile(file, s:scriptInfoFile)
    endif
    call s:RmDir(self.rtp)
    if exists('name')
        redraw
        echo 'Uninstalling ' . name . ' done'
        silent! execute '2sleep'
    endif
endfunction
" }}}2

" }}}1


" scriptbundle function {{{1

" scriptbundle#Config {{{2
function! scriptbundle#Config(ID,...) abort
    let script = s:script.new(a:ID)
    " append custom keys
    if a:0 > 0 && type(a:1) == type({})
        for key in keys(a:1)
            if index(s:acceptedKeys, key) == -1
                call s:EchoMsg("Vim script bundle: the key '". key . "' isn't accepted.", 'error')
                return
            endif
        endfor
        let script = extend(script,a:1,'force')
    endif
    call s:RmAllRtp()
    call add(g:scriptList, script)
    call s:AddAllRtp()
endfunction
" }}}2

" scriptbundle#Install {{{2
function! scriptbundle#Install(bang)
    if empty(a:bang)
        for script in g:scriptList
            if !isdirectory(script.rtp)
                call script.installScript()
            endif
        endfor
    else
        for script in g:scriptList
            call script.installScript()
        endfor
    endif
endfunction
" }}}2

" scriptbundle#Update {{{2
function! scriptbundle#Update()
    for script in g:scriptList
        if isdirectory(script.rtp)
            call script.updateScript()
        endif
    endfor
endfunction
" }}}2

" scriptbundle#Clean {{{2
function! scriptbundle#Clean()
    " get IDs left in scriptsDir
    if len(g:scriptList) > 0
        for script in g:scriptList
            let IDs = !exists('IDs') ? script.ID : IDs.'\|'.script.ID
        endfor
        let IDs = '^\('.IDs.'\)$'
    endif
    let paths = glob(s:scriptsDir . '/*', 1) . "\n" . glob(s:scriptsDir . '/.[^.]*', 1)
    let pathList = split(paths, "\n")
    let dirList = map(copy(pathList), "substitute(v:val, '^.*[\\\\/]\\(.*\\)$', '\\1', '')")
    if len(g:scriptList) > 0
        let _dirList = filter(dirList, "v:val !~ IDs && v:val =~ '^\\d\\+$'")
    else
        let _dirList = filter(dirList, "v:val =~ '^\\d\\+$'")
    endif
    for ID in _dirList
        let _script = s:script.new(ID)
        call _script.uninstallScript()
    endfor
endfunction
" }}}2

" scriptbundle#rc {{{2
function! scriptbundle#rc(...) abort
    let g:scriptList = []
    let s:acceptedKeys = ['subdir']
    let s:isWin = has('win32') || has('win64')
    let s:tmp = s:isWin ? $TEMP : '/tmp'
    if !exists('g:extractApp')
        if executable('7z')
            let s:extractApp = '!7z'
        elseif s:isWin
            let extractAppforWin = 'c:\Program Files\7-Zip\7z.exe'            
            if executable(extractAppforWin)
                let s:extractApp = '!' . s:ShellESC(extractAppforWin)
            endif
        endif
    else
        let s:extractApp = '!' . s:ShellESC(g:extractApp)
    endif
    " set vim.org reverse proxy server if need
    if !exists('g:vimSiteReverseProxyServer')
        let s:vimSiteUrl = 'http://www.vim.org'
    else
        let s:vimSiteUrl = g:vimSiteReverseProxyServer
    endif
    " set proxy if need
    if !exists('g:curlProxy')
        let s:curlProxy = ''
    else
        let s:curlProxy = '-x ' . g:curlProxy
    endif
    " set scripts directory
    let s:scriptsDir = a:0 > 0 ? expand(a:1, 1) : expand($HOME.'/.vim/scripts', 1)
    " set script info file path
    let s:scriptInfoFile = expand(s:scriptsDir . '/.scriptinfo', 1)
endfunction
" }}}2

" }}}1


" commands {{{1
command! -nargs=+ Script call scriptbundle#Config(<args>)
command! -bang -nargs=0 ScriptInstall call scriptbundle#Install('!'=='<bang>')
command! -nargs=0 ScriptUpdate call scriptbundle#Update()
command! -nargs=0 ScriptClean call scriptbundle#Clean()
" }}}1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set shiftwidth=4 tabstop=4 softtabstop=4 expandtab foldmethod=marker:
