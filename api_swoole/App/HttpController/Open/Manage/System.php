<?php

namespace App\HttpController\Open\Manage;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;

class System extends Controller
{
    public function index()
    {
        // TODO: Implement index() method.
    }
    
    public function backofficeHistory()
    {
        $auth = $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [
                        'start_time'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0 && $f == strtotime(date("Y-m-d H:i:s", $f)); }],
                        'end_time'=> [true, 'abs', function($f){ return is_numeric($f) && $f > 0 && $f == strtotime(date("Y-m-d H:i:s", $f)); }],
                        'page'=> [true, 'abs', function($f){ return preg_match('/^[0-9]{1,10000}$/i', $f) ? true : false; }]
                    ],
                    true
                ]
            ]);
        
        if ($auth) {
            if (! ($data = $this->system_model->getAgentApiLogs($this->Pars))) {
                return $this->writeJson(3003, '查询失败。', null, true);
            }
            
            return $this->writeJson(200, $data);
        }
    }
    
}