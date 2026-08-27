#!/usr/bin/env bash
# script-server-dev: prepend a runtime-configured prefix to the browser tab title.
#
# The prefix value is read server-side from the environment variable
# SCRIPT_SERVER_TITLE_PREFIX (set in /etc/default/script-server-dev by the
# package) and sent to the frontend as `titlePrefix` in the server config.
# The frontend DocumentTitleManager (compiled bundle) is patched to prepend it
# to document.title, so the tab shows e.g.:
#     ss - Network bond - Cdist script server
#
# Backend changes (Python source, applied to the git checkout):
#   src/model/server_conf.py    - title_prefix field, read from env
#   src/model/external_model.py - expose it as 'titlePrefix' in server config
# Frontend changes (compiled bundle from the dev web zip):
#   web/js/*.js - SET_CONFIG stores titlePrefix, DocumentTitleManager prepends it
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
if ! grep -q 'e.titlePrefix=t.titlePrefix' web/js/*.js; then
    sed -i 's#SET_CONFIG:function(e,t){e.serverName=t.title,e.version=t.version,e.enableScriptTitles=t.enableScriptTitles#&,e.titlePrefix=t.titlePrefix#' \
        web/js/*.js \
        && grep -q 'e.titlePrefix=t.titlePrefix' web/js/*.js \
        || fail 'could not patch web bundle (serverConfig SET_CONFIG pattern changed upstream?)'
fi

# --- 4. Frontend: DocumentTitleManager prepends the prefix --------------------
if ! grep -q 'this.$store.state.serverConfig.titlePrefix' web/js/*.js; then
    sed -i 's#document.title=this.selectedScript+" - "+this.serverName:document.title=this.serverName#document.title=(this.$store.state.serverConfig.titlePrefix||"")+this.selectedScript+" - "+this.serverName:document.title=(this.$store.state.serverConfig.titlePrefix||"")+this.serverName#g' \
        web/js/*.js \
        && grep -q 'this.$store.state.serverConfig.titlePrefix' web/js/*.js \
        || fail 'could not patch web bundle (DocumentTitleManager pattern changed upstream?)'
fi

# --- Sanity checks ------------------------------------------------------------
python3 -m py_compile src/model/server_conf.py src/model/external_model.py \
    || fail 'python syntax check failed after patching'
find src -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null

echo 'apply-title-prefix.sh: all patches applied'
