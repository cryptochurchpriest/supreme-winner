#!/bin/bash

STAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT="$HOME/Desktop/Mac-systemwide-audit-$STAMP.txt"

section() {
  printf '\n'
  printf '%s\n' \
    '============================================================'
  printf '%s\n' "$1"
  printf '%s\n' \
    '============================================================'
}

echo "Administrator access is required for a complete audit."
sudo -v || exit 1

exec > >(tee "$REPORT") 2>&1

echo "Mac system-wide cleanup audit"
echo "Generated: $(date)"
echo "Computer: $(scutil --get ComputerName 2>/dev/null)"
echo "macOS: $(sw_vers -productVersion 2>/dev/null)"
echo "Architecture: $(uname -m)"
echo "User: $(id -un)"
echo "Report: $REPORT"
echo
echo "This report is read-only. No files were deleted."

section "DISK SPACE"

df -h
echo

diskutil apfs list 2>/dev/null |
  grep -E \
    'APFS Container|Capacity Ceiling|Capacity In Use|Capacity Not Allocated'

section "LOCAL USER ACCOUNTS"

dscl . -list /Users UniqueID 2>/dev/null |
  awk '$2 >= 500 {print}' |
  sort -k2n

section "HOME DIRECTORY USAGE"

for home in /Users/*; do
  [[ -d "$home" ]] || continue
  sudo du -x -h -d 1 "$home" 2>/dev/null |
    sort -h
done

section "USER LIBRARY USAGE"

for home in /Users/*; do
  [[ -d "$home/Library" ]] || continue

  echo
  echo "--- $home/Library ---"

  sudo du -x -h -d 1 "$home/Library" 2>/dev/null |
    sort -h |
    tail -80
done

section "SYSTEM LIBRARY THIRD-PARTY LOCATIONS"

for directory in \
  "/Library/Application Support" \
  "/Library/Audio/Plug-Ins" \
  "/Library/Extensions" \
  "/Library/Filesystems" \
  "/Library/Frameworks" \
  "/Library/Internet Plug-Ins" \
  "/Library/PreferencePanes" \
  "/Library/Printers" \
  "/Library/Screen Savers" \
  "/Library/Security" \
  "/Library/SystemExtensions"; do

  if [[ -d "$directory" ]]; then
    echo
    echo "--- $directory ---"

    sudo du -x -h -d 2 "$directory" 2>/dev/null |
      sort -h |
      tail -100
  fi
done

section "INSTALLED APPLICATIONS AND BUNDLE IDENTIFIERS"

sudo find \
  /Applications \
  /System/Applications \
  /Users/*/Applications \
  -maxdepth 4 \
  -type d \
  -name '*.app' \
  -print0 2>/dev/null |
while IFS= read -r -d '' app; do
  plist="$app/Contents/Info.plist"
  bundle_id="unknown"
  version="unknown"

  if [[ -f "$plist" ]]; then
    bundle_id=$(
      /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleIdentifier' \
        "$plist" 2>/dev/null
    )

    version=$(
      /usr/libexec/PlistBuddy \
        -c 'Print :CFBundleShortVersionString' \
        "$plist" 2>/dev/null
    )

    [[ -n "$bundle_id" ]] || bundle_id="unknown"
    [[ -n "$version" ]] || version="unknown"
  fi

  printf '%s | %s | %s\n' "$bundle_id" "$version" "$app"
done |
  sort -f

section "APPLICATIONS IN USER TRASH DIRECTORIES"

sudo find /Users/*/.Trash \
  -maxdepth 4 \
  -type d \
  -name '*.app' \
  -print 2>/dev/null |
  sort -f

section "USER LAUNCH AGENTS"

sudo find /Users/*/Library/LaunchAgents \
  -maxdepth 1 \
  -type f \
  -name '*.plist' \
  -print 2>/dev/null |
  sort -f

section "SYSTEM LAUNCH AGENTS"

sudo find /Library/LaunchAgents \
  -maxdepth 1 \
  -type f \
  -name '*.plist' \
  -print 2>/dev/null |
  sort -f

section "SYSTEM LAUNCH DAEMONS"

sudo find /Library/LaunchDaemons \
  -maxdepth 1 \
  -type f \
  -name '*.plist' \
  -print 2>/dev/null |
  sort -f

section "LAUNCH SERVICE EXECUTABLE REFERENCES"

