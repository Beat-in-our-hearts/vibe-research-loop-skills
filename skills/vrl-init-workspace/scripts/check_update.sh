#!/usr/bin/env bash
# Tell the user when a newer release of the vibe-research-loop skills is out; never update anything.
#
# Usage: bash <skills folder>/vrl-init-workspace/scripts/check_update.sh
#
# Compares the release that install.sh recorded in this skill's .vrl-install with the latest release on
# GitHub, and prints two lines, the news and the update command, when the latest is newer; otherwise nothing.
# Asks GitHub at most once a day, keeping the answer in .vrl-latest next to .vrl-install, which the next
# install replaces along with the folder. Prints nothing and exits 0 whenever it cannot tell: no
# .vrl-install, as in a clone of the repository; an install of a branch or commit rather than a release;
# or GitHub not answering within 3 seconds.
#
# Everything runs inside main(), so that bash reads the whole script before running it.

main() {
	set -uo pipefail
	local repo dir installed cache latest
	repo="${VRL_REPO:-Beat-in-our-hearts/vibe-research-loop-skills}"
	dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" || return 0
	installed="$(head -n 1 "$dir/.vrl-install" 2>/dev/null)" || return 0
	case "$installed" in v[0-9]*) ;; *) return 0 ;; esac
	cache="$dir/.vrl-latest"

	if [ -f "$cache" ] && [ -n "$(find "$cache" -mmin -1440 2>/dev/null)" ]; then
		latest="$(head -n 1 "$cache")"
	else
		command -v curl >/dev/null 2>&1 || return 0
		# The same lookup as install.sh: the redirect of releases/latest, which the API's rate limit does not cover.
		latest="$(curl -fsSLI --max-time 3 -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest" 2>/dev/null)" || return 0
		case "$latest" in */tag/*) latest="${latest##*/}" ;; *) return 0 ;; esac
		printf '%s\n' "$latest" >"$cache" 2>/dev/null
	fi

	[ -n "$latest" ] && [ "$latest" != "$installed" ] || return 0
	# Newer only: an install of a tag newer than the latest release, such as a prerelease, is left alone.
	[ "$(printf '%s\n%s\n' "$installed" "$latest" | sort -V 2>/dev/null | tail -n 1)" = "$latest" ] || return 0
	printf 'vrl skills %s is out (installed: %s): https://github.com/%s/releases/tag/%s\n' "$latest" "$installed" "$repo" "$latest"
	printf 'Update with: curl -fsSL https://raw.githubusercontent.com/%s/main/install.sh | bash\n' "$repo"
}

main "$@"
exit 0
