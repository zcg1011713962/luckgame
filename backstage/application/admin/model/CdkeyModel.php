<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class CdkeyModel extends Model
{
    private $config;

    public function __construct(){
		$this->config = ConfigModel::getSystemConfig();
	}

    public function getConfig($msg = 'app.GameLoginUrl'){
        $configArr = explode('.',$msg);
		// 如果系统有当前配置项，走系统配置项
		if (!empty($this->config[$configArr[1]])) {
			return $this->config[$configArr[1]];
		}
		// 否则走配置文件
		return Config::get($msg);
    }

    public function getAdminInfo($id = 0){
        if(empty($id)){ return false; }
        return Db::table('ym_manage.cdkey')->find($id);
    }

    public function getList($num = 10){
        $where = [];
        $card = isset($_POST['number']) ? $_POST['number'] : '';
        if ($card) {
            $where['number'] = $card;
        }
        $list = Db::table('ym_manage.cdkey')->where($where)->paginate($num);
        $page = $list->render();
        return array(
            'list' => $list,
            'page' => $page
        );
    }

    public function getCount(){
        return Db::table('ym_manage.cdkey')->count();
    }

    public function getUseCount(){
        return Db::table('ym_manage.cdkey')->where('status' , 1)->count();
    }

    public function addAll($datas){
        Db::name('ym_manage.cdkey')->insertAll($datas);
        return true;
    }

    public function doDel($data){
        if(empty($data)){ return false; }
        if(empty($data['id'])){ return false; }

        Db::table('ym_manage.cdkey')->where('id',$data['id'])->delete();
        return true;
    }
}
