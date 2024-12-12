<?php
namespace App\Utility;

use EasySwoole\Component\Singleton;
use EasySwoole\Trace\TrackerManager;

class Tracker extends TrackerManager
{
    use Singleton;
}