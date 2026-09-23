# Prompt (same idea as your bash PS1: green user@host, blue path)
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f '

# Colors (macOS ls)
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
alias ls='ls -G'
alias ll='ls -lah'

# Useful aliases
alias date='date; env TZ=UTC date; env TZ="America/Los_Angeles" date'
alias psmem='ps aux | sort -nr -k 4 | head -10'
alias pscpu='ps aux | sort -nr -k 3 | head -10'
alias weather='curl http://wttr.in/Miami'
alias speedtest='networkQuality'
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
alias c='clear'
alias h='history'
alias myip='curl -4 ifconfig.co'
alias awake='caffeinate -t 10800'

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# pipx
export PATH="$PATH:/Users/johnrambo/.local/bin"

# Completion
autoload -Uz compinit
compinit

# SSH/SCP hosts from ~/.ssh/config (same idea as your bash complete -F)
_ssh_hosts_from_config() {
  local -a hosts
  hosts=(${(f)"$(awk '/^Host / {for (i=2;i<=NF;i++) if ($i !~ /[?*]/) print $i}' ~/.ssh/config 2>/dev/null)"})
  compadd -- $hosts
}
compdef _ssh_hosts_from_config ssh scp

# Sleep timer: sleep 15 → Mac sleeps after 15 minutes
sleep() {
  if [[ -z "$1" ]]; then
    echo "Usage: sleep <minutes> (e.g. sleep 15)"
    return 1
  fi
  local minutes=$1
  local seconds=$((minutes * 60))
  echo "Mac will sleep in $minutes minutes..."
  ( /bin/sleep "$seconds" && osascript -e 'tell application "System Events" to sleep' ) &
}

stopsleep() {
  pkill -f "osascript -e 'tell application \"System Events\" to sleep'"
  echo "Sleep timer cancelled."
}
