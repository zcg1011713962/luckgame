<?php
namespace app\agent\controller;

use app\admin\controller\Admin;
use think\Controller;
use think\Db;
use think\facade\Request;
use think\facade\Cache;
use think\facade\Cookie;
use think\facade\Config;
use think\facade\Log;
use app\agent\model\AdminModel;
use app\agent\model\UserModel;
use app\admin\model\ConfigModel;

class Api extends Controller
{
	private $config;
	private $hturl;
	
	public function __construct() {
		parent::__construct();

		$this->config = ConfigModel::getSystemConfig();
		$this->hturl = $this->config['GameLoginUrl'];
	}

	private function _request($url, $https=true, $method='get', $data=null)
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
	
	private function apiReturnError($msg=''){
		$rt = array('status'=>0,'msg'=>$msg,'data'=>'');
		echo json_encode($rt);die;
	}
	private function apiReturnSuccess($msg,$data){
		$rt = array('status'=>1,'msg'=>$msg,'data'=>$data);
		echo json_encode($rt);die;
	}
	private function apiReturnTxt($msg,$data){
		$rt = array('status'=>2,'msg'=>$msg,'data'=>$data);
		echo json_encode($rt);die;
	}
	
	public function uidaid()
	{		
	    $data = Request::param();
	    if(empty($data)){ $this->apiReturnError('参数有误'); }
	    if(isset($data['uid']) && empty($data['uid'])){ $this->apiReturnError('uid参数有误'); }
	    if(isset($data['aid']) && empty($data['aid'])){ $this->apiReturnError('aid参数有误'); }
		
		$key = 'fdgkl5rtlk4mfdv';
		$time = $data['time'];
		$sign = $data['sign'];
		if( $sign != md5($time.$key) ){
			$this->apiReturnError('签名验证失败');
		}
		
		$count = Db::table('ym_manage.uidglaid')->where('uid',$data['uid'])->count();
		if($count){
			$this->apiReturnError('uid已关联');
		}else{
			$rs = Db::table('ym_manage.uidglaid')->insert(array(
				'uid' => $data['uid'],
				'aid' => $data['aid'],
				'createtime' => $time
			));
			if($rs){
				$this->apiReturnSuccess('关联成功','success');
			}else{
				$this->apiReturnError('关联失败');
			}
			
		}
		
	}
	public function testuidaid(){
		$time = strtotime('now');
		$key = 'fdgkl5rtlk4mfdv';
		$sign = md5($time.$key);
		$uid = 123;
		$aid = 456;
		$url= $this->hturl."/index.php/agent/api/uidaid/time/{$time}/sign/{$sign}/uid/{$uid}/aid/{$aid}";
		$res = $this->_request($url);
		echo $res;
	}
	
	/**
	 * 用户填写code 绑定代理
	 */
	public function uidcode()
	{		
	    $data = Request::param();
	    if(empty($data)){ $this->apiReturnError('参数有误'); }
	    if(isset($data['uid']) && empty($data['uid'])){ $this->apiReturnError('uid参数有误'); }
	    if(isset($data['code']) && empty($data['code'])){ $this->apiReturnError('code参数有误'); }
		
		$key = 'fdgkl5rtlk4mfdv';
		$time = $data['time'];
		$sign = $data['sign'];
		if( $sign != md5($time.$key) ){
			$this->apiReturnError('签名验证失败');
		}
		
		$count = Db::table('ym_manage.uidglaid')->where('uid',$data['uid'])->count();
		if($count){
			$this->apiReturnError('uid已关联');
		}else{
			$aid = Db::table('ym_manage.agentinfo')->where('yqcode',$data['code'])->value('aid');
			if(!$aid){
				$this->apiReturnError('未找到相匹配的代理');
			}

			$gu = Db::table('gameaccount.newuseraccounts')->where('Id',$data['uid'])->value('Id');
			if(!$gu){
				$this->apiReturnError('uid未找到相匹配的用户');
			}

			$this->userTurnToAgent($data['uid'],$aid);

			$rs = Db::table('ym_manage.uidglaid')->insert(array(
				'uid' => $data['uid'],
				'aid' => $aid,
				'createtime' => $time
			));
			if($rs){
				$this->apiReturnSuccess('关联成功','success');
			}else{
				$this->apiReturnError('关联失败');
			}
			
		}
		
	}
	
