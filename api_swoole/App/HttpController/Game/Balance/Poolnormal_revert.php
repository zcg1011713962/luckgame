<?php
namespace App\HttpController\Game\Balance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use App\Model\Constants\MysqlTables;

class Poolnormal_revert extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'coin'=> [true, 'coin', function($f){ return !empty($f) && is_numeric(Helper::format_money($f)) && Helper::format_money($f) > 0; }],
                'event_id'=> [true, 'abs', function($f){ return !empty($f) && is_numeric($f) && $f > 0; }],
                'game_id'=> [true, 'abs', function($f){ return !empty($f) && is_numeric($f) && $f > 0; }],
                'game_timestamp'=> [true, 'abs', function($f){ return $f > 0; }],
                'game_identification'=> [true, 'abs', function($f){ return true; }]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        //redis还款
        $_cs = $this->rediscli_model->_revert($this->Pars['coin']);
        list($_c_in, $_c_b) = $_cs;
        
        if (! $this->finance_model->_revertPoolNormal($this->Pars['event_id'], $this->Pars['game_id'], $_c_in, $this->Pars['game_timestamp'], $this->Pars['game_identification'])) {
            return $this->writeJson(9030, '系统错误。新增还款记录失败', null, true);
        }
        
        return $this->writeJson(200, ['revert'=> $_c_in]);
    }
}