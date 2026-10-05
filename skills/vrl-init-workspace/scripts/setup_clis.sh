#!/usr/bin/env bash
# Install and log in to the CLIs of vibe-research-loop: uv, ntn (Notion), gh (GitHub), and hf (Hugging Face).
# Everything goes into the user's home directory; nothing needs sudo.
#
# Usage: setup_clis.sh [check|install|login|all] [--upgrade] [--only uv,ntn,gh,hf] [--workspace DIR]
#
#   check        Show which tools are installed, their versions, and which are logged in. Changes nothing.
#   install      Install each tool that ~/.local/bin lacks into ~/.local/bin, on macOS and Linux alike,
#                even if another copy exists elsewhere, such as from Homebrew or apt; that copy stays.
#   login        Log in to ntn, gh, and hf where not logged in yet. In a terminal, each CLI runs its own
#                login. Without one, as under an agent or `ssh host 'bash -s'`, each prints a URL and a
#                code to open in any browser, then waits for the approval. Tokens never pass through here.
#   all          install, then login (the default).
#
#   --upgrade    With install or all: also upgrade the tools already in ~/.local/bin to their latest
#                release. uv, ntn, and gh are reinstalled only when a newer release exists; hf is
#                left to `uv tool install --upgrade`.
#   --only       A comma-separated subset of uv,ntn,gh,hf (default: all four).
#   --workspace  The workspace root whose .env to load (default: the current directory, if it has one).
#                hf keeps its login under XDG_CACHE_HOME, which .env sets, so the hf login is refused
#                while that .env does not exist yet; everything else runs without it.
#
# On another host: ssh host 'bash -s -- install --only uv,hf --workspace /abs/path' < setup_clis.sh
#
# Everything runs inside main(), so that bash reads the whole script before running it when the
# script comes in on stdin.

main() {
	set -uo pipefail

	local cmd="all" only="uv,ntn,gh,hf" workspace=""
	UPGRADE=0
	while [ $# -gt 0 ]; do
		case "$1" in
			check | install | login | all) cmd="$1" ;;
			--upgrade) UPGRADE=1 ;;
			--only) only="${2:-}"; shift ;;
			--only=*) only="${1#--only=}" ;;
			--workspace) workspace="${2:-}"; shift ;;
			--workspace=*) workspace="${1#--workspace=}" ;;
			-h | --help) sed -n '2,/^# On another host/p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; return 0 ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done

	TOOLS=""
	local t
	for t in ${only//,/ }; do
		case "$t" in
			uv | ntn | gh | hf) TOOLS="$TOOLS $t" ;;
			*) err "Unknown tool: $t (choose from uv, ntn, gh, hf)"; return 2 ;;
		esac
	done
	[ -n "$TOOLS" ] || { err "--only lists no tool"; return 2; }
	case "$UPGRADE:$cmd" in
		1:check | 1:login) err "--upgrade goes with install or all"; return 2 ;;
	esac

	if [ -t 0 ] && [ -t 1 ]; then INTERACTIVE=1; else INTERACTIVE=0; fi
	OS="$(uname -s)"
	ARCH="$(uname -m)"
	NOTES=""
	FAILED=""
	ENV_MISSING=""

	load_env "$workspace"
	BIN_DIR="$HOME/.local/bin"
	BIN_SHOWN="\$HOME/.local/bin"
	# The user's PATH, to tell where their shell finds each tool; this script itself runs the copies in
	# ~/.local/bin first.
	ORIG_PATH="$PATH"
	export PATH="$BIN_DIR:$PATH"
	case ":$ORIG_PATH:" in
		*":$BIN_DIR:"*) ;;
		*) note "$BIN_SHOWN is not on PATH. Add this line to your shell profile: export PATH=\"$BIN_SHOWN:\$PATH\"" ;;
	esac
	setup_notion_keyring

	case "$cmd" in
		check) ;;
		install) do_install ;;
		login) do_login ;;
		all) do_install; do_login ;;
	esac

	echo
	report "$cmd"
	local report_ok=$?
	if [ -n "$NOTES" ]; then
		echo
		printf '%b' "$NOTES"
	fi
	if [ -n "$FAILED" ]; then
		echo
		err "Failed:$FAILED"
		return 1
	fi
	return "$report_ok"
}