	public function testuidcode(){
		$time = strtotime('now');
		$key = 'fdgkl5rtlk4mfdv';
		$sign = md5($time.$key);
		$uid = 3327;
		$code = '013479';
		$url= $this->hturl."/index.php/agent/api/uidcode/time/{$time}/sign/{$sign}/uid/{$uid}/code/{$code}";
		$res = $this->_request($url);
		echo $res;
	}

	/**
	 * 绑定代理 该用户变为代理  代理统计佣金
	 */
	private function userTurnToAgent($uid,$parentaid){

		$salt = substr(md5(time().'dfsgre4'),5,6);
		$username = $uid.'ABC'.$salt;
		$password = '123456';
		$arr = array(
			'id' => $uid,
			'username' => $username,
			'password' => md5($password.$salt),
			'salt' => $salt,
			'isagent' => 1,
		);

		Db::table('ym_manage.admin')->insert($arr);
		$aid = $uid;

		$adminmodel = new AdminModel();
		$yqcode = $adminmodel->gen_yqcode();

		$level = 2;
		if($level == 2){
			$pinfo = Db::table('ym_manage.agentinfo')->where('aid',$parentaid)->find();
			if($pinfo){
				$level = $pinfo['level'] + 1;
			}
		}
		$ainfo = array(
			'aid' => $aid,
			'level' => $level,
			'yqcode' => $yqcode,
			'name' => '',
			'wxname' => '',
			'mobile' => '',
			'createtime' => time(),
			'pid' => $parentaid,
			'uid' => $aid
		);
		Db::table('ym_manage.agentinfo')->insert($ainfo);
		
		return true;
	}
	
	/**
	 * 代理返佣金
	 * 延迟1分钟执行
	 * http://127.0.0.1/index.php/agent/api/weekCalc
	 */
	public function weekCalc()
	{		
		$time = time();

		$mon = strtotime('Sunday -6 day', strtotime('now'));
		$sun = strtotime('Sunday', strtotime('now'));
		
		$monday = date('Y-m-d',$mon).' 00:00:00';
		$sunday = date('Y-m-d',$sun).' 23:59:59';
		//echo $monday,'<br/>',$sunday;

		$mondaytime = strtotime($monday);
		$sundaytime = strtotime($sunday);

		//清空表
		Db::query("TRUNCATE TABLE ym_manage.fanyong;");

		$agents = Db::table('ym_manage.agentinfo')->select();
		$log = array();
		foreach($agents as $k=>$agent){
			$usernum = 0;

			$ids_list = Db::table('ym_manage.uidglaid')->field('uid')->where('aid',$agent['aid'])->select();
			$ids = '';
			foreach($ids_list as $vo){
				$ids .= $vo['uid'].',';
				$usernum++;
			}
			$ids = rtrim($ids,',');

			$czlist = Db::table('ym_manage.rechargelog')
						//->where('createtime','>=',$mondaytime)
						//->where('createtime','<', $sundaytime)
						->where('userid','in',$ids)
						->where('type','1')
						->select();
			$log[$k]['czlist'] = $czlist;

			$czfee = 0;
			foreach($czlist as $row){
				$czfee += $row['czfee']/100;
			}

			$czxflist = Db::table('ym_manage.fanyong_xflog')
						->where('aid',$agent['aid'])
						->select();
			$log[$k]['czxflist'] = $czxflist;

			$czxffee = 0;
			foreach($czxflist as $row){
				$czxffee += $row['xffee'];
			}
			$czfee = $czfee - $czxffee;
			$log[$k]['czfee'] = $czfee;

			$yulist = Db::table('gameaccount.userinfo_imp')						
						->where('userId','in',$ids)
						->select();
			$log[$k]['yulist'] = $yulist;

			$yufee = 0;
			foreach($yulist as $row){
				$yufee += $row['score']/100;
			}
			$log[$k]['yufee'] = $yufee;

			$kuifee = round($czfee - $yufee, 2);
			$log[$k]['kuifee'] = $kuifee;

			$createtime = $time;
			$log[$k]['createtime'] = $createtime;

			$insert = array(
				'aid' => $agent['aid'],
				'usernum' => $usernum,
				'czfee' => $czfee,
				'kuifee' => $kuifee,
				'yufee' => $yufee,
				'createtime' => $createtime
			);
			Db::table('ym_manage.fanyong')->insert($insert);
			$log[$k]['fanyongdb'] = $insert;

			$dofan = $this->calcFanYong($agent['aid'],$usernum,$kuifee);
			$log[$k]['dofan'] = $dofan;
		}
		file_put_contents('./fylogs/weekCalc1_'.$time.'.log',json_encode($log));
		$fylogs = Db::table('ym_manage.fanyong')->select();
		file_put_contents('./fylogs/weekCalc2_'.$time.'.log',json_encode($fylogs));
		echo 'do over';
	}

