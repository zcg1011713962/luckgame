<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;

class InviteModel extends Model
{

    public function getList($num = 10){
        $where = [];
        $card = isset($_POST['number']) ? $_POST['number'] : '';
        if ($card) {
            $where['uid'] = $card;
        }
        $list = Db::table('ym_manage.account_invite_sends')->where($where)->paginate($num);
        $page = $list->render();
        return array(
            'list' => $list,
            'page' => $page
        );
    }

    public function getCount(){
        return Db::table('ym_manage.account_invite_sends')->count();
    }

    public function addAll($datas){
        Db::name('ym_manage.account_invite_sends')->insertAll($datas);
        return true;
    }

    public function doDel($data){
        if(empty($data)){ return false; }
        if(empty($data['id'])){ return false; }

        Db::table('ym_manage.account_invite_sends')->where('id',$data['id'])->delete();
        return true;
    }
}