say() { printf '==> %s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }
note() { NOTES="${NOTES}note: $*\n"; }
fail() { FAILED="$FAILED $1"; err "$2"; }
has() { command -v "$1" >/dev/null 2>&1; }

# The first copy of a command on the user's PATH, which is what their shell runs.
first_on_path() {
	local d IFS=:
	for d in $ORIG_PATH; do
		[ -n "$d" ] && [ -x "$d/$1" ] && [ ! -d "$d/$1" ] && { echo "$d/$1"; return 0; }
	done
	return 1
}
wants() { case " $TOOLS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

load_env() {
	local ws="$1"
	if [ -z "$ws" ]; then
		[ -f "$PWD/.env" ] || return 0
		ws="$PWD"
	fi
	if [ ! -f "$ws/.env" ]; then
		# Setup installs the tools before the workspace has a .env; only the hf login needs it.
		ENV_MISSING="$ws"
		note "No .env in $ws yet, so this ran without it. Log in to hf only once it exists."
		return 0
	fi
	set -a
	# shellcheck disable=SC1091
	. "$ws/.env"
	set +a
	say "Loaded $ws/.env"
}

# Linux without a Secret Service (no D-Bus session, as in containers and SSH sessions) has no keychain,
# so ntn must keep its token in a file instead.
setup_notion_keyring() {
	wants ntn || return 0
	[ "$OS" = Linux ] || return 0
	[ -z "${NOTION_KEYRING:-}" ] || return 0
	[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 0
	export NOTION_KEYRING=0
	note "This machine has no keychain, so ntn keeps its token in a plain file (NOTION_KEYRING=0). Every later ntn command needs it too: add this line to your shell profile: export NOTION_KEYRING=0"
}

# ---------- state ----------

version_of() {
	local out
	case "$1" in
		hf) out="$(hf version 2>/dev/null </dev/null)" ;;
		*) out="$("$1" --version 2>/dev/null </dev/null)" ;;
	esac
	printf '%s\n' "$out" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1
}

# ok: in ~/.local/bin. elsewhere: only outside it. missing: nowhere. outdated: hf without buckets.
status_of() {
	if [ ! -x "$BIN_DIR/$1" ]; then
		if first_on_path "$1" >/dev/null; then echo elsewhere; else echo missing; fi
		return
	fi
	if [ "$1" = hf ] && ! "$BIN_DIR/hf" buckets --help >/dev/null 2>&1 </dev/null; then
		echo outdated
		return
	fi
	echo ok
}

logged_in() {
	case "$1" in
		ntn) ntn api v1/users/me >/dev/null 2>&1 </dev/null ;;
		gh) gh auth status --hostname github.com >/dev/null 2>&1 </dev/null ;;
		hf)
			# Older versions print "Not logged in" and still exit 0.
			local out
			out="$(hf auth whoami 2>&1 </dev/null)" || return 1
			! printf '%s' "$out" | grep -qi 'not logged in'
			;;
		*) return 1 ;;
	esac
}

# Exits non-zero if a tool is not ok, or, except after install, not logged in.
report() {
	local t status version login where shadow all_ok=0
	printf '%-5s %-9s %-10s %-6s %s\n' TOOL STATUS VERSION LOGIN PATH
	for t in $TOOLS; do
		status="$(status_of "$t")"
		version="-"; login="-"; where="-"
		if [ "$status" != missing ]; then
			version="$(version_of "$t")"
			where="$(command -v "$t")"
			shadow="$(first_on_path "$t")"
			if [ "$status" != elsewhere ] && [ -n "$shadow" ] && [ "$shadow" != "$BIN_DIR/$t" ]; then
				note "Your shell runs $shadow, which comes before $BIN_SHOWN on PATH: put $BIN_SHOWN first in PATH, or remove that copy."
			fi
			if [ "$t" != uv ]; then
				if logged_in "$t"; then
					login=yes
				else
					login=no
					[ "$1" = install ] || all_ok=1
				fi
			fi
		fi
		[ "$status" = ok ] || all_ok=1
		printf '%-5s %-9s %-10s %-6s %s\n' "$t" "$status" "${version:--}" "$login" "$where"
	done
	return "$all_ok"
}

