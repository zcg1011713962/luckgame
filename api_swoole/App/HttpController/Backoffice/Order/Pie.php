<?php
namespace App\HttpController\Backoffice\Order;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
//饼图
class Pie extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                'start_time'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                'end_time'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                'status'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                'user_channel'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }],
                'pay_channel'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
            ],
            true
        );
    }
    
    public function index()
    {
        $data = $this->order_model->getPieData($this->Pars['start_time'], $this->Pars['end_time'], $this->Pars['status'], $this->Pars['pay_channel'], $this->Pars['user_channel']);
        if (!$data) {
            return $this->writeJson(4001, '查询失败', null, true);
        }
        
        return $this->writeJson(200, '查询成功', $data);
    }
}