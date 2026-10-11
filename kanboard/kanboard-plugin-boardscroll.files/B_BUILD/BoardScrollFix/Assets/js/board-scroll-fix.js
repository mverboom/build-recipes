/*
 * Kanboard BoardScrollFix plugin
 *
 * Kanboard replaces #board-container with fresh markup every time the board is
 * refreshed (moving a card, board polling, collapsing a column). A new element
 * starts at scrollLeft 0, which makes the board jump back to the first column on
 * mobile after a drag and drop.
 *
 * Wrap Kanboard.BoardDragAndDrop.prototype.refresh to remember the horizontal
 * board scroll position and the window vertical position, and restore them after
 * the container has been replaced.
 */
(function () {
    'use strict';

    if (typeof Kanboard === 'undefined' || !Kanboard.BoardDragAndDrop) {
        return;
    }

    var originalRefresh = Kanboard.BoardDragAndDrop.prototype.refresh;

    Kanboard.BoardDragAndDrop.prototype.refresh = function (data) {
        var oldContainer = document.getElementById('board-container');
        var scrollLeft = oldContainer ? oldContainer.scrollLeft : 0;
        var scrollTop = window.pageYOffset || document.documentElement.scrollTop || 0;

        var result = originalRefresh.call(this, data);

        var newContainer = document.getElementById('board-container');
        if (newContainer) {
            newContainer.scrollLeft = scrollLeft;
        }

        if (scrollTop > 0) {
            window.scrollTo(0, scrollTop);
        }

        return result;
    };
})();
