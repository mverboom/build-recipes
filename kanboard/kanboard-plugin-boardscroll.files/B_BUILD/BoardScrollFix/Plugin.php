<?php

namespace Kanboard\Plugin\BoardScrollFix;

use Kanboard\Core\Plugin\Base;

class Plugin extends Base
{
    public function initialize()
    {
        $this->hook->on('template:layout:js', array(
            'template' => 'plugins/BoardScrollFix/Assets/js/board-scroll-fix.js',
        ));
    }

    public function getPluginName()
    {
        return 'BoardScrollFix';
    }

    public function getPluginDescription()
    {
        return t('Keep the board scroll position when the board is refreshed');
    }

    public function getPluginAuthor()
    {
        return 'Mark Verboom';
    }

    public function getPluginVersion()
    {
        return '1.0.0';
    }

    public function getPluginHomepage()
    {
        return 'https://github.com/mverboom/build-recipes';
    }
}
