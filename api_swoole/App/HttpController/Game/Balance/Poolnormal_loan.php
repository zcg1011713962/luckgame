<?php
namespace App\HttpController\Game\Balance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use App\Model\Constants\MysqlTables;

class Poolnormal_loan extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account_id'=> [true, 'abs', function($f){ return is_numeric($f) && $f >= 0; }],
                'coin'=> [true, 'coin', function($f){ return !empty($f) && is_numeric(Helper::format_money($f)) && Helper::format_money($f) > 0; }],
                'game_id'=> [true, 'abs', function($f){ return !empty($f) && is_numeric($f) && $f > 0; }],
                'game_timestamp'=> [true, 'abs', function($f){ return $f > 0; }],
                'game_identification'=> [true, 'abs', function($f){ return true; }]
            ]
        );
    }
    
    public function index() {}
    
    public function index_post()
    {

        if(!$this->finance_model->canApplyLoanStrategy($this->Pars['account_id'], $this->Pars['coin'], $this->Pars['game_id'])) {
            return $this->writeJson(9030, '借款失败。个人最大赢分余额不足', null, true);
        }

        if (($_cs = $this->rediscli_model->_loan($this->Pars['coin'])) === false) {
            return $this->writeJson(9030, '系统错误', null, true);
        }
        
        list($_c_out, $_c_b) = $_cs;
        
        if (! $_c_out && ! $_c_b) {
            return $this->writeJson(9023, '借款失败。池子余额不足', null, true);
        }
        
        if (! ($eventid = $this->finance_model->_loanPoolNormal($this->Pars['game_id'], $_c_out, $this->Pars['game_timestamp'], $this->Pars['game_identification']))) {
            $this->rediscli_model->_revert($this->Pars['coin']); //借款记录失败，还款到彩池
            return $this->writeJson(9030, '系统错误。新增借款记录失败', null, true);
        }
        
        return $this->writeJson(200, ['event_id'=> $eventid, 'loan'=> $_c_out, 'balance'=> $_c_b]);
    }
}