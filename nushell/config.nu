# config.nu
#
# Installed by:
# version = "0.114.1"
#
# This file is used to override default Nushell settings, define
# (or import) custom commands, or run any other startup tasks.
# See https://www.nushell.sh/book/configuration.html
#
# Nushell sets "sensible defaults" for most configuration settings, 
# so your `config.nu` only needs to override these defaults if desired.
#
# You can open this file in your default editor using:
#     config nu
#
# You can also pretty-print and page through the documentation for configuration
# options using:
#     config nu --doc | nu-highlight | less -R

# --- Terminal-Icons replacement: eza (icon-aware ls) ---
# `ls` stays Nushell's built-in so `ls | where size > 1mb` etc. still works;
# eza is only used for the display-oriented commands below.
# NOTE: eza 0.23.5 silently prints nothing when given no path at all, so an
# explicit default path is always passed (bug reproduced outside Nushell too).
def ll [path: string = "."] { eza -l --icons --group-directories-first $path }
def la [path: string = "."] { eza -la --icons --group-directories-first $path }
def lt [path: string = "."] { eza --tree --icons $path }

# --- z / PSReadLine-equivalent tuning ---
# zoxide (z / zi commands) and oh-my-posh (prompt) are auto-loaded from
# ./vendor/autoload/ - no source line needed here.
$env.config.show_banner = false
$env.config.history.file_format = "sqlite"
$env.config.history.max_size = 100_000
$env.config.history.isolation = true

# --- fzf-powered history search (Ctrl+R), fzf equivalent for PSReadLine's history search ---
$env.config.keybindings = ($env.config.keybindings | append {
    name: fzf_history
    modifier: control
    keycode: char_r
    mode: [emacs, vi_normal, vi_insert]
    event: {
        send: executehostcommand
        cmd: "commandline edit --replace (history | get command | reverse | uniq | str join (char nul) | ^fzf --scheme=history --read0 --layout=reverse --height=40% | str trim)"
    }
})

# --- run fastfetch once at the start of each interactive session ---
# Structure/styling lives in fastfetch's own config.jsonc, not here.
if $nu.is-interactive {
    fastfetch
}

# --- strip .exe/.bat/etc from external command-name tab completions ---
# Nushell's built-in PATH scanner (completions.external.enable) always
# includes the literal filename, extension and all, with no toggle to strip
# it - so the scanner is disabled and replaced with a custom completer that
# does the same PATH glob but only for the command-name position (single
# token), stripping known executable extensions from the result.
$env.config.completions.external.enable = false
$env.config.completions.external.completer = {|spans|
    if ($spans | length) != 1 {
        return []
    }
    let prefix = ($spans | first)
    let exts = [".exe" ".bat" ".cmd" ".com" ".ps1"]
    $env.PATH
    | each {|dir|
        let clean_dir = ($dir | str replace --all '\' "/")
        try { glob $"($clean_dir)/($prefix)*" --no-dir } catch { [] }
    }
    | flatten
    | each {|p|
        mut name = ($p | path basename)
        for ext in $exts {
            if ($name | str lowercase | str ends-with $ext) {
                $name = ($name | str substring 0..<(($name | str length) - ($ext | str length)))
            }
        }
        $name
    }
    | uniq
    | sort
    | each {|name| {value: $name, description: ""} }
}
