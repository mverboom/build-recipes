#!/usr/bin/env bash
# script-server-dev: prepend a runtime-configured prefix to the browser tab title.
#
# The prefix is read server-side from SCRIPT_SERVER_TITLE_PREFIX (set in
# /etc/default/script-server-dev) and exposed as `titlePrefix` in the server
# config. The frontend prepends it to document.title, so the tab shows e.g.:
#     ss - Network bond - Cdist script server
#
# The recipe builds web/ from web-src of the same git checkout (no prebuilt
# bundle download), so all frontend changes are applied to web-src/src.
#
# Backend (Python source):
#   src/model/server_conf.py    - title_prefix field, read from env
#   src/model/external_model.py - expose it as 'titlePrefix' in server config
# Frontend (web-src source):
#   store/serverConfig.js              - keep titlePrefix from the API
#   components/DocumentTitleManager.vue - prepend it to document.title
#
# Every replacement is guarded: if the expected pattern is not found the build
# fails with a clear message, so an upstream change that breaks this patch is
# caught at build time instead of silently producing a broken tab title.
#
# Run from the script-server source root (recipe does: cd script-server).

set -u

fail() {
    echo "apply-title-prefix.sh: $*" >&2
    exit 1
}

# --- 1. Backend: read SCRIPT_SERVER_TITLE_PREFIX in server_conf.py ----------
if ! grep -q 'self.title_prefix = os.environ.get("SCRIPT_SERVER_TITLE_PREFIX")' src/model/server_conf.py; then
    sed -i 's#        self.enable_script_titles = None#        self.enable_script_titles = None\n        self.title_prefix = os.environ.get("SCRIPT_SERVER_TITLE_PREFIX")#' \
        src/model/server_conf.py \
        && grep -q 'self.title_prefix = os.environ.get("SCRIPT_SERVER_TITLE_PREFIX")' src/model/server_conf.py \
        || fail 'could not patch src/model/server_conf.py (pattern changed upstream?)'
fi

# --- 2. Backend: expose titlePrefix in server_conf_to_external ---------------
if ! grep -q "'titlePrefix': server_config.title_prefix," src/model/external_model.py; then
    sed -i "s#        'enableScriptTitles': server_config.enable_script_titles,#        'titlePrefix': server_config.title_prefix,\n        'enableScriptTitles': server_config.enable_script_titles,#" \
        src/model/external_model.py \
        && grep -q "'titlePrefix': server_config.title_prefix," src/model/external_model.py \
        || fail 'could not patch src/model/external_model.py (pattern changed upstream?)'
fi

# --- 3. Frontend: serverConfig store keeps titlePrefix from the API ----------
SC=web-src/src/main-app/store/serverConfig.js
if ! grep -q 'titlePrefix: null,' "$SC"; then
    sed -i 's#^        enableScriptTitles: null,#        enableScriptTitles: null,\n        titlePrefix: null,#' "$SC" \
        && grep -q 'titlePrefix: null,' "$SC" \
        || fail "could not patch $SC (state pattern changed upstream?)"
fi
if ! grep -q 'state.titlePrefix = config.titlePrefix;' "$SC"; then
    sed -i 's#^            state.serverName = config.title;#            state.serverName = config.title;\n            state.titlePrefix = config.titlePrefix;#' "$SC" \
        && grep -q 'state.titlePrefix = config.titlePrefix;' "$SC" \
        || fail "could not patch $SC (SET_CONFIG pattern changed upstream?)"
fi

# --- 4. Frontend: DocumentTitleManager prepends the prefix --------------------
DT=web-src/src/main-app/components/DocumentTitleManager.vue
if ! grep -q 'titlePrefix: state => state.titlePrefix' "$DT"; then
    sed -i "s#^      enableScriptTitles: state => isNull(state.enableScriptTitles) || state.enableScriptTitles\$#      enableScriptTitles: state => isNull(state.enableScriptTitles) || state.enableScriptTitles,\n      titlePrefix: state => state.titlePrefix || ''#" "$DT" \
        && grep -q 'titlePrefix: state => state.titlePrefix' "$DT" \
        || fail "could not patch $DT (mapState pattern changed upstream?)"
fi
if ! grep -q 'document.title = this.titlePrefix +' "$DT"; then
    sed -i "s#        document.title = this.selectedScript + ' - ' + this.serverName;#        document.title = this.titlePrefix + this.selectedScript + ' - ' + this.serverName;#" "$DT" \
        && sed -i "s#        document.title = this.serverName;#        document.title = this.titlePrefix + this.serverName;#" "$DT" \
        && grep -q 'document.title = this.titlePrefix +' "$DT" \
        || fail "could not patch $DT (updateTitle pattern changed upstream?)"
fi

# --- Sanity checks ------------------------------------------------------------
grep -q 'document.title = this.titlePrefix + this.serverName;' "$DT" \
    || fail 'both updateTitle branches were not patched'
python3 -m py_compile src/model/server_conf.py src/model/external_model.py \
    || fail 'python syntax check failed after patching'
find src -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null

echo 'apply-title-prefix.sh: all patches applied'
