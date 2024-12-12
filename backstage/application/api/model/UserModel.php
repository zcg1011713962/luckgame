<?php
namespace app\api\model;
use think\Model;
use think\Db;
use think\facade\Config;
use app\admin\model\ConfigModel;

class UserModel extends Model
{
	private $key = '';
	private $apiurl = '';
	
	public function __construct(){
		parent::__construct();

		// 读取配置信息
		$config = ConfigModel::getSystemConfig();
		$this->apiurl = $config['GameServiceApi'];
		$this->key = $config['PrivateKey'];
		// $this->apiurl = Config::get('app.Recharge_API');
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
	
	/**
	 * 通过token查询用户信息
	 */
	public function userinfo($token){
		$rs = $this->getUserInfoByToken($token);		
		return $rs;
	}

	/**
	 * 通过openid查询用户信息
	 */
	public function getUserInfoByOpenid($openid){
		return Db::table('ym_manage.user')->where('openid',$openid)->find();
	}
	
	/**
	 * 通过uid和to查询用户信息
	 */
	public function getUserInfoByUidAndTo($uid,$to){
		return Db::table('ym_manage.user')->where('uid',$uid)->where('fromtype',$to)->find();
	}

	/**
	 * 生成用户信息
	 */
	public function genUserInfo($openid){
		$time = time();
		$data = array(
			'id' => 0,
			'openid' => $openid,
			'nickname' => '游客'.mt_rand(1000,9999),
			'avatar' => '',
			'score' => 0,//金币
			'diamond' => 0,//钻石
			'quan' => 0,//参赛券
			'jifen' => 0,//积分
			'yue' => 0,//余额
			'duanwei' => 1,
			'xingji' => 1,
			'createtime' => $time,
			'logintime' => $time
		);
		$rs = Db::table('ym_manage.user')->insertGetId($data);
		$data['id'] = $rs;
		return $rs ? $data : false;		
	}

	/**
	 * 验证用户
	 */
	public function checkUser($val,$key='id'){
		return Db::table('ym_manage.user')->where($key,$val)->count();
	}
	
	/**
	 * 获取用户信息
	 */
	public function getUser($val,$key='id'){
		return Db::table('ym_manage.user')->where($key,$val)->find();
	}
	
	/**
	 * 编辑用户信息
	 */
	public function editUser($whereKey,$where,$key,$val){
		$time = time();
		$info = $this->getUser($where,$whereKey);
		if($info){
			if($key == 'token'){
				$token = md5(md5($info['uid'].$info['fromtype'].$time).substr(md5($time),5,10));
				$val = $token;
			}
			return Db::name('ym_manage.user')->where($whereKey,$where)->update([$key => $val, 'logintime' => $time]);
		}
		return false;		
	}
	
	/**
	 * 用户初始化 返回token
	 */
	public function UserInit($uid, $to){
		$time = time();
		$user = $this->getUserInfoByUidAndTo($uid, $to);
		$token = md5(md5($uid.$to.$time).substr(md5($time),5,10));
		if($user){
			//已存在 更新token			
			$rs = Db::name('ym_manage.user')->where('id',$user['id'])->setField('token', $token);
			return $rs ? $token : false;
		}else{
			//不存在 新建账号
			$account = Db::table('gameaccount.newuseraccounts')->where('Id',$uid)->find();
			if(!$account){ return false; }
			$data = array(
				'openid' => '',
				'account' => $account['Account'],
				'nickname' => $account['nickname'],
				'avatar' => $account['headimgurl'],
				'score' => 0,
				'diamond' => 0,
				'jifen' => 0,
				'yue' =>  0,
				'createtime' => $time,
				'logintime' => $time,
				'uid' => $uid,
				'token' => $token,
				'fromtype' => $to
			);
			$rs = Db::table('ym_manage.user')->insertGetId($data);
			return $rs ? $token : false;
		}
	}
	
	/**
	 * 转移金币 存记录
	 */
	public function turnScore($id, $num, $fromtype){
		$time = time();
		$info = $this->getUser($id,'id');
		if($info){
			
			$rs = $this->insertScore($info['account'], $num, $fromtype);
			if(!$rs){ return false; }
			
			$score = $info['score'] + $num;
			$rs = $this->editUser('id',$id,'score',$score);
			if(!$rs){ return false; }
			$logtype = $num>0 ? 1 : 0;
			$this->addRechargeLog($info['uid'],abs($num),$info['score'],$score,$logtype,$fromtype);
			
			return true;
		}
		return false;	
	}
	
	private function insertScore($account,$fee,$fromtype){
		if(empty($account) || empty($fee)){ return false; }
		$account = trim($account);
		$fee = intval($fee) * 1;
		
		$act = "scoreedit";			
		$time = strtotime('now');
		$key = $this->key;
		$sign = $act.$account.$fee.$time.$key;
		$md5sign = md5($sign);
		$url=$this->apiurl."/Activity/gameuse?act=".$act."&accountname=".$account."&goldnum=".$fee."&time=".$time."&sign=".$md5sign;
		$res = $this->_request($url);
		
		$res = json_decode($res,true);
		if(isset($res['status']) && ($res['status'] == '0')){
			$score = $user['score'] + $fee;
			$logtype = $fee>0 ? 1 : 0;				
			$this->addRechargeLog($user['Id'],abs($fee),$user['score'],$score,$logtype,$fromtype);
			return true;
		}else{
			return json_encode($res);
		}
		
		return false;
	}
	
	private function addRechargeLog($uid,$czfee,$oldfee,$newfee,$logtype,$fromtype){
		$log = array(
			'adminid' => 0,
			'userid' => $uid,
			'createtime' => time(),
			'czfee' => $czfee,
			'oldfee' => $oldfee,
			'newfee' => $newfee,
			'type' => $logtype,		//1 加 0 减
			'fromtype' => $fromtype
		);
		Db::name('ym_manage.rechargelog_user')->insert($log);
	}

	/**
	 * 验证用户
	 */
	public function checkAccountUser($val,$key='Id'){
		return Db::table('gameaccount.newuseraccounts')->where($key,$val)->count();
	}

	/**
	 * 验证用户 一分钟支付一次
	 */
	public function checkUserCanPay($uid){
		$time = time();
		$last = Db::table('ym_manage.paylog')->where('uid',$uid)->order('createtime desc')->limit(1)->find();
		if($last){
			if($time > $last['payendtime']){
				return true;
			}
			return false;
		}else{
			return true;
		}
	}
	
	public function getUserPayInfo($uid, $fee, $type){
		$time = time();
		$last = Db::table('ym_manage.paylog')->where('uid',$uid)->where('fee',$fee)->where('type',$type)->order('createtime desc')->limit(1)->find();
		if($last){
			if($time >= $last['createtime']){
				if($time < $last['payendtime']){
					return json_decode($last['prepayresmsg'],true);
				}
			}
		}
		return false;
	}

	public function getOrderStatus($ordersn){
		$log = Db::table('ym_manage.paylog')->where('osn',$ordersn)->find();
		if($log){
			return $log['status'];
		}
		return false;
	}

	public function getNutsPayOrderStatus($ordersn) {
		$log = Db::table('ym_manage.paylog')->where('osn',$ordersn)->find();
		if($log){
			return $log;
		}
		return false;
	}
	
}