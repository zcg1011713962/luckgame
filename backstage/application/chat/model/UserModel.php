<?php
namespace app\chat\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;
use think\facade\Log;
use app\admin\model\ConfigModel;

class UserModel extends Model
{	
	private $key = '';
	private $apiurl = '';
	private $config;
	
	public function __construct(){
		parent::__construct();
		$this->config = ConfigModel::getSystemConfig();
		$this->apiurl = $this->config['GameServiceApi'];
		$this->key = $this->config['PrivateKey'];
		// $this->apiurl = Config::get('app.gameServer');
	}
	private function _request($url, $https=false, $method='get', $data=null)
	{
		$ch = curl_init();
		curl_setopt($ch,CURLOPT_URL,$url); //设置URL
		curl_setopt($ch,CURLOPT_HEADER,false); //不返回网页URL的头信息
		curl_setopt($ch,CURLOPT_RETURNTRANSFER,true);//不直接输出返回一个字符串
		if($https){
			curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);//服务器端的证书不验证
			curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);//客户端证书不验证
		}
		if($method == 'post'){
			curl_setopt($ch, CURLOPT_POST, true); //设置为POST提交方式
			curl_setopt($ch, CURLOPT_POSTFIELDS, $data);//设置提交数据$data
		}
		$str = curl_exec($ch);//执行访问
		curl_close($ch);//关闭curl释放资源
		return $str;
	}
	
	public function getAgId(){
		return Cookie::get('chat_user_id');
	}
	public function getConfig($msg = ''){
		if(empty($msg)){ return false; }
		return Config::get($msg);
	}
	public function myinfo(){
		$kfid = $this->getAgId();
		if(empty($kfid)){
			return false;
		}
		$info = Db::table('ym_manage.kefu_list')->where('id',$kfid)->find();
		return $info;
	}
	
	public function getUserList(){
		$kfid = $this->getAgId();
		if(empty($kfid)){
			return false;
		}
		
		$list = Db::table('ym_manage.kefu_msg')->field('kfid,uid')->where('kfid',$kfid)->group('kfid,uid')->select();
		return $list;
	}
	
	public function getMsgList($uid){
		$kfid = $this->getAgId();
		if(empty($kfid)){
			return false;
		}
		$ids = Db::table('ym_manage.kefu_msg')->field('id')->where('kfid',$kfid)->where('uid',$uid)->order('createtime desc')->limit(0,10)->select();
		
		$idstr = '';
		foreach($ids as $row){
			$idstr .= $row['id'].',';
		}
		$idstr = rtrim($idstr,',');
		$list = Db::table('ym_manage.kefu_msg')->where('id','in',$idstr)->order('createtime asc')->select();
		return $list;
	}
	
	public function sendMsg($uid,$msg){
		$kfid = $this->getAgId();
		if(empty($kfid)){
			return false;
		}

		if($msg == 'NXP_CONFIG_DEFAULT_RETURNMSG'){
			$msg = Db::table('ym_manage.config')->where('flag','KEFU_RETURNMSG')->value('value');
		}
		
		$kfname = Db::table('ym_manage.kefu_list')->where('id',$kfid)->value('name');
		$data = array(
			'kfid' => $kfid,
			'uid' => $uid,
			'msg' => $msg,
			'createtime' => time(),
			'type' => 2,
			'uname' => '',
			'kfname' => $kfname
		);
		$list = Db::table('ym_manage.kefu_msg')->insert($data);
		if($list){
			$this->sendMsgRedis($uid,$kfid,1,$msg);
			return true;
		}
		return false;
	}
	
	//发布
	//'type' => '2',//1默认聊天 2回复
	private function sendMsgRedis($uid,$kfid,$type,$msg){

		$Redis_ip = $this->getConfig('app.Redis_ip');
		$Redis_port = $this->getConfig('app.Redis_port');
		$Redis_auth = $this->getConfig('app.Redis_auth');

		$redis = new \Redis();
		$redis->connect($Redis_ip, $Redis_port);
		$redis->auth($Redis_auth); 
		$strChannel = 'GMsendMsgToUser';
		
		$arr = array(
			'user_id' => $uid,
			'gm_id' => $kfid,
			'type' => $type,
			'msg' => $msg
		);		
		$rs = $redis->publish($strChannel, json_encode($arr));
		$redis->close();
	}

	public function closeLeft($uid){
		$kfid = $this->getAgId();
		if(empty($kfid)){
			return false;
		}
		
		Db::table('ym_manage.kefu_msg')->where('uid',$uid)->where('kfid',$kfid)->delete();
		echo 'success';
	}
	
	public function getUserCount($search = ''){
		if(!empty($search)){
			return Db::table('gameaccount.newuseraccounts')
						->where('Id|Account','eq',$search)
						->count();
		}else{
			return Db::table('gameaccount.newuseraccounts')->count();
		}
	}
	
	public function getUserInfo($id){
		if(empty($id)){ return false; }		
		return Db::table('gameaccount.newuseraccounts')->alias('u')
					->join('gameaccount.userinfo_imp i','u.Id=i.userId')
					->find($id);
	}
	
	public function getUserInfoByAccount($account){
		if(empty($account)){ return false; }		
		return Db::table('gameaccount.newuseraccounts')->alias('u')
					->join('gameaccount.userinfo_imp i','u.Id=i.userId')
					->where('u.Account',$account)
					->find();
	}
	
	
	
	public function setUserScore($data,$type){
		if(empty($type) || !in_array($type,['1','2']) ){ return false; }
		if(empty($data)){ return false; }
		if(empty($data['username']) || empty($data['uid']) ){ return false; }
		if(empty($data['score']) || empty($data['addscore']) ){ return false; }
		$addscore = round($data['addscore'], 0);
		$account = trim($data['username']);
		
		if($type == '2'){
			$addscore = 0 - $addscore;
		}
		
		return $this->insertScore($account,$addscore);
		
		die;
		//下面代码废弃
		$user = Db::table('gameaccount.newuseraccounts')
					->where('Id',$data['uid'])
					->where('Account',$data['username'])
					->find();
					
		if($user){
			if($user['score'] != $data['score']){
				return false;
			}
			if($type == '1'){
				$score = $user['score'] + $addscore;
				$logtype = 1;
				$totalRecharge = $user['totalRecharge'] + $addscore;
			}elseif($type == '2'){
				$score = $user['score'] - $addscore;
				$logtype = 0;
				$totalRecharge = $user['totalRecharge'];
			}else{
				return false;
			}
			
			$res = Db::name('gameaccount.newuseraccounts')
						->where('Id', $user['Id'])
						->data(['score' => $score, 'totalRecharge' => $totalRecharge])
						->update();
			if($res){				
				$this->addRechargeLog($user['Id'],$addscore,$user['score'],$score,$logtype);
				return true;
			}else{
				return false;
			}
		}
		
		return false;
	}
			
	private function addRechargeLog($uid,$czfee,$oldfee,$newfee,$logtype){
		$kefuid = $this->getAgId();
		$log = array(
			'kefuid' => $kefuid,
			'uid' => $uid,
			'createtime' => time(),
			'czfee' => $czfee,
			'oldfee' => $oldfee,
			'newfee' => $newfee,
			'type' => $logtype//1 加 0 减
		);
		Db::name('ym_manage.rechargelog_kefu_zy')->insert($log);
	}
	public function delSelfScore($czfee){
		$kefuid = $this->getAgId();
		$kefu = $this->myinfo();
		$newfee = $kefu['score'] - $czfee;
		$rs = Db::name('ym_manage.kefu_list')->where('id',$kefuid)->data(['score'=>$newfee])->update();
		//Log::write($rs,'delSelfScore_delscore');
		$log = array(
			'adminid' => 0,
			'kefuid' => $kefuid,
			'createtime' => time(),
			'czfee' => $czfee,
			'oldfee' => $kefu['score'],
			'newfee' => $newfee,
			'type' => 0//1 加 0 减
		);
		$rs = Db::name('ym_manage.rechargelog_kefu')->insert($log);
		//Log::write($rs,'delSelfScore_delscorelog');
	}

	public function insertScore($account,$fee){
		//Log::record('In','insertScore');
		if(empty($account) || empty($fee)){ return false; }
		$account = trim($account);
		$fee = round(floatval($fee),2) * 100;
		
		$user = $this->getUserInfoByAccount($account);
		if($user){

			//扣除客服自己的金币数值
			$this->delSelfScore(abs($fee));
			
			$act = "scoreedit";			
			$time = strtotime('now');
			$key = $this->key;
			$sign = $act.$account.$fee.$time.$key;
			$md5sign = md5($sign);
			$url=$this->apiurl."/Activity/gameuse?act=".$act."&accountname=".$account."&goldnum=".$fee."&time=".$time."&sign=".$md5sign;
			$res = $this->_request($url);
			//Log::write($res,'insertScore_addscore');

			$res = json_decode($res,true);
			if(isset($res) && ($res['status'] == '0')){
				$score = $user['score'] + $fee;
				$logtype = $fee>0 ? 1 : 0;				
				$this->addRechargeLog($user['Id'],abs($fee),$user['score'],$score,$logtype);
				return true;
			}else{
				return json_encode($res);
			}
			
		}
		return false;
	}
		
	public function setUserVip($data){
		if(empty($data)){ return false; }
		if(empty($data['i'])){ return false; }
		if(!isset($data['t'])){ return false; }
		
		$user = Db::table('gameaccount.newuseraccounts')
					->where('Id',$data['i'])
					->find();					
		if($user){
			
			$res = Db::name('gameaccount.newuseraccounts')
						->where('Id', $user['Id'])
						->data(['is_vip' => $data['t']])
						->update();
			if($res){
				return true;
			}
		}
		
		return false;
	}
	
	
	
	public function rechargeLogs($num = 10){
		$kfid = $this->getAgId();
		$list = Db::table('ym_manage.rechargelog_kefu')->where('kefuid',$kfid)->order('id desc')->paginate($num);
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	public function rechargeLogsCount(){
		$kfid = $this->getAgId();
		return Db::table('ym_manage.rechargelog_kefu')->where('kefuid',$kfid)->count();
	}

	public function rechargeLogs1($num = 10){
		$kfid = $this->getAgId();
		$list = Db::table('ym_manage.rechargelog_kefu_zy')->where('kefuid',$kfid)->order('id desc')->paginate($num);
		$page = $list->render();
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	public function rechargeLogsCount1(){
		$kfid = $this->getAgId();
		return Db::table('ym_manage.rechargelog_kefu_zy')->where('kefuid',$kfid)->count();
	}
	
	
}
