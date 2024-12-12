<?php
namespace app\admin\controller;
use app\admin\controller\Parents;
use think\Db;
use think\facade\Config;
use think\facade\Log;

//斗地主比赛场
class Ddzbsc extends Parents
{
	private $dbconn = 'db_ddzbsc';//'mysql://root:root@192.168.1.110:3306/landlords#utf8';

    public function index()
    {	
		//获取难度
		$total = Db::connect($this->dbconn)->table('config')->where('flag','TOTAL')->find();
		$this->assign('total',$total['value']);

		$out = Db::connect($this->dbconn)->table('config')->where('flag','OUT')->find();
		$this->assign('out',$out['value']);

		$start = Db::connect($this->dbconn)->table('config')->where('flag','START_GAME')->find();
		$this->assign('start',$start['value']);

		$score = Db::connect($this->dbconn)->table('config')->where('flag','BM_SCORE')->find();
		$this->assign('score',$score['value']);

		$awards = Db::connect($this->dbconn)->table('config')->where('award','>','0')->select();
		$this->assign('awards',$awards);

		$pw_total = Db::connect($this->dbconn)->table('config')->where('flag','PW_TOTAL')->find();
		$this->assign('pw_total',$pw_total['value']);
		$pw_award1 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD1')->find();
		$this->assign('pw_award1',$pw_award1['value']);
		$pw_award2 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD2')->find();
		$this->assign('pw_award2',$pw_award2['value']);
		$pw_award3 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD3')->find();
		$this->assign('pw_award3',$pw_award3['value']);
		$pw_award4 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD4')->find();
		$this->assign('pw_award4',$pw_award4['value']);
		$pw_award5 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD5')->find();
		$this->assign('pw_award5',$pw_award5['value']);
				
        return $this->fetch();
    }
	
	public function nandu_save(){
		$data = request()->post();
		//var_dump($data);die;
		
		foreach($data as $k => $v){
			$_conf = Db::connect($this->dbconn)->table('config')->where('flag',$k)->find();
			Db::connect($this->dbconn)->table('config')->where('id',$_conf['id'])->update($v);
		}

		$this->redirect('index');
	}

	public function getConfig($flag = ''){
		if(empty($flag)){ return false; }
		return Config::get($flag);
	}

	public function doStartGame(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(!isset($data['t'])){ die('参数有误。'); }

		$conf = Db::connect($this->dbconn)->table('config')->where('flag','START_GAME')->find();
		if($conf['value'] == $data['t']){
			die('当前状态一致，请更换操作');
		}
		
		$res = Db::connect($this->dbconn)->table('config')->where('flag','START_GAME')->update(['value'=>$data['t']]);
		if($res){
			$redis_ip = $this->getConfig('app.redis_ip');
			$redis_port = $this->getConfig('app.redis_port');
			$redis_auth = $this->getConfig('app.redis_auth');
			//发布订阅					
			$redis = new \Redis();
			$redis->connect($redis_ip, $redis_port);
			$redis->auth($redis_auth); 

			$total = Db::connect($this->dbconn)->table('config')->where('flag','TOTAL')->find();		
			$out = Db::connect($this->dbconn)->table('config')->where('flag','OUT')->find();
			$awards = Db::connect($this->dbconn)->table('config')->field('award,type,value')->where('award','>','0')->select();
			$score = Db::connect($this->dbconn)->table('config')->where('flag','BM_SCORE')->find();

			$pw_total = Db::connect($this->dbconn)->table('config')->where('flag','PW_TOTAL')->find();
			$pw_award1 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD1')->find();
			$pw_award2 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD2')->find();
			$pw_award3 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD3')->find();
			$pw_award4 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD4')->find();
			$pw_award5 = Db::connect($this->dbconn)->table('config')->where('flag','PW_AWARD5')->find();

			$str = [
				'total' => $total['value'],
				'out' => $out['value'],
				'score' => $score['value'],
				'start' => $data['t'],
				'awards' => $awards,
				'pw_total' => $pw_total['value'],
				'pw_award1' => $pw_award1['value'],
				'pw_award2' => $pw_award2['value'],
				'pw_award3' => $pw_award3['value'],
				'pw_award4' => $pw_award4['value'],
				'pw_award5' => $pw_award5['value']
			];
			$str = json_encode($str);
			Log::write($str,'doStartGame');
			$rs = $redis->publish('DDZBSC_START', $str);
			Log::write($rs,'doStartGame');
			$redis->close();
		}
		if($res){
			echo 'success';
		}else{
			echo '操作失败';
		}		
	}

	public function logs()
    {	
		$config = Db::connect($this->dbconn)->table('config')->where('award','>','0')->select();
		$_conf = [];
		foreach ($config as $k => $v) {
			$_conf[$v['award']] = $v;
		}		
		$this->assign('_conf',$_conf);
	
		$logs = Db::connect($this->dbconn)->table('log_baoming_save')->where('result','>','0')->select();		
		$this->assign('logs',$logs);

        return $this->fetch();
	}
	
	public function doSendWin(){
		$data = request()->param();
		if(empty($data)){ $this->error('参数有误'); }
		
		if(!isset($data['id'])){ $this->error('参数有误。'); }

		$rs = Db::connect($this->dbconn)->table('log_baoming_save')->where('id',$data['id'])->update(['is_send_win'=>1]);
		if($rs){
			$this->redirect('logs');
		}else{
			$this->error('发奖失败');
		}
	}

}
