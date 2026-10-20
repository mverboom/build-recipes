/*
 * Kanboard BoardScrollFix plugin
 *
 * Kanboard renders the board columns inside #board-container, which is the
 * horizontal scroller (assets/css/src/board.css: #board-container
 * { overflow-x: auto }). Two things reset it to the first column on mobile:
 *
 *  1. Kanboard replaces #board-container with fresh markup on every board
 *     refresh (moving a card, board polling, collapsing a column). A new
 *     element starts at scrollLeft 0.
 *  2. Opening a card and going back to the board is a full page load, so the
 *     freshly rendered container starts at scrollLeft 0 as well.
 *
 * Case 1 is fixed by wrapping Kanboard.BoardDragAndDrop.prototype.refresh and
 * restoring the position after the container has been replaced. Case 2 is
 * fixed by remembering the position in sessionStorage (per project) and
 * restoring it when a board page loads. sessionStorage means the position is
 * kept while the tab/app lives and starts at the first column again after a
 * restart.
 */
(function () {
    'use strict';

    if (typeof window === 'undefined' || typeof document === 'undefined') {
        return;
    }

    var STORAGE_PREFIX = 'kanboard-board-scroll:';
    var SAVE_DELAY = 150;
    var RESTORE_TRIES = 20;
    var RESTORE_INTERVAL = 100;

    var restoring = false;
    var restoreTries = 0;
    var saveTimer = null;
    var restoreTimer = null;

    function boardContainer() {
        return document.getElementById('board-container');
    }

    // The board table carries data-project-id (absent on readonly/public boards).
    function storageKey() {
        var board = document.getElementById('board');
        var projectId = board ? board.getAttribute('data-project-id') : null;

        return projectId ? STORAGE_PREFIX + projectId : null;
    }

    function readPosition() {
        var key = storageKey();
        if (!key) {
            return null;
        }

        try {
            var value = window.sessionStorage.getItem(key);
            if (value === null) {
                return null;
            }

            var position = parseInt(value, 10);

            return isNaN(position) || position < 0 ? null : position;
        } catch (e) {
            return null;
        }
    }

    function savePosition() {
        var key = storageKey();
        var container = boardContainer();

        if (!key || !container) {
            return;
        }

        // Nothing to scroll means compact mode (or an empty board): keep the
        // remembered position instead of overwriting it with 0.
        if (container.scrollWidth - container.clientWidth <= 0) {
            return;
        }

        try {
            window.sessionStorage.setItem(key, String(container.scrollLeft));
        } catch (e) {
            // Storage full or disabled: the board still works, we just forget.
        }
    }

    function scheduleSave() {
        if (restoring || saveTimer !== null) {
            return;
        }

        saveTimer = window.setTimeout(function () {
            saveTimer = null;
            savePosition();
        }, SAVE_DELAY);
    }

    function stopRestoring() {
        restoring = false;
        restoreTries = 0;

        if (restoreTimer !== null) {
            window.clearTimeout(restoreTimer);
            restoreTimer = null;
        }
    }

    function applyPosition() {
        restoreTimer = null;

        var container = boardContainer();
        var target = readPosition();

        if (!container || target === null) {
            stopRestoring();
            return;
        }

        if (target > 0) {
            container.scrollLeft = target;
        }

        // Give the browser a few more chances in case the board was not laid
        // out yet (fonts, images, column widths) and the position was clamped.
        if (Math.abs(container.scrollLeft - target) <= 2 || restoreTries >= RESTORE_TRIES) {
            stopRestoring();
            return;
        }

        restoreTries++;
        restoreTimer = window.setTimeout(applyPosition, RESTORE_INTERVAL);
    }

    function init() {
        var container = boardContainer();

        if (!container) {
            return; // Not a board page.
        }

        container.addEventListener('scroll', scheduleSave, { passive: true });

        window.addEventListener('pagehide', function () {
            savePosition();
        });

        document.addEventListener('visibilitychange', function () {
            if (document.visibilityState === 'hidden') {
                savePosition();
            }
        });

        // Do not fight the user if they start scrolling while we are restoring.
        ['touchstart', 'touchmove', 'pointerdown', 'wheel', 'keydown'].forEach(function (event) {
            window.addEventListener(event, stopRestoring, { passive: true });
        });

        restoring = true;
        applyPosition();
    }

    /*
     * Case 1: Kanboard's own in page board refresh replaces the container.
     */
    if (typeof Kanboard !== 'undefined' && Kanboard.BoardDragAndDrop) {
        var originalRefresh = Kanboard.BoardDragAndDrop.prototype.refresh;

        Kanboard.BoardDragAndDrop.prototype.refresh = function (data) {
            var oldContainer = boardContainer();
            var scrollLeft = oldContainer ? oldContainer.scrollLeft : 0;
            var scrollTop = window.pageYOffset || document.documentElement.scrollTop || 0;

            var result = originalRefresh.call(this, data);

            var newContainer = boardContainer();
            if (newContainer) {
                newContainer.scrollLeft = scrollLeft;
            }

            if (scrollTop > 0) {
                window.scrollTo(0, scrollTop);
            }

            savePosition();

            return result;
        };
    }

    /*
     * Case 2: full page load after coming back from a task view.
     */
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
