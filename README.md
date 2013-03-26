## About
[Vim-script-bundle] [] is a vim.org scripts manager plugin for vim.

## Quick start

1. Setup [Vim-script-bundle] []

        $ git clone https://github.com/BeyondIM/vim-script-bundle.git ~/.vim/scripts/scriptbundle

2. Configure scripts

    Sample `.vimrc`

    ```VimL
    set runtimepath+=$HOME/.vim/scripts/scriptbundle/

    " Set a vim.org reverse proxy server if vim.org can't get access.  
    " let g:vimSiteReverseProxyServer = 'http://vim.wendal.net'

    " Set http or socks proxy if vim.org can't get access.  
    " let g:curlProxy = 'http://127.0.0.1:8888'  
    " let g:curlProxy = 'socks5://127.0.0.1:8888'

    " Some scripts require 7zip to extract.  
    " let g:sevenZipPath = 'path_to_7z_execute_file'

    call scriptbundle#rc()  
    " mark - http://www.vim.org/scripts/script.php?script_id=2666  
    Script '2666'  
    " matchit - http://www.vim.org/scripts/script.php?script_id=39  
    Script '39'
    " align - http://www.vim.org/scripts/script.php?script_id=294  
    Script '294'
    " mayansmoke - http://www.vim.org/scripts/script.php?script_id=3065  
    " Move script to subdirectory to get work properly.
    Script '3065', {'subdir':'colors'}  

    " Brief help  
    " ScriptInstall     - Install configured and non-installed scripts  
    " ScriptInstall!    - Reinstall all installed scripts  
    " ScriptUpdate      - Update all installed scripts
    ```

3. Install configured scripts

    Launch `vim`, run `:ScriptInstall`

    Installing requires [curl] [] and extracting requires [7zip] [].

## Why Vim-script-bundle

[Vundle] [] is a great plugin for managing bundles, [Neobundle] [] is based on Vundle and has lots of new features. Both of them fetch vim.org scripts from [github.com/vim-scripts] [] instead of official site, but some scripts on github.com/vim-scripts are outdated, if you are puzzled by this, you should like [Vim-script-bundle] [], which fetchs vim.org scripts from official site and provides convenience mechanism to manage scripts as Vundle manages bundles.

[Vim-script-bundle]: https://github.com/BeyondIM/vim-script-bundle "Vim script bundle"
[curl]: http://curl.haxx.se "curl"
[7zip]: http://www.7-zip.org "7zip"
[Vundle]: https://github.com/gmarik/vundle "Vundle"
[Neobundle]: https://github.com/Shougo/neobundle.vim "Neobundle"
[github.com/vim-scripts]: https://github.com/vim-scripts "vim scritps on github"
