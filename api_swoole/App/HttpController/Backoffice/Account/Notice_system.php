<?php
namespace App\HttpController\Backoffice\Account;

use EasySwoole\Http\AbstractInterface\Controller;
use App\Utility\Helper;
use App\Model\Curl;

class Notice_system extends Controller
{
    protected function onRequest($action, $method) :? bool
    {
        //检查请求参数
        return $this->colationPars(
            [
                [
                    Helper::HTTP_GET,
                    [],
                    true
                ],
                [
                    Helper::HTTP_POST,
                    [
                        'content'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ],
                [
                    Helper::HTTP_PUT,
                    [
                        'id'=> [true, 'str', function($f){ return preg_match('/^[0-9]+$/i',$f) ? true : false; }],
                        'content'=> [true, 'str', function($f){ return true; }]
                    ],
                    true
                ]
            ]
        );
    }
    
    public function index()
    {
        $notice = $this->account_model->getNoticeSystem();
        
        return $this->writeJson(200, '获取成功', $notice);
    }
    
    public function index_post()
    {
        if (! ($notice = $this->account_model->postNoticeSystem($this->Pars['content']))) {
            return $this->writeJson(9010, '添加系统公告失败', null, true);
        }
        $data = [
            'content' => $this->Pars['content'],
            'type' => 5
        ];
        $_curl = new Curl();
        $res = $_curl->pushSystemsettingNoticeRolling($data);
        return $this->writeJson(200, '添加系统公告成功', $notice);
    }
    
    public function index_put()
    {
        if (! ($notice = $this->account_model->putNoticeSystem($this->Pars['id'], $this->Pars['content']))) {
            return $this->writeJson(9010, '编辑系统公告失败', null, true);
        }
        
        return $this->writeJson(200, '编辑系统公告成功', $notice);
    }
}