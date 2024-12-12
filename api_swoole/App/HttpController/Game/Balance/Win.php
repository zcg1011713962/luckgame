<?php
namespace App\HttpController\Game\Balance;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Logger;

class Win extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'account_id'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0; }],
                'coin'=> [true, 'coin', function($f){ return !empty($f) && is_numeric(Helper::format_money($f)) && Helper::format_money($f) >= 0; }],
                'game_id'=> [true, 'abs', function($f){ return $f > 0; }],
                'isjp'=> [true, 'abs', function($f){ return in_array($f, [0,1]); }],
                'game_timestamp'=> [true, 'abs', function($f){ return $f > 0; }],
                'game_identification'=> [true, 'abs', function($f){ return true; }]
            ],
            false
        );
    }
    
    public function index() {}
    

    public function index_post()
    {
        $balance = [];
        //获取系统参数
        if (! ($_system_setting = $this->system_model->_getRedisSystemParameters(
                [
                    'pool_jp_outline',/* JP池子 开奖水位设定 */
                    'pool_jp_outlimup',/* JP池子 单次开奖上限 */
                    'pool_jp_outlimdown'/* JP池子 单次开奖下限 */
                ]
            ))
        ) {
            return $this->writeJson(9021, '系统错误。系统参数未初始化', null, true);
        }
        //结算金额
        $balance['coin'] = Helper::format_money($this->Pars['coin']);
        //判断玩家是否可以中JP奖
        $can_get_jp = ! $this->Pars['isjp'] ? false : $this->account_model->getPlayerCanGetJP($this->Pars['account_id'], $this->Pars['game_timestamp']);

        if(!$this->finance_model->canApplyLoanStrategy($this->Pars['account_id'], $balance['coin'], $this->Pars['game_id'])) {
            return $this->writeJson(9023, '结算失败。个人最大赢分余额不足', null, true);
        }

        //池子操作并返回结果
        list($balance['poolnormal'], $balance['pooljp'], $pool_normal_balance_last, $pool_jp_balance_last) = $this->rediscli_model->_transfer($balance['coin'], $_system_setting, $can_get_jp);
        //结算失败，普通池余额不足，无法派奖
        if ($balance['poolnormal'] == 0) {
            return $this->writeJson(9023, '结算失败。池子(normal)余额不足', null, true);
        }
        //创建流水
        //增加池子记录
        $_pool = $balance;
        $_pool['account_id'] = $this->Pars['account_id'];
        $_pool['game_id'] = $this->Pars['game_id'];
        $_pool['game_timestamp'] = $this->Pars['game_timestamp'];
        $_pool['game_identification'] = $this->Pars['game_identification'];
        if (! ($_pool_eventid = $this->finance_model->_entryPool($_pool))) {
            return $this->writeJson(9030, '系统错误。记录流水失败', null, true);
        }
        //结算事件ID
        $balance['event_id'] = $_pool_eventid;
        //结算成功
        $balance['state'] = 1;
        //日志
        Logger::getInstance()->log(PHP_EOL . json_encode($balance, JSON_UNESCAPED_UNICODE) . PHP_EOL . json_encode($this->Pars, JSON_UNESCAPED_UNICODE), 'pool-win-log');
        
        return $this->writeJson(200, $balance);
    }
}