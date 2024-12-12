<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class Players extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'id'=> [false, 'str'],
                'keyword'=> [false, 'str', function($f){ return ! preg_match('/[\'.,:;*?~`!@#$%^&+=)(<>{}]|\]|\[|\/|\\\|\"|\|/',$f) ? true : false; }],
                'orderby'=> [false, 'str'],
                'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index()
    {
        if (! ($players = $this->account_model->getPlayers($this->Pars['keyword'], $this->Pars['orderby'], $this->Pars['page'], $this->Pars['id']))) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, '查询成功', $players);
    }
}