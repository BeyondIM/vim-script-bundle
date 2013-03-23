" Vim-script-bundle: A simple vim.org scripts manager plugin for Vim
" Author: BeyondIM <lypdarling at gmail dot com>
" HomePage: https://github.com/BeyondIM/vim-script-bundle
" License: MIT license
" Version: 0.2

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
    silent! execute 'setlocal nobuflisted'
    silent! execute 'wincmd q'
endfunction
" }}}2

" CreateScriptInfoFile {{{2
function! s:CreateScriptInfoFile()
    silent! execute 'keepalt botright 1new'
    silent! execute 'edit ' . s:scriptInfoFile
    silent! execute 'write!'
    silent! execute 'setlocal nobuflisted'
    silent! execute 'wincmd q'
    if !filereadable(s:scriptInfoFile)
        call s:EchoMsg("can't read " . s:scriptInfoFile, 'error')
        return
    endif
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
function! s:script.crawlHtml()
    let tmp1 = s:tmp . '/' . self.ID
    silent! execute '!curl ' . s:curlProxy . ' ' . s:vimSiteUrl . '/scripts/script.php?script_id=' . self.ID . ' > ' . tmp1
    " get script src_id, package name and version number
    let pageHtml = readfile(tmp1)
    let idx = 0
    for line in pageHtml
        if match(line, 'download_script.php?src_id=') != -1
            let idx = index(pageHtml, line)
            break
        endif
    endfor
    if idx == 0
        call s:EchoMsg("can't find download link.", 'error')
        return
    endif
    let srcID = substitute(pageHtml[idx], '.*download_script.php?src_id=\(\d\+\).*', '\1', '')
    let packageName = substitute(pageHtml[idx], '.*<a.*>\(.*\)</a>.*', '\1', '')
    let ver = substitute(pageHtml[idx+1], '.*<b>\(.*\)</b>.*', '\1', '')
    " delete temporary file
    call delete(tmp1)
    let self.srcID = srcID
    let self.packageName = packageName
    let self.ver = ver
endfunction
" }}}2

" installScript {{{2
function! s:script.installScript()
    call self.crawlHtml()
    call self.extractScript()
    " update script info file
    let info = {'ID':self.ID, 'ver':self.ver}
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
function! s:script.extractScript()
    call s:RmDir(self.rtp)
    call s:MkDir(self.rtp)
    " download script package file
    let tmp2 = s:tmp . '/' . self.packageName
    silent! execute '!curl ' . s:curlProxy . ' ' . s:vimSiteUrl . '/scripts/download_script.php?src_id=' . self.srcID . ' > ' . tmp2
    " install script
    if match(self.packageName, '\(tar.gz\|tgz\|tar.bz2\|tbz2\)$') != -1
        silent! execute s:sevenZipPath . ' x ' . tmp2 . ' -o' . s:tmp . ' -aoa'
        let tmp3 = s:tmp . '/' . substitute(self.packageName,'^\(.*\).\(tar.gz\|tgz\|tar.bz2\|tbz2\)$', '\1', '') . '.tar'
        silent! execute s:sevenZipPath . ' x ' . tmp3 . ' -ttar -o' . self.rtp . ' -aoa'
        call delete(tmp3)
    elseif match(self.packageName, '\(vba\|vmb\).\(gz\|bz2\)$') != -1
        silent! execute s:sevenZipPath . ' x ' . tmp2 . ' -o' . s:tmp . ' -aoa'
        let tmp3 = s:tmp . '/' . substitute(self.packageName,'^\(.*\).\(vba\|vmb\).\(gz\|bz2\)$', '\1.\2', '')
        call s:InstallVimball(tmp3,self.rtp)
        call delete(tmp3)
    elseif match(self.packageName, '\(zip\|gz\|bz2\)$') != -1
        silent! execute s:sevenZipPath . ' x ' . tmp2 . ' -o' . self.rtp . ' -aoa'
    elseif match(self.packageName, 'tar$') != -1
        silent! execute s:sevenZipPath . ' x ' . tmp2 . ' -ttar -o' . self.rtp . ' -aoa'
    elseif match(self.packageName, '\(vba\|vmb\)$') != -1
        call s:InstallVimball(tmp2,self.rtp)
    elseif match(self.packageName, 'vim$') != -1
        if exists('self.subdir')
            call s:MkDir(expand(self.rtp.'/'.self.subdir, 1))
            call s:Move(tmp2, expand(self.rtp.'/'.self.subdir, 1))
        else
            call s:Move(tmp2, self.rtp)
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
    call delete(tmp2)
endfunction
" }}}2

" updateScript {{{2
function! s:script.updateScript()
    call self.crawlHtml()
    " update script info file
    let info = {'ID':self.ID, 'ver':self.ver}
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
    elseif self.ver > oldVer
        call remove(file, idx)
        call add(file, string(info))
        call writefile(file, s:scriptInfoFile)
        call self.extractScript()
    else
        return
    endif
endfunction
" }}}2

" uninstallScript {{{2
function! s:script.uninstallScript()
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
    if idx != -1
        call remove(file, idx)
        call writefile(file, s:scriptInfoFile)
    endif
    call s:RmDir(self.rtp)
endfunction
" }}}2

" }}}1


" scriptbundle function {{{1

" scriptbundle#Config {{{2
function! scriptbundle#Config(ID,...)
    let script = s:script.new(a:ID)
    if a:0 > 0 && type(a:1) == type({})
        let script = extend(script,a:1,'force')
    endif
    call s:RmAllRtp()
    call add(g:scriptList, script)
    call s:AddAllRtp()
    return script
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
        let IDs = '\('.IDs.'\)'
    endif
    let paths = glob(s:scriptsDir . '/*', 1) . "\n" . glob(s:scriptsDir . '/.[^.]*', 1)
    let pathList = split(paths, "\n")
    let dirList = map(copy(pathList), "substitute(v:val, '^.*[\\\\/]\\(.*\\)$', '\\1', '')")
    if len(g:scriptList) > 0
        let _dirList = filter(dirList, "v:val !~ IDs && v:val =~ '\\d\\+'")
    else
        let _dirList = filter(dirList, "v:val =~ '\\d\\+'")
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
    let s:isWin = has('win32') || has('win64')
    let s:tmp = s:isWin ? $TEMP : '/tmp'
    if !exists('g:sevenZipPath')
        let s:sevenZipPath = '!7z'
    else
        let s:sevenZipPath = '!' . g:sevenZipPath
    endif
    " set vim.org reverse proxy server if need
    if !exists('g:vimSiteReverseProxyServer')
        let s:vimSiteUrl = 'http://www.vim.org'
    else
        let s:vimSiteUrl = g:vimSiteReverseProxyServer
    endif
    " set scoks5 proxy if need
    if !exists('g:curlProxy')
        let s:curlProxy = ''
    else
        let s:curlProxy = '-x ' . g:curlProxy
    endif
    " set scripts folder
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
