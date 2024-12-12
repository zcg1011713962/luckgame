<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use think\Db;
use app\admin\model\EmailModel;

class EmailManage extends Parents {
    public function lists() {
        $emailModel = new EmailModel;
        $emailList = $emailModel->getEmailList();
        $this->assign('emailList',$emailList);
        return $this->fetch();
    }

    public function addEmail() {
        $params = request()->post();
        EmailModel::addEmail($params);
        return $this->_success('','发送邮件成功!');
    }
}