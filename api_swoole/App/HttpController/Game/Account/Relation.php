<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * BB推广员系统：获取玩家账号的推广关联
 * 转账时检查玩家是否是上下级关系，只能是1级上下级关系间转账
 */
class Relation extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
        [
            [
                Helper::HTTP_GET,
                [
                    'account'=> [false, 'str', function($f){ return !empty(Helper::account_format_login($f)); }]
                ],
                true
            ],
            [
                Helper::HTTP_POST,
                [
                    'account_id'=> [true, 'str', function($f){ return true; }],
                    'relation'=> [true, 'str', function($f){ return in_array($f, ['parent', 'children']); }]
                ],
                true
            ]
        ]);
    }
    
    public function index()
    {
        $result = $this->account_model->getPlayerRelation($this->Pars['account'] ?? '');
        
        return $this->writeJson(200, $result);
    }
    
    public function index_post()
    {
        if (! $this->account_model->checkPlayerRelation($this->Pars['account_id'], $this->Pars['relation'])) {
            return $this->writeJson(9010, '错误', null, true);
        }
        
        return $this->writeJson(200, '正确');
    }
}