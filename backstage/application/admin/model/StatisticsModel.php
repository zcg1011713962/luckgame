<?php
namespace app\admin\model;
use think\Model;
use think\Db;

class StatisticsModel extends Model
{
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
			
	public function getCZTotalfee(){
		$num1 = Db::table('ym_manage.rechargelog')->where('type',1)->sum('czfee');
		$num2 = Db::table('ym_manage.rechargelog')->where('type',0)->sum('czfee');
		
		return array(
			'addfee' => $num1,
			'delfee' => $num2,
			'totalfee' => $num1 - $num2
		);
	}
	
	public function getCZfeeByWhere($starttime,$endtime){
		if(empty($starttime)){ return false; }
		if(empty($endtime)){ return false; }
		
		$num1 = Db::table('ym_manage.rechargelog')
					->where('type',1)
					->where('createtime','>=',$starttime)
					->where('createtime','<=',$endtime)
					->sum('czfee');
		$num2 = Db::table('ym_manage.rechargelog')
					->where('type',0)
					->where('createtime','>=',$starttime)
					->where('createtime','<=',$endtime)
					->sum('czfee');
		return array(
			'addfee' => $num1,
			'delfee' => $num2,
			'totalfee' => $num1 - $num2
		);
		
	}
	
	public function getKClists(){
		$info = Db::table('ym_manage.game')->where('delete_at',0)->order('port asc')->select();
		foreach($info as $k => $v){
			$kucun = Db::table('la_ba.gambling_game_list')->where('nGameID',$v['gameid'])->order('nGameID desc')->limit(1)->find();
			$info[$k]['kucun'] = !empty($kucun) ? $kucun['nGamblingBalanceGold'] : 0;
		}
		return $info;
	}
	
	public function searchKC($id){
		if(empty($id)){return false;}
		
		$info = Db::table('ym_manage.game')->find($id);
		if($info){
			$kucun = Db::table('ym_manage.kucunlog')->where('gameid',$info['gameid'])->order('id desc')->limit(1)->find();
			return !empty($kucun) ? '['.$kucun['createtime'].']  '.$kucun['kucun'] : 0;
		}
		return false;
	}
	
	public function getKCByWhere($starttime,$endtime){
		if(empty($starttime)){ return false; }
		if(empty($endtime)){ return false; }
		$starttime = date('Y-m-d',$starttime);
		$endtime = date('Y-m-d',$endtime);
		
		$num1 = Db::table('ym_manage.kucunlog')
					->where('createtime','like',$starttime.'%')
					->order('id desc')
					->limit(1)
					->find();
		$num2 = Db::table('ym_manage.kucunlog')
					->where('createtime','like',$endtime.'%')
					->order('id desc')
					->limit(1)
					->find();
		//return $num1['kucun'].'-'.$num2['kucun'];
		if(empty($num1) || empty($num2)){ return false; }
		return array(
			'num1' => $num1['kucun'],
			'num2' => $num2['kucun'],
			'res' => $num2['kucun'] - $num1['kucun']
		);
		
	}
	
}
