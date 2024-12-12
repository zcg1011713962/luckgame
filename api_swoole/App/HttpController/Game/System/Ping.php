<?php
namespace App\HttpController\Game\System;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;

class Ping extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        return true;
    }
    
    public function index()
    {
        return $this->response()->write('hello');
    }
}