# ---------- install ----------

do_install() {
	has curl || { fail install "curl is required to install anything"; return; }
	local t
	# uv first: hf is installed with it.
	for t in uv ntn gh hf; do
		wants "$t" || continue
		case "$(status_of "$t")" in
			ok)
				if [ "$UPGRADE" = 1 ]; then
					upgrade_one "$t"
				else
					say "$t is already installed: $BIN_DIR/$t"
				fi
				continue
				;;
			outdated) say "$t has no 'hf buckets'; installing a newer one" ;;
			elsewhere) say "Installing $t into $BIN_DIR, besides $(first_on_path "$t")" ;;
			missing) say "Installing $t" ;;
		esac
		"install_$t"
		hash -r
		if [ "$(status_of "$t")" = ok ]; then
			say "$t $(version_of "$t") is ready: $(command -v "$t")"
		else
			fail "$t" "Could not install $t"
		fi
	done
}

# The latest release of uv, ntn, or gh, as a bare version such as 1.2.3.
latest_version() {
	local v
	case "$1" in
		uv) v="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/astral-sh/uv/releases/latest)" ;;
		gh) v="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest)" ;;
		ntn) v="$(curl -fsSL https://ntn.dev/latest.txt)" ;;
	esac || return 1
	v="${v##*/}"
	v="$(printf '%s' "${v#v}" | tr -d '[:space:]')"
	case "$v" in [0-9]*) echo "$v" ;; *) return 1 ;; esac
}

# Whether version $1 is older than version $2, field by field.
version_lt() {
	local IFS=. i x y
	local -a a b
	a=(${1%%-*})
	b=(${2%%-*})
	for i in 0 1 2; do
		x="${a[i]:-0}"
		y="${b[i]:-0}"
		[ "$x" -lt "$y" ] && return 0
		[ "$x" -gt "$y" ] && return 1
	done
	return 1
}

upgrade_one() {
	local t="$1" old new latest=""
	old="$(version_of "$t")"
	if [ "$t" != hf ]; then
		if ! latest="$(latest_version "$t")"; then
			fail "$t" "Could not find the latest release of $t"
			return
		fi
		if ! version_lt "$old" "$latest"; then
			say "$t $old is the latest release"
			return
		fi
		say "Upgrading $t $old to $latest"
	fi
	"install_$t"
	hash -r
	new="$(version_of "$t")"
	if [ "$(status_of "$t")" != ok ] || { [ -n "$latest" ] && [ "$new" != "$latest" ]; }; then
		fail "$t" "Could not upgrade $t"
	elif [ "$new" = "$old" ]; then
		say "$t $old is the latest release"
	else
		say "$t is upgraded: $old -> $new"
	fi
}

install_uv() {
	# Leave the shell profiles alone.
	curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$BIN_DIR" UV_NO_MODIFY_PATH=1 sh
}

install_ntn() {
	# A static binary, checked against its published SHA-256.
	curl -fsSL https://ntn.dev | env NTN_INSTALL_DIR="$BIN_DIR" bash
}