for plist in \
  /Library/LaunchAgents/*.plist \
  /Library/LaunchDaemons/*.plist \
  /Users/*/Library/LaunchAgents/*.plist; do

  [[ -f "$plist" ]] || continue

  label=$(
    sudo /usr/libexec/PlistBuddy \
      -c 'Print :Label' "$plist" 2>/dev/null
  )

  program=$(
    sudo /usr/libexec/PlistBuddy \
      -c 'Print :Program' "$plist" 2>/dev/null
  )

  if [[ -z "$program" ]]; then
    program=$(
      sudo /usr/libexec/PlistBuddy \
        -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null
    )
  fi

  printf '%s | %s | %s\n' \
    "${label:-unknown}" \
    "${program:-unknown}" \
    "$plist"
done |
  sort -f

section "POSSIBLY BROKEN LAUNCH SERVICE REFERENCES"

for plist in \
  /Library/LaunchAgents/*.plist \
  /Library/LaunchDaemons/*.plist \
  /Users/*/Library/LaunchAgents/*.plist; do

  [[ -f "$plist" ]] || continue

  program=$(
    sudo /usr/libexec/PlistBuddy \
      -c 'Print :Program' "$plist" 2>/dev/null
  )

  if [[ -z "$program" ]]; then
    program=$(
      sudo /usr/libexec/PlistBuddy \
        -c 'Print :ProgramArguments:0' "$plist" 2>/dev/null
    )
  fi

  if [[ "$program" = /* && ! -e "$program" ]]; then
    echo "$plist"
    echo "    Missing executable: $program"
  fi
done

section "PRIVILEGED HELPER TOOLS"

sudo find /Library/PrivilegedHelperTools \
  -maxdepth 1 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "LOGIN AND BACKGROUND ITEMS"

if command -v sfltool >/dev/null 2>&1; then
  sudo sfltool dumpbtm 2>/dev/null
else
  echo "sfltool is unavailable."
fi

section "SYSTEM EXTENSIONS"

systemextensionsctl list 2>/dev/null

section "NON-APPLE KERNEL EXTENSIONS"

kmutil showloaded 2>/dev/null |
  grep -v 'com.apple' |
  head -200

section "NETWORK SERVICES"

networksetup -listallnetworkservices 2>/dev/null

section "VPN AND NETWORK INTERFACES"

scutil --nc list 2>/dev/null
echo
ifconfig -l 2>/dev/null

section "NETWORK SYSTEM EXTENSION CONFIGURATION"

sudo find \
  "/Library/Preferences/SystemConfiguration" \
  -maxdepth 1 \
  -type f \
  -print 2>/dev/null |
  sort -f

section "AUDIO DRIVERS AND HAL PLUG-INS"

sudo find \
  "/Library/Audio/Plug-Ins/HAL" \
  "/Library/Audio/Plug-Ins/Components" \
  "/Library/Audio/Plug-Ins/VST" \
  "/Library/Audio/Plug-Ins/VST3" \
  -maxdepth 3 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "SECURITY AUTHORIZATION PLUG-INS"

sudo find \
  /Library/Security/SecurityAgentPlugins \
  -maxdepth 3 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "PACKAGE RECEIPTS: NON-APPLE"

pkgutil --pkgs 2>/dev/null |
  grep -vE '^com\.apple\.|^com\.macos\.' |
  sort -f

section "INSTALLER RECEIPT DATABASE FILES"

sudo find /Library/Receipts /private/var/db/receipts \
  -maxdepth 2 \
  -type f \
  ! -name 'com.apple.*' \
  -print 2>/dev/null |
  sort -f

section "HOMEBREW STATUS"

if command -v brew >/dev/null 2>&1; then
  echo "Homebrew: $(command -v brew)"
  echo

  echo "--- Formulae ---"
  brew list --formula --versions 2>/dev/null

  echo
  echo "--- Casks ---"
  brew list --cask --versions 2>/dev/null

  echo
  echo "--- Outdated ---"
  brew outdated 2>/dev/null

  echo
  echo "--- Diagnostic ---"
  brew doctor 2>&1
else
  echo "Homebrew command not found."
fi

section "MACPORTS STATUS"

if command -v port >/dev/null 2>&1; then
  port installed 2>/dev/null
else
  echo "MacPorts command not found."
fi

section "USR LOCAL INVENTORY"

if [[ -d /usr/local ]]; then
  sudo du -x -h -d 2 /usr/local 2>/dev/null |
    sort -h |
    tail -150
else
  echo "/usr/local does not exist."
fi

section "OPT HOMEBREW INVENTORY"

if [[ -d /opt/homebrew ]]; then
  sudo du -x -h -d 2 /opt/homebrew 2>/dev/null |
    sort -h |
    tail -150
else
  echo "/opt/homebrew does not exist."
fi

section "THIRD-PARTY SYSTEM PREFERENCES"

sudo find /Library/Preferences \
  -maxdepth 2 \
  -type f \
  ! -name 'com.apple.*' \
  ! -name '.DS_Store' \
  -print 2>/dev/null |
  sort -f

section "THIRD-PARTY USER PREFERENCES"

sudo find /Users/*/Library/Preferences \
  -maxdepth 2 \
  -type f \
  ! -name 'com.apple.*' \
  ! -name 'group.com.apple.*' \
  ! -name '.DS_Store' \
  -print 2>/dev/null |
  sort -f

