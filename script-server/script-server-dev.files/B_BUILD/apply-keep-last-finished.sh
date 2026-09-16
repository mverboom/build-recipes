#!/usr/bin/env bash
# script-server-dev: keep the most recent finished execution per script in the
# live tabs, so its output stays viewable when you switch away and back.
#
# Browser-session only: this only affects the in-memory Vuex state of the open
# page. After a reload, or from another system/browser, completed runs are still
# only available via the History page.
#
# Frontend (web-src source):
#   store/scriptExecutionManager.js - do not drop a finished executor when
#       switching away; prune terminal executors so at most one (the newest, or
#       the one currently selected) remains per script.
#   components/scripts/script-view.vue - prune right after the current
#       execution finishes, so the previous finished run disappears immediately.
#
# Every replacement is guarded: if the expected pattern is not found (exactly
# once) the build fails with a clear message.
#
# Run from the script-server source root (recipe does: cd script-server).

set -u

fail() {
    echo "apply-keep-last-finished.sh: $*" >&2
    exit 1
}

SEM=web-src/src/main-app/store/scriptExecutionManager.js
SV=web-src/src/main-app/components/scripts/script-view.vue

[ -f "$SEM" ] || fail "$SEM not found"
[ -f "$SV" ] || fail "$SV not found"

python3 - "$SEM" "$SV" <<'PYEOF' || fail 'patching failed'
import sys

sem_path, sv_path = sys.argv[1], sys.argv[2]


def patch(path, old, new, marker):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    if marker in content:
        print(path + ': already patched')
        return

    count = content.count(old)
    if count != 1:
        raise SystemExit('%s: expected exactly one match, found %d' % (path, count))

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.replace(old, new))
    print(path + ': patched')


SEM_OLD = """            const currentExecutor = state.currentExecutor;
            if (!isNull(currentExecutor)) {
                // Don't remove finished executor automatically, if it was cleaned up
                // unless id is null, meaning it was an error
                if (executor && !isNull(executor.state.id) && (executor.state.id === currentExecutor.state.id)) {
                    return;
                }

                if ([STATUS_FINISHED, STATUS_DISCONNECTED, STATUS_ERROR].includes(currentExecutor.state.status)) {
                    dispatch('_removeExecutor', currentExecutor);
                }
            }

            commit('SELECT_EXECUTOR', executor);
            if (executor) {
                dispatch('scriptSetup/reloadModel', {
                    values: clone(executor.state.parameterValues),
                    forceAllowedValues: true,
                    scriptName: executor.state.scriptName
                }, {root: true});
            }
        },
"""

SEM_NEW = """            const currentExecutor = state.currentExecutor;
            if (!isNull(currentExecutor)) {
                if (executor && !isNull(executor.state.id) && (executor.state.id === currentExecutor.state.id)) {
                    return;
                }
            }

            commit('SELECT_EXECUTOR', executor);
            if (executor) {
                dispatch('scriptSetup/reloadModel', {
                    values: clone(executor.state.parameterValues),
                    forceAllowedValues: true,
                    scriptName: executor.state.scriptName
                }, {root: true});
            }

            dispatch('_pruneFinished');
        },

        // Keep at most one terminal (finished/disconnected/error) execution per
        // script, so the last run of a script stays viewable after switching away.
        // The currently selected execution always wins; running executions are
        // never pruned. Browser-session only: after a reload (or on another
        // system) completed runs are only available via History.
        _pruneFinished({state, dispatch}) {
            const terminalStatuses = [STATUS_FINISHED, STATUS_DISCONNECTED, STATUS_ERROR];

            const newestByScript = {};
            const currentExecutor = state.currentExecutor;
            const currentIsTerminal = !isNull(currentExecutor)
                && terminalStatuses.includes(currentExecutor.state.status);

            Object.keys(state.executors).forEach(id => {
                const executor = state.executors[id];
                if (!terminalStatuses.includes(executor.state.status)) {
                    return;
                }
                if (currentIsTerminal && (executor.state.scriptName === currentExecutor.state.scriptName)) {
                    return;
                }

                const newest = newestByScript[executor.state.scriptName];
                if (isNull(newest) || (parseInt(executor.state.id) > parseInt(newest.state.id))) {
                    newestByScript[executor.state.scriptName] = executor;
                }
            });

            if (currentIsTerminal) {
                newestByScript[currentExecutor.state.scriptName] = currentExecutor;
            }

            Object.keys(state.executors).forEach(id => {
                const executor = state.executors[id];
                if (!terminalStatuses.includes(executor.state.status)) {
                    return;
                }
                if (newestByScript[executor.state.scriptName] !== executor) {
                    dispatch('_removeExecutor', executor);
                }
            });
        },
"""

patch(sem_path, SEM_OLD, SEM_NEW, "dispatch('_pruneFinished')")


SV_OLD = """        if (newStatus === STATUS_FINISHED) {
          this.$store.dispatch('executions/' + this.currentExecutor.state.id + '/cleanup');
        }
"""

SV_NEW = """        if (newStatus === STATUS_FINISHED) {
          this.$store.dispatch('executions/' + this.currentExecutor.state.id + '/cleanup');
          this.$store.dispatch('executions/_pruneFinished');
        }
"""

patch(sv_path, SV_OLD, SV_NEW, 'executions/_pruneFinished')
PYEOF

echo 'apply-keep-last-finished.sh: all patches applied'
