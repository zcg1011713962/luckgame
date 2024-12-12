<?php
namespace app\api\model;
use app\admin\model\ConfigModel;

use think\Db;

class KefuModel 
{
   public function getLists(){
	   return Db::table('ym_manage.kefu_list')->field('id,name')->where('isclose',0)->select();
   }
   public function getwLists(){
      $config = ConfigModel::getSystemConfig();
	   $kefu = Db::table('ym_manage.kefu_list')->field('id,name,avatar,customer_url')->where('isclose',0)->where('customer_type',1)->select();
      foreach ($kefu as $k => $v) {
         $kefu[$k]['avatar_url'] = $config['SystemUrl'].$v['avatar'];
      }
      return $kefu;
   }
}