	private function calcFanYongXi($usernum,$kuifee){
		$xi = 0;

		if($kuifee >= 100 && $kuifee <= 5000){
			if($usernum >= 3 && $usernum < 10){
				$xi = 5;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 8;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 10;
			}
			if($usernum >= 50){
				$xi = 20;
			}
		}
		if($kuifee >= 5001 && $kuifee <= 30000){
			if($usernum >= 3 && $usernum < 10){
				$xi = 8;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 10;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 15;
			}
			if($usernum >= 50){
				$xi = 25;
			}
		}
		if($kuifee >= 30001 && $kuifee <= 99999){
			if($usernum >= 3 && $usernum < 10){
				$xi = 10;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 15;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 20;
			}
			if($usernum >= 50){
				$xi = 30;
			}
		}
		if($kuifee >= 100000 && $kuifee <= 299999){
			if($usernum >= 3 && $usernum < 10){
				$xi = 15;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 20;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 25;
			}
			if($usernum >= 50){
				$xi = 35;
			}
		}
		if($kuifee >= 300000 && $kuifee <= 999999){
			if($usernum >= 3 && $usernum < 10){
				$xi = 20;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 25;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 30;
			}
			if($usernum >= 50){
				$xi = 40;
			}
		}
		if($kuifee >= 1000000 && $kuifee <= 4999999){
			if($usernum >= 3 && $usernum < 10){
				$xi = 30;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 35;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 40;
			}
			if($usernum >= 50){
				$xi = 50;
			}
		}
		if($kuifee >= 5000000 && $kuifee <= 9999999){
			if($usernum >= 3 && $usernum < 10){
				$xi = 35;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 40;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 50;
			}
			if($usernum >= 50){
				$xi = 50;
			}
		}
		if($kuifee >= 10000000 ){
			if($usernum >= 3 && $usernum < 10){
				$xi = 40;
			}
			if($usernum >= 10 && $usernum < 30){
				$xi = 50;
			}
			if($usernum >= 30 && $usernum < 50){
				$xi = 50;
			}
			if($usernum >= 50){
				$xi = 50;
			}
		}
		return $xi;
	}

	private function calcFanYong($aid,$usernum,$kuifee){
		if(empty($aid) || empty($usernum) || empty($kuifee) || ($kuifee < 0) ){ return false; }
		$xi = $this->calcFanYongXi($usernum,$kuifee);

		if($xi){
			$addfee = round($kuifee * $xi /100, 2);
			$ainfo = Db::table('ym_manage.agentinfo')->where('aid',$aid)->find();
			$oldfee = round($ainfo['commission'], 2);
			$newfee = round($addfee + $oldfee, 2);
			//增加佣金
			Db::table('ym_manage.agentinfo')->where('aid',$aid)->update(['commission'=>$newfee]);
			//增加佣金记录
			$log = array(
				'aid' => $aid,
				'addfee' => $addfee,
				'oldfee' => $oldfee,
				'newfee' => $newfee,
				'createtime' => time()
			);
			Db::table('ym_manage.fanyong_log')->insert($log);
			return true;
		}

		return false;
	}
	
	public function testWeekCalc(){
		$time = strtotime('now');
		$key = 'fdgkl5rtlk4mfdv';
		$sign = md5($time.$key);
		$uid = 123;
		$code = '013467';
		$url= $this->hturl."/index.php/agent/api/uidcode/time/{$time}/sign/{$sign}/uid/{$uid}/code/{$code}";
		$res = $this->_request($url);
		echo $res;
	}

	//http://127.0.0.1/index.php/agent/api/gameServerApi_saveAllUser
	//先提前1min执行 然后去数据库查询数据
	//status 0成功 1有误
	public function gameServerApi_saveAllUser(){
		$act = "saveAllUser";			
		$time = strtotime('now');
		$key = $this->config['PrivateKey'];
		$sign = $act.$time.$key;
		$md5sign = md5($sign);
		$apiurl = $this->config['GameServiceApi'];
		$url= $apiurl."/Activity/gameuse?act=".$act."&time=".$time."&sign=".$md5sign;
		$res = $this->_request($url);
		//{"status":0,"msg":""}

		Log::write('SaveAllUser: '.$res,'info');
		echo 'success';
	}

