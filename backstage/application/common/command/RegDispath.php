<?php
namespace app\common\command;

use app\admin\model\UserModel;
use think\console\Command;
use think\console\Input;
use think\console\Output;
use think\Db;

class RegDispath extends Command {
	
	protected function configure()
    {
        $this->setName('reg_dispath')->setDescription('注册推广人员奖励');
    }

    protected function execute(Input $input, Output $output)
    {
        $list = Db::table('ym_manage.account_invite_sends')->where([
            'status' => 0 ,
        ])->select();
        foreach ($list as $val){
            // 更新成处理中
            Db::table('ym_manage.account_invite_sends')->where('id' , $val['id'])->update(['status' => 1]);
            $account = Db::table('gameaccount.newuseraccounts')->where('id' , $val['uid'])->find();
            if ($account){
                // 处理
                $userModel = new UserModel();
                $status = $userModel->insertScore($account['Account'] , $val['number']);
                if ($status){
                    // 处理成功
                    $data = ['status' => 2 , 'updated_at' => date('Y-m-d H:i:s')];
                }else{
                    // 失败
                    $data = ['status' => 3 , 'updated_at' => date('Y-m-d H:i:s')];
                }
                Db::table('ym_manage.account_invite_sends')->where('id' , $val['id'])->update($data);
            }
        }
    }
}


?>