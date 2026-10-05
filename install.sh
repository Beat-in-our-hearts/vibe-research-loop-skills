#!/usr/bin/env bash
# Install the vibe-research-loop skills for Claude Code and Codex, without keeping a clone and without sudo.
#
# Usage: curl -fsSL https://raw.githubusercontent.com/Beat-in-our-hearts/vibe-research-loop-skills/main/install.sh | bash
#        ... | bash -s -- [--version <tag|branch|commit>] [--uninstall]
#
#   (default)    Install the latest release, or update to it: download its archive to a temporary folder,
#                copy each skill into ~/.agents/skills, which Codex reads, and link it from ~/.claude/skills,
#                which Claude Code reads. Skills that the new version dropped are removed.
#   --version    Install this tag, branch, or commit instead, such as v0.1.0 or main.
#   --uninstall  Remove the skills this script installed, and their links.
#
# Only folders this script installed, marked by a .vrl-install file, are ever replaced or removed; a skill
# folder from anywhere else is left alone and reported. Links to an old clone of the repository are
# replaced, and the clone itself is left for the user to delete.
#
# Everything runs inside main(), so that bash reads the whole script before running it from a pipe.

main() {
	set -uo pipefail
	# Every path below hangs off HOME, and some of them are removed.
	[ -n "${HOME:-}" ] && [ "$HOME" != / ] || { err "HOME is not set"; return 1; }

	REPO="${VRL_REPO:-Beat-in-our-hearts/vibe-research-loop-skills}"
	CODEX_DIR="$HOME/.agents/skills"
	CLAUDE_DIR="$HOME/.claude/skills"
	MARKER=".vrl-install"

	local version="" uninstall=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--version) version="${2:-}"; shift ;;
			--version=*) version="${1#--version=}" ;;
			--uninstall) uninstall=1 ;;
			-h | --help) sed -n '2,/^# Everything runs/p' "$0" 2>/dev/null | sed '$d' | sed 's/^# \{0,1\}//'; return 0 ;;
			*) err "Unknown argument: $1"; return 2 ;;
		esac
		shift
	done

	if [ "$uninstall" = 1 ]; then
		do_uninstall
		return
	fi
	do_install "$version"
}

say() { printf '==> %s\n' "$*"; }
err() { printf 'error: %s\n' "$*" >&2; }

# Whether a folder was installed by this script.
ours() { [ -d "$1" ] && [ ! -L "$1" ] && [ -f "$1/$MARKER" ]; }

do_install() {
	local version="$1" tmp archive top src name dest link old_target old_clones="" installed="" skipped="" removed="" rc=0
	command -v curl >/dev/null 2>&1 || { err "curl is required"; return 1; }
	command -v tar >/dev/null 2>&1 || { err "tar is required"; return 1; }

	if [ -z "$version" ]; then
		version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")" || {
			err "Could not reach GitHub"
			return 1
		}
		case "$version" in
			*/tag/*) version="${version##*/}" ;;
			*) version=main; say "No release yet; installing main" ;;
		esac
	fi

	tmp="$(mktemp -d)" || return 1
	archive="$tmp/skills.tar.gz"
	say "Downloading $REPO at $version"
	if ! curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$version" -o "$archive"; then
		err "Could not download $REPO at $version: check the version"
		rm -rf "$tmp"
		return 1
	fi
	tar -xzf "$archive" -C "$tmp" || { err "Could not unpack the archive"; rm -rf "$tmp"; return 1; }
	top="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
	if [ ! -d "$top/skills" ]; then
		err "The archive has no skills folder"
		rm -rf "$tmp"
		return 1
	fi

	mkdir -p "$CODEX_DIR" "$CLAUDE_DIR" || { rm -rf "$tmp"; return 1; }

	for src in "$top"/skills/*/; do
		src="${src%/}"
		name="$(basename "$src")"
		[ -f "$src/SKILL.md" ] || continue
		dest="$CODEX_DIR/$name"
		link="$CLAUDE_DIR/$name"

		# The copy in ~/.agents/skills.
		if [ -L "$dest" ]; then
			old_target="$(readlink "$dest")"
			old_clones="$old_clones $(dirname "$(dirname "$old_target")")"
			rm -f "$dest"
		elif [ -e "$dest" ] && ! ours "$dest"; then
			skipped="$skipped $dest"
			continue
		fi
		rm -rf "$dest.vrl-new"
		if ! cp -R "$src" "$dest.vrl-new" || ! printf '%s\n' "$version" >"$dest.vrl-new/$MARKER"; then
			rm -rf "$dest.vrl-new"
			err "Could not copy $name"
			rc=1
			continue
		fi
		if ours "$dest"; then rm -rf "$dest"; fi
		mv "$dest.vrl-new" "$dest"

		# The link in ~/.claude/skills.
		if [ -L "$link" ]; then
			old_target="$(readlink "$link")"
			[ "$old_target" = "$dest" ] || old_clones="$old_clones $(dirname "$(dirname "$old_target")")"
			rm -f "$link"
		elif [ -e "$link" ]; then
			skipped="$skipped $link"
			installed="$installed $name"
			continue
		fi
		ln -s "$dest" "$link"
		installed="$installed $name"
	done
	rm -rf "$tmp"

	# Skills an earlier version installed that this one no longer has.
	for dest in "$CODEX_DIR"/*; do
		ours "$dest" || continue
		name="$(basename "$dest")"
		case " $installed " in *" $name "*) continue ;; esac
		rm -rf "$dest"
		[ "$(readlink "$CLAUDE_DIR/$name" 2>/dev/null)" = "$dest" ] && rm -f "$CLAUDE_DIR/$name"
		removed="$removed $name"
	done

	echo
	say "Installed $version:${installed:- nothing}"
	say "Copies in $CODEX_DIR, links in $CLAUDE_DIR"
	[ -z "$removed" ] || say "Removed skills this version dropped:$removed"
	if [ -n "$skipped" ]; then
		err "Left alone, since this script did not install them; remove them and run it again to replace them:"
		printf '  %s\n' $skipped >&2
		rc=1
	fi
	report_old_clones "$old_clones"
	echo
	say "Next: install the CLIs with bash $CODEX_DIR/vrl-init-workspace/scripts/setup_clis.sh, or run /vrl-init-workspace (Claude Code) or \$vrl-init-workspace (Codex) in an empty folder. Start a new session if a skill does not show up."
	return "$rc"
}

# Tell the user about clones that the replaced links pointed to; never delete them.
report_old_clones() {
	local d seen=""
	for d in $1; do
		case " $seen " in *" $d "*) continue ;; esac
		seen="$seen $d"
		[ -d "$d/.git" ] && say "Your skills no longer use the clone at $d; delete it when you no longer need it."
	done
}

do_uninstall() {
	local dest name removed=""
	for dest in "$CODEX_DIR"/*; do
		ours "$dest" || continue
		name="$(basename "$dest")"
		[ "$(readlink "$CLAUDE_DIR/$name" 2>/dev/null)" = "$dest" ] && rm -f "$CLAUDE_DIR/$name"
		rm -rf "$dest"
		removed="$removed $name"
	done
	say "Removed:${removed:- nothing; no skills from this script were found}"
}

main "$@"
