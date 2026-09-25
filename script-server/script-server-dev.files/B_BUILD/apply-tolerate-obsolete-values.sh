#!/usr/bin/env bash
# script-server-dev: tolerate obsolete dynamic-multiselect values.
#
# apply-deeplink-prefill.sh forces deep-link prefill values so a dependent
# parameter's value is not wiped before its values list is computed. But the
# combobox still flags any selected value not in the CURRENT allowed list as
# "Obsolete value(s)" and refuses to run, and the backend validate_value raises
# InvalidValueException ("has value ..., but should be in [...]").
#
# That blocks the WordPress "scan -> select -> apply" flow whenever the scan
# cache changed between generating the deep link and submitting the form (e.g.
# an item was already updated and dropped from --list-updates).
#
# Patch:
#   * web-src combobox.vue: do not raise the obsolete error for forced
#     (deep-link) values - they are kept and submitted.
#   * src/model/parameter_config.py: script-backed (dynamic) multiselects
#     tolerate elements that are no longer in the allowed list; static lists
#     keep strict validation.
#
# Consumers ignore entries that no longer apply (wp-update --plan only applies
# pending items; --site filters drop non-matching labels).
#
# Every replacement is guarded: if the expected pattern is not found exactly
# once the build fails with a clear message, so an upstream change is caught at
# build time instead of silently losing the tolerance.
#
# Run from the script-server source root (recipe does: cd script-server).

set -u

fail() {
    echo "apply-tolerate-obsolete-values.sh: $*" >&2
    exit 1
}

VUE=web-src/src/common/components/combobox.vue
PY=src/model/parameter_config.py

[ -f "$VUE" ] || fail "$VUE not found"
[ -f "$PY" ] || fail "$PY not found"

# --- frontend: forced values must not raise the obsolete error --------------
if grep -q 'if (!this.forceValue && !isEmptyArray(wrongValues))' "$VUE"; then
    echo 'apply-tolerate-obsolete-values.sh: frontend already patched'
else
    count=$(grep -c 'if (!isEmptyArray(wrongValues)) {' "$VUE")
    [ "$count" = 1 ] || fail "expected exactly one wrongValues check in $VUE, found $count"
    sed -i 's#if (!isEmptyArray(wrongValues)) {#if (!this.forceValue \&\& !isEmptyArray(wrongValues)) {#' "$VUE"
    grep -q 'if (!this.forceValue && !isEmptyArray(wrongValues))' "$VUE" \
        || fail 'frontend patch failed'
fi

# --- backend: dynamic multiselects tolerate stale elements ------------------
if grep -q 'tolerate stale elements' "$PY"; then
    echo 'apply-tolerate-obsolete-values.sh: backend already patched'
else
    python3 - "$PY" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = """        if self.type == PARAM_TYPE_MULTISELECT:
            if not isinstance(user_value, list):
                return 'should be a list, but was: ' + value_string + '(' + str(type(user_value)) + ')'
            for value_element in user_value:
"""
new = """        if self.type == PARAM_TYPE_MULTISELECT:
            if not isinstance(user_value, list):
                return 'should be a list, but was: ' + value_string + '(' + str(type(user_value)) + ')'
            # tolerate stale elements: a script-backed (dynamic) values list can
            # change between a deep link and submit; the consumer ignores
            # entries that no longer apply. Static lists stay strict.
            if isinstance(self._values_provider, (ScriptValuesProvider, DependantScriptValuesProvider)):
                return None
            for value_element in user_value:
"""
assert s.count(old) == 1, 'backend anchor not found exactly once'
open(p, 'w', encoding='utf-8').write(s.replace(old, new))
PYEOF
    grep -q 'tolerate stale elements' "$PY" || fail 'backend patch failed'
fi

python3 -m py_compile "$PY" || fail 'patched backend does not compile'

echo 'apply-tolerate-obsolete-values.sh: obsolete-value tolerance patched'
