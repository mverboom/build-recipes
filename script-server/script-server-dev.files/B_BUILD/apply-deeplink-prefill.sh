#!/usr/bin/env bash
# script-server-dev: make deep-link URL parameter prefill survive the
# dependent-values wipe race.
#
# Deep links like index.html#/<script>?Hosts=h1,h2&Containers=h1:c1 are
# prefilled by the frontend: store/index.js watches scripts.predefinedParameters
# and calls scriptSetup/reloadModel with forceAllowedValues: false.
#
# With false, the combobox component "fixes" each predefined value against the
# parameter's CURRENT allowed values as soon as it mounts. For parameters whose
# allowed values depend on other parameters (e.g. multiselect Containers
# depends on multiselect Hosts), the first render happens before the dependent
# values list has been computed, so the predefined value is silently wiped to
# [] and sent to the server - the prefill is lost. (For independent parameters
# like Hosts the allowed list is already complete at first render, so they
# survive; that is why only the dependent parameter appears broken.)
#
# Patch: forceAllowedValues false -> true in the web-src source (instead of the
# compiled bundle, now that the recipe builds web/ from web-src). Forced values
# are never wiped; values that are not (yet) in the allowed list are rendered as
# disabled options with an "Obsolete values" hint until the reloaded model
# provides the full list, instead of being dropped.
#
# Every replacement is guarded: if the expected pattern is not found (exactly
# once) the build fails with a clear message, so an upstream change that breaks
# this patch is caught at build time instead of silently keeping the race.
#
# Run from the script-server source root (recipe does: cd script-server).

set -u

fail() {
    echo "apply-deeplink-prefill.sh: $*" >&2
    exit 1
}

IDX=web-src/src/main-app/store/index.js

[ -f "$IDX" ] || fail "$IDX not found"

false_count=$(grep -c 'forceAllowedValues: false,' "$IDX")
true_count=$(grep -c 'forceAllowedValues: true,' "$IDX")

if [ "$false_count" = 0 ]; then
    if [ "$true_count" -ge 1 ]; then
        echo 'apply-deeplink-prefill.sh: already patched'
        exit 0
    fi
    fail "no forceAllowedValues: false found in $IDX (upstream changed the prefill code?)"
fi

[ "$false_count" = 1 ] \
    || fail "expected exactly one forceAllowedValues: false in $IDX, found $false_count"

sed -i 's#forceAllowedValues: false,#forceAllowedValues: true,#' "$IDX"

grep -q 'forceAllowedValues: true,' "$IDX" \
    || fail 'patching forceAllowedValues failed'
[ "$(grep -c 'forceAllowedValues: false,' "$IDX")" = 0 ] \
    || fail 'forceAllowedValues: false still present after patching'

# Sanity: the patched call site is the predefinedParameters deep-link watcher.
grep -q 'predefinedParameters' "$IDX" \
    || fail 'predefinedParameters watcher not found - wrong file patched?'

echo 'apply-deeplink-prefill.sh: forceAllowedValues patched in web-src source'
