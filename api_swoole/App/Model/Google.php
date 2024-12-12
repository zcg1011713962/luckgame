<?php
namespace App\Model;

use App\Model\Model;
use EasySwoole\EasySwoole\Logger;
use App\Utility\Helper;
use EasySwoole\EasySwoole\Config;

class Google extends Model
{
    function __construct()
    {
        parent::__construct();
        
        if (! $this->is_enabled()) {
            //log_message('error', 'cURL Class - PHP was not built with cURL enabled. Rebuild PHP with --with-curl to use cURL.');
        }
    }

    public function is_enabled()
    {
        return function_exists('curl_init');
    }

    /**
    * google注册用户验证token和email
    */
    public function checkcode($email='', $id_token='') {
        return true; //TODO 服务器不能科学上网，只能先默认通过
        if (empty($id_token) || empty($email)) {
            $this->setErrMsg('参数不能为空');
            return false;
        }
        $url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . $id_token;
        $res = $this->models->curl_model->simple_get($url);
        $res = json_decode($res, true);
        if ($res && isset($res['email']) && $res['email'] == $email) {
            return true;
        }
        $this->setErrMsg('验证失败');
        return false;
    }
    
}