	//不是代理时返回管理员微信号
	private function getConfigTxt(){
		$txt = Db::table('ym_manage.config')->where('flag','MANAGER_WECHAT_NUMBER')->find();
		return $txt ? $txt['value']: '';
	}

	/**
	 * 客户端显示信息
	 */
	public function clientShow(){
		$return = array();

		//$data = Request::param();
		//$data = file_get_contents('php://input');
		//echo json_encode($data);die;

		$data = file_get_contents('php://input');
		$data = json_decode($data,true);

	    if(empty($data)){ $this->apiReturnError('参数有误'); }
	    if(isset($data['uid']) && empty($data['uid'])){ $this->apiReturnError('uid参数有误'); }
	    if(isset($data['sign']) && empty($data['sign'])){ $this->apiReturnError('sign参数有误'); }
		
		$uid = intval($data['uid']);
		$sign = $data['sign'];
		$key = 'fdgkl5rtlk4mvcccd765fdv';
		if( $sign != md5($uid.$key) ){
			$this->apiReturnError('签名验证失败');
		}

		$adminModel = new AdminModel();
		$checkAgent = $adminModel->getAgentDetail($uid);
		if(empty($checkAgent)){
			$txt = $this->getConfigTxt();	
			$this->apiReturnTxt('success',$txt);
			//$this->apiReturnError('该用户不是代理');
		}

		$time = time();

		$mon = strtotime('Sunday -6 day', $time);
		$sun = strtotime('Sunday', $time);
		
		$monday = date('Y-m-d',$mon).' 00:00:00';
		$sunday = date('Y-m-d',$sun).' 23:59:59';
		
		$mondaytime = strtotime($monday);
		$sundaytime = strtotime($sunday);
		$return['timeDiff'] = $sundaytime - $time;//时间差

		$infos = $adminModel->get3ji_api_infos($uid);
		if(empty($infos)){
			$this->apiReturnError('获取信息失败');
		}
		$return['numA'] = $infos['num1'];
		$return['numB'] = $infos['num2'];
		$return['numC'] = $infos['num3'];
		//$return['nowIncome'] = $this->getOneUserNowIncome($uid,$mondaytime,$sundaytime);
		$return['AllYongJin'] = $this->getAllYongJin($uid);
		$return['person']['a'] = $this->getPerson($infos['ids1'],$mondaytime,$sundaytime,$return['numA']);
		$return['person']['b'] = $this->getPerson($infos['ids2'],$mondaytime,$sundaytime,$return['numA']);
		$return['person']['c'] = $this->getPerson($infos['ids3'],$mondaytime,$sundaytime,$return['numA']);

		$all = [];
		if(!empty($return['person']['a'])){
			$all += $return['person']['a'];
		}
		if(!empty($return['person']['b'])){
			$all += $return['person']['b'];
		}
		if(!empty($return['person']['c'])){
			$all += $return['person']['c'];
		}
		$return['person']['all'] = $all;

		$return['nowIncome'] = $this->calcMeShiShi($return['person']['all']);
		
		$this->apiReturnSuccess('success',$return);
	}

	private function calcMeShiShi($arr){
		if(empty($arr)){ return 0; }
		$fee = 0;
		foreach($arr as $row){
			if(!empty($row[2])){
				$fee += $row[2];
			}
		}
		return round($fee, 2);
	}

	/**
	 * 查询一个用户的实时收益
	 */
	private function getOneUserNowIncome_bak($uid,$mondaytime,$sundaytime){
		$adminModel = new AdminModel();
		$infos = $adminModel->get3ji_api_infos($uid);
		if(empty($infos)){ return 0; }
		$fee = 0;

		$one   = explode(',',$infos['ids1']);
		$two   = explode(',',$infos['ids2']);
		$three = explode(',',$infos['ids3']);

		$arr = array_merge($one,$two,$three);
		foreach($arr as $row){
			$fee += $this->getOneUserScoreToIncome($row,$mondaytime,$sundaytime);
		}

		return $fee<=0 ? 0 : $fee;
	}

	/**
	 * 查询一个用户的实时收益
	 */
	private function getOneUserNowIncome($kuifee,$lv){		
		if(empty($kuifee)){ return 0; }		
		return round($kuifee * $lv /100, 2);
	}

	private function getOneUserScoreToIncome($uid,$mondaytime,$sundaytime){
		$adminModel = new AdminModel();
		$infos = $adminModel->get3ji_api_infos($uid);
		if(empty($infos)){ return 0; }

		$_nowScore = $this->getNowIncome($uid,$mondaytime,$sundaytime);//当前战绩
		$_xi = $this->calcFanYongXi($infos['num1'], $_nowScore);
		$fee = $_nowScore * $_xi/100;//当前收益
		return $fee<=0 ? 0 : $fee;
	}