section "USER APPLICATION SUPPORT INVENTORY"

for home in /Users/*; do
  directory="$home/Library/Application Support"
  [[ -d "$directory" ]] || continue

  echo
  echo "--- $directory ---"

  sudo du -x -h -d 1 "$directory" 2>/dev/null |
    sort -h |
    tail -120
done

section "USER CONTAINER INVENTORY"

for home in /Users/*; do
  directory="$home/Library/Containers"
  [[ -d "$directory" ]] || continue

  echo
  echo "--- $directory ---"

  sudo du -x -h -d 1 "$directory" 2>/dev/null |
    sort -h |
    tail -120
done

section "USER GROUP CONTAINER INVENTORY"

for home in /Users/*; do
  directory="$home/Library/Group Containers"
  [[ -d "$directory" ]] || continue

  echo
  echo "--- $directory ---"

  sudo du -x -h -d 1 "$directory" 2>/dev/null |
    sort -h |
    tail -120
done

section "USER CACHE INVENTORY"

for home in /Users/*; do
  directory="$home/Library/Caches"
  [[ -d "$directory" ]] || continue

  echo
  echo "--- $directory ---"

  sudo du -x -h -d 1 "$directory" 2>/dev/null |
    sort -h |
    tail -100
done

section "USER SAVED APPLICATION STATES"

sudo find /Users/*/Library/Saved\ Application\ State \
  -maxdepth 1 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "USER HTTP STORAGE"

sudo find /Users/*/Library/HTTPStorages \
  -maxdepth 1 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "USER WEBKIT DATA"

sudo find /Users/*/Library/WebKit \
  -maxdepth 1 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "FILE PROVIDER DATA"

sudo find /Users/*/Library/Application\ Support/FileProvider \
  -maxdepth 3 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "CLOUD STORAGE PROVIDERS"

sudo find /Users/*/Library/CloudStorage \
  -maxdepth 3 \
  -mindepth 1 \
  -print 2>/dev/null |
  sort -f

section "KNOWN LEGACY AND REMOVED-APP NAME CANDIDATES"

sudo find \
  /Applications \
  /Library \
  /usr/local \
  /opt/homebrew \
  /Users \
  -xdev \
  \( \
    -path '*/Photos Library.photoslibrary/*' -o \
    -path '*/Library/Metadata/*' -o \
    -path '*/Library/Caches/com.apple.*' -o \
    -path '*/.Trash/*' \
  \) -prune -o \
  \( \
    -iname '*parallels*' -o \
    -iname '*zerotier*' -o \
    -iname '*getdropbox*' -o \
    -iname 'com.dropbox*' -o \
    -iname '*dropbox*.plist' -o \
    -iname '*protonvpn*' -o \
    -iname '*keybase*' -o \
    -iname '*capcut*' -o \
    -iname '*com.lemon.lvoverseas*' -o \
    -iname '*valvesoftware*' -o \
    -iname '*firefox*' -o \
    -iname 'org.mozilla*' -o \
    -iname '*wondershare*' -o \
    -iname '*crossover*' -o \
    -iname '*beachcube*' -o \
    -iname '*utopia*' -o \
    -iname '*trinity*' -o \
    -iname '*mikrotik*' -o \
    -iname '*tutanota*' -o \
    -iname '*node_modules*' -o \
    -iname '*angular*' -o \
    -iname '.npm' \
  \) -print 2>/dev/null |
  sort -f

section "BROKEN SYMBOLIC LINKS IN THIRD-PARTY LOCATIONS"

