<?php
namespace App\HttpController\Game\Balance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Bigbang extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account_id'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0; }],
                'logtoken'=> [true, 'str', function($f){ return !empty($f); }],
                'game_timestamp'=> [true, 'abs', function($f){ return $f > 0; }],
                'game_identification'=> [true, 'abs', function($f){ return true; }]
            ],
            false
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! $this->finance_model->putBigbang($this->Pars['logtoken'], $this->Pars['account_id'], $this->Pars['game_timestamp'], $this->Pars['game_identification'])) {
            return $this->writeJson(9030, '开奖失败', null, true);
        }
        
        return $this->writeJson(200);
    }
}