	private function getNowRecharge($uid,$mondaytime,$sundaytime){
		if(empty($uid)){ return 0; }
		$czlist = Db::table('ym_manage.rechargelog')
				->where('createtime','>=',$mondaytime)
				->where('createtime','<', $sundaytime)
				->where('userid','in',$uid)
				->where('type','1')
				->select();
		
		$czfee = 0;
		foreach($czlist as $row){
			$czfee += $row['czfee'];//分
		}
		return $czfee;
	}

	private function getAllRecharge($uid){
		if(empty($uid)){ return 0; }
		$czlist = Db::table('ym_manage.rechargelog')
				->where('userid','in',$uid)
				->where('type','1')
				->select();
		
		$czfee = 0;
		foreach($czlist as $row){
			$czfee += $row['czfee'];//分
		}
		return $czfee;
	}

	private function getNowScore($uid){
		if(empty($uid)){ return 0; }
		$user = new UserModel;
		$info = $user->getUserInfo($uid);		
		$realnum = $user->getRealNum($info['Account']);
		$score = empty($realnum) ? 0 : $realnum;
		return $score;
	}

	private function getNowIncome($uid,$mondaytime,$sundaytime){
		if(empty($uid)){ return 0; }
		$recharge = $this->getNowRecharge($uid,$mondaytime,$sundaytime);
		$score = $this->getNowScore($uid);
		return round( ( $score - $recharge )/100, 2);
	}

	private function getAllIncome($uid){
		if(empty($uid)){ return 0; }
		$recharge = $this->getAllRecharge($uid);
		$score = $this->getNowScore($uid);
		$rs = round( ( $score - $recharge )/100, 2);
		return $rs>0 ? 0 : $rs;
	}

	private function getAllYongJin($uid){
		if(empty($uid)){ return 0; }
		$adminModel = new AdminModel();
		$info = $adminModel->getCommissionList_Api($uid);
		return round($info, 2);
	}

	private function getPerson($ids,$mondaytime,$sundaytime,$numA){
		if(empty($ids)){ return false; }
		$adminModel = new AdminModel();
		$list = $adminModel->get3ji_list($ids);
		$return = [];
		foreach($list as $v){			
			$_nowScore = $this->getNowIncome($v['aid'],$mondaytime,$sundaytime);//当前战绩
			$_kuiScore = $this->getALLIncome($v['aid']);//总亏损

			$xi = $this->calcFanYongXi($numA,abs($_kuiScore));
			if($_kuiScore < 0){
				$_nowIncome = round( abs($_kuiScore) * $xi /100, 2);
			}else{
				$_nowIncome = 0;
			}
			
			//$_nowIncome = $this->getOneUserNowIncome($v['aid'],$mondaytime,$sundaytime);

			$_allIncome = $this->getAllYongJin($v['aid']);//总收益
			$_return = [$_nowScore,$_kuiScore,$_nowIncome,$_allIncome];
			$return[$v['aid']] = $_return;
		}
		return $return;
	}

	public function testClientShow($uid=3241){		
		$key = 'fdgkl5rtlk4mvcccd765fdv';
		//$uid = 3241;
		$sign = md5($uid.$key);
		$url= $this->hturl."/index.php/agent/api/clientShow/uid/{$uid}/sign/{$sign}";
		$res = $this->_request($url);
		echo $res;
	}
	
	
	/**
	 * 用户如果是代理 返回代理号
	 */
	public function agentCode()
	{		
	    $data = Request::param();
	    if(empty($data)){ $this->apiReturnError('参数有误'); }
	    if(isset($data['uid']) && empty($data['uid'])){ $this->apiReturnError('uid参数有误'); }
		
		$uid = $data['uid'];
		
		$adminModel = new AdminModel();
		$checkAgent = $adminModel->getAgentDetail($uid);
		if(empty($checkAgent)){
			$this->apiReturnError('该用户不是代理');
		}else{
			$this->apiReturnSuccess('success',$checkAgent['yqcode']);
		}
		
	}
	
	//http:127.0.0.1/index.php/agent/api/testagentcode
	public function testagentcode(){		
		$uid = 3327;
		$url= $this->hturl."/index.php/agent/api/agentCode/uid/{$uid}";
		$res = $this->_request($url);
		echo $res;
	}
	
}