install_gh() {
	# No installer script exists, so take the release archive, check it, and copy the binary.
	local os ext arch tag version name dir rc=1
	case "$OS" in
		Linux) os=linux; ext=tar.gz ;;
		Darwin) os=macOS; ext=zip ;;
		*) err "Unsupported OS for gh: $OS"; return 1 ;;
	esac
	case "$ARCH" in
		x86_64 | amd64) arch=amd64 ;;
		aarch64 | arm64) arch=arm64 ;;
		*) err "Unsupported architecture for gh: $ARCH"; return 1 ;;
	esac
	tag="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest)" || return 1
	tag="${tag##*/}"
	version="${tag#v}"
	case "$version" in [0-9]*) ;; *) err "Could not find the latest gh release"; return 1 ;; esac
	name="gh_${version}_${os}_${arch}"
	dir="$(mktemp -d)" || return 1
	(
		set -e
		cd "$dir"
		curl -fsSLO "https://github.com/cli/cli/releases/download/$tag/$name.$ext"
		curl -fsSLO "https://github.com/cli/cli/releases/download/$tag/gh_${version}_checksums.txt"
		grep " $name.$ext\$" "gh_${version}_checksums.txt" >expected.sha256
		if has sha256sum; then sha256sum -c expected.sha256; else shasum -a 256 -c expected.sha256; fi
		if [ "$ext" = zip ]; then unzip -q "$name.$ext"; else tar -xzf "$name.$ext"; fi
		mkdir -p "$BIN_DIR"
		cp "$name/bin/gh" "$BIN_DIR/gh"
		chmod 0755 "$BIN_DIR/gh"
	) && rc=0
	rm -rf "$dir"
	return "$rc"
}

install_hf() {
	# With uv, hf gets a Python of its own, so it needs neither a system Python nor sudo. Without
	# --python, uv may pick an old system Python, such as macOS's 3.9, and resolve an old hf.
	if has uv; then
		# --force replaces an hf left in ~/.local/bin by something else, such as pip install --user.
		env UV_TOOL_BIN_DIR="$BIN_DIR" uv tool install --upgrade --force --python 3.12 hf </dev/null
		return
	fi
	# Without uv, the official installer needs Python 3.10+ with venv. Skip its bundled agent skill and
	# leave the shell profiles alone.
	curl -LsSf https://hf.co/cli/install.sh | env HF_CLI_BIN_DIR="$BIN_DIR" bash -s -- --exclude-skill --no-modify-path
}

# ---------- login ----------

do_login() {
	local t
	for t in ntn gh hf; do
		wants "$t" || continue
		if [ "$(status_of "$t")" = missing ]; then
			fail "$t" "$t is not installed; run install first"
			continue
		fi
		if [ "$t" = hf ] && [ -n "$ENV_MISSING" ]; then
			fail hf "No .env in $ENV_MISSING yet: log in to hf once it exists, since XDG_CACHE_HOME decides where hf keeps its login"
			continue
		fi
		if logged_in "$t"; then
			say "$t is already logged in"
			continue
		fi
		say "Logging in to $t"
		if "login_$t" && logged_in "$t"; then
			say "$t is logged in"
		else
			fail "$t" "Could not log in to $t"
		fi
	done
}

# Whether a browser can open on this machine, for logins that open one themselves.
can_open_browser() {
	[ -z "${SSH_CONNECTION:-}" ] || return 1
	case "$OS" in
		Darwin) return 0 ;;
		*) [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] ;;
	esac
}

login_ntn() {
	if [ "$INTERACTIVE" = 1 ] && can_open_browser; then
		ntn login
		return
	fi
	# Two steps: start the login, which prints a URL and a code, then poll, which waits for the approval.
	ntn login --no-browser </dev/null || return 1
	say "Open the URL above in any browser, check that it shows the code above, and approve."
	ntn login poll </dev/null
}

login_gh() {
	# Without a terminal, gh prints a one-time code and a URL, then waits for the approval.
	if [ "$INTERACTIVE" = 1 ]; then
		gh auth login --hostname github.com --git-protocol https --web
	else
		gh auth login --hostname github.com --git-protocol https --web </dev/null || return 1
		# What an interactive login offers by default: let git use this login for https://github.com.
		gh auth setup-git --hostname github.com </dev/null &&
			say "git now uses this GitHub login for https://github.com remotes"
	fi
}

login_hf() {
	# Without a terminal, --format agent prints a URL and a code, then waits for the approval.
	if [ "$INTERACTIVE" = 1 ]; then
		hf auth login
	else
		hf auth login --format agent </dev/null
	fi
}

main "$@"
