<?php
require_once "./vendor/autoload.php";

go(function() {
    \EasySwoole\EasySwoole\Core::getInstance()->initialize();
    require_once "./vendor/bin/phpunit";
});