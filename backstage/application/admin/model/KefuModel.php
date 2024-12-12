<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use app\admin\model\ConfigModel;

class KefuModel extends Model
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
		$kefu = Db::table('ym_manage.kefu_list')->find($id);
		$kefu['avatar_url'] = $this->config['SystemUrl'].$kefu['avatar'];
		return $kefu;
	}
	
	public function getList($num = 10, $kefu_type = 0){
		$list = Db::table('ym_manage.kefu_list')->where('customer_type', $kefu_type)->paginate($num);
		$page = $list->render();

		if ($kefu_type == 1) {
			// 追加URL前缀
			$list = $list->toArray();
			foreach ($list['data'] as $k => $v) {
				$list['data'][$k]['avatar_url'] = $this->config['SystemUrl'].$v['avatar'];
			}
		}
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	public function getCount($kefu_type = 0){
		return Db::table('ym_manage.kefu_list')->where('customer_type', $kefu_type)->count();
	}
	
	public function doAdd($data){
		if(empty($data)){ return false; }
		if(empty($data['username'])){ return false; }
		if(empty($data['uid'])){ return false; }
		if(empty($data['pass']) ){ return false; }
		
		$arr = array(
			'name' => $data['uid'],
			'account' => $data['username'],
			'password' => $data['pass'],
			'isclose' => $data['isagent']
		);
		$aid = Db::table('ym_manage.kefu_list')->insertGetId($arr);
                $this->query("set autocommit=1");
                return true;
	}

	public function dowAdd($params, $imageUrl){
		
		$arr = array(
			'name' => $params['username'],
			'customer_type' => 1,
			'avatar' => $imageUrl,
			'isclose' => $params['isagent'],
			'customer_url' => $params['customer_url']
		);		
		$aid = Db::table('ym_manage.kefu_list')->insertGetId($arr);		
                $this->query("set autocommit=1");
		return true;
	}

	public function dowEdit($params, $imageUrl) {
		$arr = array(
			'name' => $params['username'],
			'customer_type' => 1,
			'isclose' => $params['isagent'],
			'customer_url' => $params['customer_url']
		);
		if (!empty($imageUrl)) {
			$arr['avatar'] = $imageUrl;
		}
		$aid = Db::table('ym_manage.kefu_list')->where('id',$params['adminid'])->update($arr);		
                $this->query("set autocommit=1");
		return true;
	}
	
	public function doEdit($data){
		if(empty($data)){ return false; }
		if(empty($data['username']) || empty($data['adminid'])){ return false; }
		if(empty($data['pass']) ){ return false; }
		
				
		$arr = array(
			'name' => $data['uid'],
			'account' => $data['username'],
			'password' => $data['pass'],
			'isclose' => $data['isagent']
		);
		$ret=Db::table('ym_manage.kefu_list')->where('id',$data['adminid'])->update($arr);
                $this->query("set autocommit=1");
                return $ret;
	}
	
	public function doDel($data){
		if(empty($data)){ return false; }
		if(empty($data['id'])){ return false; }
		
		Db::table('ym_manage.kefu_list')->where('id',$data['id'])->delete();
                $this->query("set autocommit=1");
		return true;
	}

	public function setUserScore($data,$type){
		if(empty($type) || !in_array($type,['1','2']) ){ return false; }
		if(empty($data)){ return false; }
		if(empty($data['account']) || empty($data['uid']) ){ return false; }
		if( empty($data['addscore']) ){ return false; }
		$addscore = $data['addscore'];
		
		$user = Db::table('ym_manage.kefu_list')
					->where('id',$data['uid'])
					->find();
					
		if($user){
			
			if($type == '1'){
				$score = $user['score'] + $addscore;
				$logtype = 1;
			}elseif($type == '2'){
				$score = $user['score'] - $addscore;
				$logtype = 0;
				if($score<0){
					return false;
				}
			}else{
				return false;
			}
			
			$res = Db::name('ym_manage.kefu_list')
						->where('id', $user['id'])
						->data(['score' => $score])
						->update();
			if($res){				
				$this->addRechargeLog($user['id'],$addscore,$user['score'],$score,$logtype);
                                $this->query("set autocommit=1");
				return true;
			}else{
				return false;
			}
		}
		
		return false;
	}
			
	private function addRechargeLog($uid,$czfee,$oldfee,$newfee,$logtype){
		$adminid = Cookie::get('admin_user_id');
		$log = array(
			'adminid' => $adminid,
			'kefuid' => $uid,
			'createtime' => time(),
			'czfee' => $czfee,
			'oldfee' => $oldfee,
			'newfee' => $newfee,
			'type' => $logtype//1 加 0 减
		);
		Db::name('ym_manage.rechargelog_kefu')->insert($log);
                $this->query("set autocommit=1");
	}
	
}
