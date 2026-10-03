#!/usr/bin/env bash
#
# The verification gate for the platform charts.
#
#   1. STATELESS. No caches. The component charts live in charts/platform/charts/, so
#      there is nothing to fetch and the gate proves what `helm package` will publish.
#   2. FAIL LOUDLY ON A MISSING TOOL. A missing checker is a failure, not a warning.
#   3. FIX WHAT IT FINDS. Suppressing a finding to reach green is how a gate stops
#      meaning anything.
#   4. NECESSARY, NOT SUFFICIENT. `helm template` proves the charts render. It does not
#      prove the cluster accepts them, and it cannot prove the images exist. Installing
#      does both; the release workflow checks the registry.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

CHART="charts/platform"
PASSED=0
FAILED=0
OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT

ok() { PASSED=$((PASSED + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
bad() {
	FAILED=$((FAILED + 1))
	printf '  \033[31mFAIL\033[0m %s\n' "$1"
}
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
check() {
	local name="$1"
	shift
	if "$@" >"$OUT" 2>&1; then ok "$name"; else
		bad "$name"
		sed 's/^/       /' "$OUT"
	fi
}
require() {
	local tool="$1" got="$2" want="$3"
	if ! command -v "$tool" >/dev/null 2>&1; then
		bad "$tool not installed (want $want)"
		return 1
	fi
	case "$got" in
	*"$want"*)
		ok "$tool matched $want"
		return 0
		;;
	*)
		bad "$tool is $got, want $want"
		return 1
		;;
	esac
}

step "tool versions"
require helm "$(helm version --short 2>&1)" "v4"
require shellcheck "$(shellcheck --version 2>&1 | sed -n 's/^version: //p')" "0.11.0"
require gitleaks "$(gitleaks version 2>&1)" "8.30.1"

step "tool installer"
# Every tool the gate REQUIRES must also be installed by scripts/install-tools.sh, or
# CI falls back to whatever the runner image happens to ship. That is how a stale
# ShellCheck shadowed the required version in another repository: green locally, red
# in CI. The gate is the same everywhere, or it is not a gate.
missing=""
while read -r tool; do
	grep -q -- "$tool" scripts/install-tools.sh || missing="$missing $tool"
done < <(sed -n 's/^require \([A-Za-z][A-Za-z0-9_-]*\) .*/\1/p' scripts/verify.sh | sort -u)
if [ -n "$missing" ]; then
	bad "scripts/install-tools.sh does not install:$missing"
else
	ok "scripts/install-tools.sh covers every required tool"
fi

step "scripts"
check "shellcheck (scripts)" shellcheck -s bash scripts/*.sh

step "subcharts"
# A directory under charts/ is loaded by Helm without a `dependencies:` declaration, so
# a missing one is invisible until `helm template` fails on a missing Kubernetes
# object -- or worse, until something is silently absent at install time.
for component in town pestilence scarab; do
	if [ -f "$CHART/charts/$component/Chart.yaml" ]; then
		ok "charts/platform/charts/$component"
	else
		bad "charts/platform/charts/$component is missing -- its objects will not render"
	fi
done

step "dependency declarations"
# Helm reports a mismatch in `dependency list` but does NOT fail lint or template, so
# it is asserted here. A declared version that disagrees with the subchart's own is
# otherwise invisible until something reads the metadata.
wrong=""
while read -r line; do
	[ -n "$line" ] || continue
	case "$line" in
	*unpacked) ;;
	*) wrong="${wrong:+$wrong; }${line}" ;;
	esac
done < <(helm dependency list "$CHART" 2>/dev/null | tail -n +2)
if [ -n "$wrong" ]; then
	bad "dependency declarations are not satisfied:$wrong"
else
	ok "every dependency declaration matches its subchart"
fi

step "chart"
check "helm lint (platform)" helm lint "$CHART"
for component in town pestilence scarab; do
	check "helm lint ($component, standalone)" helm lint "$CHART/charts/$component"
done
check "helm template (platform)" helm template platform "$CHART"

step "pinned images"
# The components version independently, so nothing enforces a shared number. What IS
# enforced is that every image this chart deploys is pinned to a version. A floating
# tag makes a rollback a coin toss and a redeploy unpredictable.
rendered="$(helm template platform "$CHART" 2>/dev/null)"
unpinned=""
while read -r ref; do
	[ -n "$ref" ] || continue
	case "$ref" in
	*:latest | *:) unpinned="$unpinned ${ref}" ;;
	esac
done < <(printf '%s\n' "$rendered" | grep -oE 'ghcr\.io/gobackto-work/[A-Za-z0-9._/-]+(:[A-Za-z0-9._-]*)?' | sort -u)
if [ -n "$unpinned" ]; then
	bad "images are not pinned to a version:$unpinned"
else
	ok "every image is pinned to a version"
fi

step "secrets"
check "gitleaks (tree + git history)" gitleaks detect --source . --no-banner --redact

printf '\n'
if [ "$FAILED" -eq 0 ]; then
	printf '\033[1mverify.sh: %d passed, 0 failed\033[0m\n' "$PASSED"
	printf 'verified: %d checks, 0 failures\n' "$PASSED"
else
	printf '\033[1;31mverify.sh: %d passed, %d failed\033[0m\n' "$PASSED" "$FAILED"
	exit 1
fi
