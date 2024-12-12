<?php
require '../../vendor/autoload.php';
define('EASYSWOOLE_ROOT','../../');
\EasySwoole\EasySwoole\Core::getInstance()->initialize();

use EasySwoole\Actor\DeveloperTool;

go(function (){
    $tool = new DeveloperTool(\App\Actor\RoomActor::class,'001000001',[
        'startArg'=>'startArg....'
    ]);
    $tool->onReply(function ($data){
        var_dump('reply :'.$data);
    });
    swoole_event_add(STDIN,function ()use($tool){
        $ret = trim(fgets(STDIN));
        if(!empty($ret)){
            go(function ()use($tool,$ret){
                $tool->push(trim($ret));
            });
        }
    });
    $tool->run();
});