#!/usr/bin/env php
<?php
namespace think;
define('APP_PATH', __DIR__ . '/application/');
define('BIND_MODULE','api/Socket');
// 加载框架引导文件
require __DIR__ . '/thinkphp/base.php';
Container::get('app')->path(APP_PATH)->run()->send();