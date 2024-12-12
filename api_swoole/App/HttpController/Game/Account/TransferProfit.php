<?php
namespace App\HttpController\Game\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

/**
 * BB推广员收益，通过支付密码提现到账户余额
 *
 */
class TransferProfit extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //$this->outLog = true;
        
        //检查请求参数
        return $this->colationPars(
            [
                'pwdmd5'=> [true, 'str', function($f){ return preg_match('/^[a-z0-9]{32}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index() {}
    
    public function index_post()
    {
        if (! ($coin = $this->account_model->postPlayerTransferProfit($this->Pars['pwdmd5']))) {
            return $this->writeJson(9010, '提现失败', null, true);
        }
        
        return $this->writeJson(200, '提现成功', $coin);
    }
}