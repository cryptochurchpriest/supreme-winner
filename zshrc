# ============================================================
# zsh configuration
# ============================================================

# Prompt
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f '

# Colors
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced

# ============================================================
# Aliases
# ============================================================

alias ls='ls -G'
alias ll='ls -lah'

alias c='clear'
alias h='history'
alias psmem='ps aux | sort -nr -k 4 | head -10'
alias pscpu='ps aux | sort -nr -k 3 | head -10'
alias weather='curl http://wttr.in/Miami'
alias speedtest='networkQuality'
alias tailscale='/Applications/Tailscale.app/Contents/MacOS/Tailscale'
alias myip='curl -4 ifconfig.co'
alias awake='caffeinate -t 10800'

# ============================================================
# Date / time
# ============================================================

dates() {
    /bin/date
    TZ=UTC /bin/date
    TZ=America/Los_Angeles /bin/date
}

# ============================================================
# PATH
# ============================================================

# Keep PATH entries unique and put pipx applications first.
typeset -U path PATH
path=("$HOME/.local/bin" $path)

# ============================================================
# Zsh completion
# ============================================================

autoload -Uz compinit
compinit

# SSH/SCP host completion from ~/.ssh/config
_ssh_hosts_from_config() {
    local -a hosts

    [[ -r "$HOME/.ssh/config" ]] || return

    hosts=(${(f)"$(awk '
        /^Host / {
            for (i = 2; i <= NF; i++)
                if ($i !~ /[?*]/)
                    print $i
        }
    ' "$HOME/.ssh/config" 2>/dev/null)"})

    compadd -- $hosts
}

compdef _ssh_hosts_from_config ssh scp

# ============================================================
# Mac sleep timer
# ============================================================

# Usage:
#   macsleep 15
#
# Leaves the normal /bin/sleep command untouched.
macsleep() {
    if [[ -z "$1" ]]; then
        echo "Usage: macsleep <minutes> (e.g. macsleep 15)"
        return 1
    fi

    local minutes="$1"
    local seconds=$((minutes * 60))

    echo "Mac will sleep in $minutes minutes..."

    (
        /bin/sleep "$seconds" &&
        osascript -e 'tell application "System Events" to sleep'
    ) &
}

stopsleep() {
    pkill -f '/usr/bin/osascript.*System Events.*sleep' 2>/dev/null
    echo "Sleep timer cancelled."
}
