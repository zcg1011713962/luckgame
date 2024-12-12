<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Vchild_detail extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'username'=> [true, 'str', function($f){ return preg_match('/^[a-zA-Z0-9]{5,30}$/i',$f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($vchild = $this->account_model->getVchild($this->Pars['username']))) {
            return $this->writeJson(1002, '查询失败', null, true);
        }
        
        return $this->writeJson(200, '查询成功', $vchild);
    }
}