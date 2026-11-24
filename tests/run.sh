#!/usr/bin/env bash
# Hermetic checks for omarchy-linkpick routing. Runs a copy of the repo in a
# temporary HOME with stubbed launchers, so it never opens a real browser,
# never calls the real xdg-open, and never touches an installed Linkpick.
#
#   bash tests/run.sh

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

pass=0 fail=0
ok()  { echo "ok   - $1"; pass=$((pass + 1)); }
bad() { echo "FAIL - $1"; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# Repo copy with /usr/bin/xdg-open pointed at a logging stub.
mkdir -p "$T/repo" "$T/stub" "$T/home" "$T/cwd"
cp -a "$ROOT/bin" "$ROOT/wrappers" "$ROOT/config" "$T/repo/"
sed -i "s#/usr/bin/xdg-open#$T/stub/real-xdg-open#g" "$T/repo/bin/omarchy-linkpick" "$T/repo/wrappers/xdg-open"

LOG="$T/log"
for name in real-xdg-open omarchy-launch-browser omarchy-launch-webapp fake-incognito-browser; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s"\n' "$name" "$LOG" >"$T/stub/$name"
done
cat >"$T/stub/omarchy-menu-select" <<STUB
#!/usr/bin/env bash
echo "menu \$1" >>"$LOG"
case "\$1" in
  "Open link") printf 'x\t-\t%s\n' "\${MENU_CHOICE:-browser}" ;;
  *) printf 'x\tJust once\tonce\n' ;;
esac
STUB
printf '#!/usr/bin/env bash\nexit 0\n' >"$T/stub/omarchy"
chmod +x "$T/stub/"*

export HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" XDG_STATE_HOME="$T/home/.local/state"
export PATH="$T/stub:$PATH"
unset OMARCHY_LINKPICK_WRAP
LP="$T/repo/bin/omarchy-linkpick"
HIST="$XDG_STATE_HOME/omarchy-linkpick/history.json"
mkdir -p "$HOME/.local/bin"
ln -s "$LP" "$HOME/.local/bin/omarchy-linkpick"

reset() {
  rm -rf "$XDG_CONFIG_HOME/omarchy-linkpick" "$XDG_STATE_HOME/omarchy-linkpick"
  : >"$LOG"
  "$LP" status >/dev/null
}
lp() { (cd "$T/cwd" && "$LP" "$@") >/dev/null 2>&1; }
hist_has() { [[ -f $HIST ]] && grep -q -- "$1" "$HIST"; }

echo "# 1. Private opens are not recorded (#1)"
reset
MENU_CHOICE=browser-private lp open 'https://example.com/private-path'
check "private browser launched with --private" "grep -q 'omarchy-launch-browser --private https://example.com/private-path' '$LOG'"
check "private open not in history.json" "! hist_has private-path"
reset
MENU_CHOICE=browser lp open 'https://example.com/normal-path'
check "normal open still recorded" "hist_has normal-path"
reset
"$LP" always example.org incog >/dev/null
tmp=$(mktemp); jq '.handlers += [{"id":"incog","name":"Incog","command":["fake-incognito-browser","--incognito","{url}"]}]' \
  "$XDG_CONFIG_HOME/omarchy-linkpick/config.json" >"$tmp" && mv "$tmp" "$XDG_CONFIG_HOME/omarchy-linkpick/config.json"
lp open 'https://example.org/incog-path'
check "--incognito handler launched" "grep -q 'fake-incognito-browser --incognito https://example.org/incog-path' '$LOG'"
check "--incognito open not in history.json" "! hist_has incog-path"

echo "# 2. Existing local files stay files (#2)"
touch "$T/cwd/notes.md" "$T/cwd/report.pdf"
reset
(cd "$T/cwd" && "$T/repo/wrappers/xdg-open" notes.md) >/dev/null 2>&1
check "wrapper sends existing notes.md to real xdg-open" "grep -qx 'real-xdg-open notes.md' '$LOG'"
check "wrapper did not open a browser for notes.md" "! grep -q 'launch-browser' '$LOG'"
reset
"$LP" disable >/dev/null; : >"$LOG"
lp open report.pdf
check "interception off: report.pdf goes to real xdg-open" "grep -qx 'real-xdg-open report.pdf' '$LOG'"
check "interception off: no https://report.pdf" "! grep -q 'https://report.pdf' '$LOG'"
: >"$LOG"
(cd "$T/cwd" && "$T/repo/wrappers/xdg-open" example.net) >/dev/null 2>&1
check "non-existent example.net still routed as https" "grep -qx 'omarchy-launch-browser https://example.net' '$LOG'"

echo "# 3. Explicit always=ask beats preferred (#3)"
reset
"$LP" set-ask off >/dev/null
"$LP" preferred example.com browser >/dev/null
"$LP" always example.com ask >/dev/null
: >"$LOG"
MENU_CHOICE=browser lp open 'https://example.com/ask-path'
check "chooser shown despite preferred handler" "grep -qx 'menu Open link' '$LOG'"
reset
"$LP" set-ask off >/dev/null
"$LP" preferred example.com browser >/dev/null
: >"$LOG"
lp open 'https://example.com/pref-path'
check "preferred alone still opens without chooser" "grep -qx 'omarchy-launch-browser https://example.com/pref-path' '$LOG' && ! grep -q '^menu' '$LOG'"

echo "# 4. Omarchy notice kept (#4)"
check "omarchy-cmd-default-browser keeps the Omarchy copyright and MIT notice" \
  "grep -q '^# Copyright (c) David Heinemeier Hansson' '$ROOT/wrappers/omarchy-cmd-default-browser' && grep -q 'The above copyright notice and this permission notice shall be' '$ROOT/wrappers/omarchy-cmd-default-browser'"

echo "# $pass passed, $fail failed"
(( fail == 0 ))
