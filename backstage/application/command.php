<?php
// +----------------------------------------------------------------------
// | ThinkPHP [ WE CAN DO IT JUST THINK ]
// +----------------------------------------------------------------------
// | Copyright (c) 2006-2016 http://thinkphp.cn All rights reserved.
// +----------------------------------------------------------------------
// | Licensed ( http://www.apache.org/licenses/LICENSE-2.0 )
// +----------------------------------------------------------------------
// | Author: yunwuxin <448901948@qq.com>
// +----------------------------------------------------------------------

return [
		
	// 指令名 =》完整的类名
    'hello'	=>	'app\common\command\Hello',
    'chat'	=>	'app\common\command\Chat',
    'onlinenum'	=>	'app\common\command\Onlinenum',
    'robotsql'	=>	'app\common\command\Robotsql',
    'reg_dispath'	=>	'app\common\command\RegDispath',
    "aws_upload"   => 'app\common\command\AwsUploadFile',
];