for root in \
  /Applications \
  /Library \
  /usr/local \
  /opt/homebrew \
  /Users/*/Applications \
  /Users/*/Library/Application\ Support \
  /Users/*/Library/LaunchAgents; do

  [[ -e "$root" ]] || continue

  sudo find "$root" \
    -xdev \
    -type l \
    ! -exec test -e {} \; \
    -print 2>/dev/null
done |
  sort -f |
  head -1000

section "BROKEN SYMBOLIC LINKS IN USR LOCAL BIN"

sudo find /usr/local/bin \
  -maxdepth 1 \
  -type l \
  ! -exec test -e {} \; \
  -print 2>/dev/null |
  sort -f

section "BROKEN SYMBOLIC LINKS IN HOMEBREW BIN"

sudo find /opt/homebrew/bin \
  -maxdepth 1 \
  -type l \
  ! -exec test -e {} \; \
  -print 2>/dev/null |
  sort -f

section "SHELL STARTUP FILE REFERENCES"

for file in \
  /etc/profile \
  /etc/bashrc \
  /etc/zprofile \
  /etc/zshrc \
  /etc/paths \
  /Users/*/.profile \
  /Users/*/.bash_profile \
  /Users/*/.bashrc \
  /Users/*/.zprofile \
  /Users/*/.zshrc; do

  [[ -f "$file" ]] || continue
  echo
  echo "--- $file ---"
  sudo grep -vE '^[[:space:]]*(#|$)' "$file" 2>/dev/null
done

section "CUSTOM PATH CONFIGURATION"

sudo find /etc/paths.d /etc/manpaths.d \
  -maxdepth 1 \
  -type f \
  -print 2>/dev/null |
while IFS= read -r file; do
  echo
  echo "--- $file ---"
  sudo cat "$file" 2>/dev/null
done

section "USER AND SYSTEM CRON JOBS"

echo "--- Root crontab ---"
sudo crontab -l 2>/dev/null || echo "No root crontab."

for home in /Users/*; do
  [[ -d "$home" ]] || continue
  user="$(basename "$home")"

  id "$user" >/dev/null 2>&1 || continue

  echo
  echo "--- Crontab for $user ---"
  sudo crontab -u "$user" -l 2>/dev/null ||
    echo "No crontab for $user."
done

section "RUNNING THIRD-PARTY PROCESSES"

ps -axo pid,user,command |
  grep -vE \
    '/System/Library|/usr/libexec|/usr/sbin|/usr/bin|kernel_task' |
  grep -v '[g]rep' |
  head -500

section "LARGEST SYSTEM APPLICATION SUPPORT DIRECTORIES"

sudo du -x -h -d 2 "/Library/Application Support" 2>/dev/null |
  sort -h |
  tail -100

section "LARGEST FILES IN MUTABLE SYSTEM LOCATIONS"

sudo find \
  /Applications \
  /Library \
  /usr/local \
  /opt/homebrew \
  /Users \
  -xdev \
  \( \
    -path '*/Photos Library.photoslibrary/*' -o \
    -path '*/.Trash/*' \
  \) -prune -o \
  -type f \
  -size +1G \
  -exec du -h {} + 2>/dev/null |
  sort -h |
  tail -200

section "OLD INSTALLERS, DISK IMAGES, AND ARCHIVES"

sudo find /Users \
  -xdev \
  \( \
    -path '*/Library/*' -o \
    -path '*/Photos Library.photoslibrary/*' -o \
    -path '*/.Trash/*' \
  \) -prune -o \
  -type f \
  \( \
    -iname '*.dmg' -o \
    -iname '*.pkg' -o \
    -iname '*.iso' -o \
    -iname '*.xip' -o \
    -iname '*.zip' -o \
    -iname '*.rar' -o \
    -iname '*.7z' \
  \) \
  -exec du -h {} + 2>/dev/null |
  sort -h

section "FOCUSED REMOVED-SOFTWARE VERIFICATION"

echo "--- Commands ---"

for command_name in node npm npx ng; do
  if command -v "$command_name" >/dev/null 2>&1; then
    echo "$command_name: $(command -v "$command_name")"
  else
    echo "$command_name: not installed"
  fi
done

echo
echo "--- Processes ---"

pgrep -afil \
  'zerotier|dropbox|parallels|prl_|node|npm|angular' ||
  echo "No matching processes."

echo
echo "--- Launch services ---"

sudo find \
  /Library/LaunchAgents \
  /Library/LaunchDaemons \
  /Users/*/Library/LaunchAgents \
  -maxdepth 1 \
  -type f 2>/dev/null |
  grep -iE \
    'zerotier|dropbox|parallels|node|npm|angular' ||
  echo "No matching launch services."

echo
echo "--- Package receipts ---"

pkgutil --pkgs 2>/dev/null |
  grep -iE \
    'zerotier|dropbox|parallels|node|npm|angular' ||
  echo "No matching package receipts."

section "AUDIT COMPLETE"

echo "No files were deleted."
echo
echo "Report saved to:"
echo "$REPORT"
