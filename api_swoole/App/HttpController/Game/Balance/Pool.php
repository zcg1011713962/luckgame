<?php
namespace App\HttpController\Game\Balance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Pool extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        return true;
    }
    
    public function index()
    {
        list($_balance_poolnormal/* 普通池余额 */, $_balance_pooljp/* JP池余额 */) = $this->rediscli_model->getDb()->mGet(
            [
                RedisKey::SYSTEM_BALANCE_POOLNORMAL,
                RedisKey::SYSTEM_BALANCE_POOLJP
            ]);
        
        return $this->writeJson(200, ['normal'=> Helper::format_money($_balance_poolnormal), 'jp'=> Helper::format_money($_balance_pooljp)]);
    }
}