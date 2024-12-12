<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use think\Db;
use app\admin\model\AdminModel;
use app\admin\model\ConfigModel;

class Config extends Parents
{

	private $apiurl = '';
	
	public function __construct(){
		parent::__construct();
		$admin = new AdminModel();

		// 读取配置信息
		$config = ConfigModel::getSystemConfig();
		$this->apiurl = $config['GameServiceApi'];
		// $this->apiurl = $admin->getConfig('app.YxxUpd_API');
	}
	
    public function lists()
    {	
		//获取难度
		$nandu = $this->nandu_get();
		$this->assign('nandu',$nandu);
		
		//关卡送优惠券设置
		$quan = $this->quan_get();
		$this->assign('quan',$quan);
		
		//积分设置
		$jifen = $this->jifen_get();
		$this->assign('jifen',$jifen);
		
		//跑马灯设置
		$deng = $this->deng_get();
		$this->assign('deng',$deng);
		
		//规则文本设置
		$txt = $this->txt_get();
		$this->assign('txt',$txt);
		
        return $this->fetch();
    }
	
	private function nandu_get(){
		$file_nandu = './setConfig_nandu';
		if(file_exists($file_nandu)){
			$nandu = file_get_contents($file_nandu);
			$nandu = json_decode($nandu,true);
		}else{
			$nandu = [
				1=>['big'=>1,'num'=>5],
				2=>['big'=>2,'num'=>10],
				3=>['big'=>3,'num'=>15],
				4=>['big'=>4,'num'=>20],
				5=>['big'=>5,'num'=>25],
				6=>['big'=>6,'num'=>25],
				7=>['big'=>7,'num'=>30],
				8=>['big'=>8,'num'=>30],
				9=>['big'=>9,'num'=>35],
				10=>['big'=>10,'num'=>35],
			];
		}
		return $nandu;
	}
	
	public function nandu_save(){
		$data = request()->post();
		$data = $data['nandu'];
		foreach($data as $k=>$v ){
			
			$big = (int) $v['big'];
			if($big > 10 || $big < 1){
				$big = 1;
			}
			$data[$k]['big'] = $big;
			
			$num = (int) $v['num'];
			if($num > 35 || $num < 1){
				$num = 10;
			}
			$data[$k]['num'] = $num;
			
		}
		
		$check = Db::table('ym_manage.tytconfig')->where('flag','nandu')->count();
		if($check){
			$dbdata = ['value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->where('flag', 'nandu')->update($dbdata);
		}else{
			$dbdata = ['flag' => 'nandu', 'value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->insert($dbdata);
		}
		
		
		file_put_contents('./setConfig_nandu', json_encode($data));
		$this->redirect('lists');
	}
	
	private function quan_get(){
		$file = './setConfig_quan';
		if(file_exists($file)){
			$quan = file_get_contents($file);
			$quan = json_decode($quan,true);
		}else{
			$quan = [
				1=>'201812250001',
				2=>'201812250002',
				3=>'',
				4=>'',
				5=>'',
				6=>'',
				7=>'',
				8=>'',
				9=>'',
				10=>'201812250002',
			];
		}
		return $quan;
	}
	
	public function quan_save(){
		$data = request()->post();
		$data = $data['quan'];
				
		$check = Db::table('ym_manage.tytconfig')->where('flag','quan')->count();
		if($check){
			$dbdata = ['value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->where('flag', 'quan')->update($dbdata);
		}else{
			$dbdata = ['flag' => 'quan', 'value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->insert($dbdata);
		}
		
		
		file_put_contents('./setConfig_quan', json_encode($data));
		$this->redirect('lists');
	}
	
	private function jifen_get(){
		$file_nandu = './setConfig_jifen';
		if(file_exists($file_nandu)){
			$nandu = file_get_contents($file_nandu);
			$nandu = json_decode($nandu,true);
		}else{
			$nandu = [
				1=>['xiaohao'=>1,'huodelv'=>1],
				2=>['xiaohao'=>2,'huodelv'=>2],
				3=>['xiaohao'=>3,'huodelv'=>3],
				4=>['xiaohao'=>4,'huodelv'=>4],
				5=>['xiaohao'=>5,'huodelv'=>5],
				6=>['xiaohao'=>6,'huodelv'=>6],
				7=>['xiaohao'=>7,'huodelv'=>7],
				8=>['xiaohao'=>8,'huodelv'=>8],
				9=>['xiaohao'=>9,'huodelv'=>9],
				10=>['xiaohao'=>10,'huodelv'=>10],
			];
		}
		return $nandu;
	}
	
	public function jifen_save(){
		$data = request()->post();
		$data = $data['jifen'];
		foreach($data as $k=>$v ){
			
			$big = (int) $v['xiaohao'];
			if($big < 1){
				$big = 1;
			}
			$data[$k]['xiaohao'] = $big;
			
			$num = (int) $v['huodelv'];
			if($num < 1){
				$num = 1;
			}
			$data[$k]['huodelv'] = $num;
			
		}
		
		$check = Db::table('ym_manage.tytconfig')->where('flag','jifen')->count();
		if($check){
			$dbdata = ['value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->where('flag', 'jifen')->update($dbdata);
		}else{
			$dbdata = ['flag' => 'jifen', 'value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->insert($dbdata);
		}
		
		file_put_contents('./setConfig_jifen', json_encode($data));
		$this->redirect('lists');
	}
	
	private function deng_get(){
		$file = './setConfig_deng';
		if(file_exists($file)){
			$deng = file_get_contents($file);
			$deng = json_decode($deng,true);
		}else{
			$time = date('Y-m-d H:i:s',strtotime('+1day'));
			$deng = [
				1=>['text'=>'测试测试测试','lv'=>5,'ex'=>$time],
				2=>['text'=>'测试测试测试','lv'=>5,'ex'=>$time],
				3=>['text'=>'','lv'=>5,'ex'=>$time],
				4=>['text'=>'','lv'=>5,'ex'=>$time],
				5=>['text'=>'','lv'=>5,'ex'=>$time],
				6=>['text'=>'','lv'=>5,'ex'=>$time],
				7=>['text'=>'','lv'=>5,'ex'=>$time],
				8=>['text'=>'','lv'=>5,'ex'=>$time],
				9=>['text'=>'','lv'=>5,'ex'=>$time],
				10=>['text'=>'','lv'=>5,'ex'=>$time],
			];
		}
		return $deng;
	}
	
	public function deng_save(){
		$data = request()->post();
		$data = $data['deng'];
		foreach($data as $k=>$v ){
			
			$lv = (int) $v['lv'];			
			$data[$k]['lv'] = $lv;
						
		}
		
		$check = Db::table('ym_manage.tytconfig')->where('flag','deng')->count();
		if($check){
			$dbdata = ['value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->where('flag', 'deng')->update($dbdata);
		}else{
			$dbdata = ['flag' => 'deng', 'value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->insert($dbdata);
		}
		
		
		file_put_contents('./setConfig_deng', json_encode($data));
		$this->redirect('lists');
	}
	
	private function txt_get(){
		$file = './setConfig_txt';
		if(file_exists($file)){
			$txt = file_get_contents($file);
			$txt = json_decode($txt,true);
		}else{
			$txt = '规则文本。。。。。';
		}
		return $txt;
	}
	
	public function txt_save(){
		$data = request()->post();
		$data = $data['txt'];
				
		$check = Db::table('ym_manage.tytconfig')->where('flag','txt')->count();
		if($check){
			$dbdata = ['value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->where('flag', 'txt')->update($dbdata);
		}else{
			$dbdata = ['flag' => 'txt', 'value' => json_encode($data)];
			Db::name('ym_manage.tytconfig')->insert($dbdata);
		}
		
		
		file_put_contents('./setConfig_txt', json_encode($data));
		$this->redirect('lists');
	}
	
	public function yxxfkc(){
		
		$act = "tablequery";
		$param = "";
		$url = $this->gen_yxx_api_url($act,$param);		
		$res = $this->_request($url);
		//var_dump($res);
		//$res = '{"status":1,"result":[{"table_id":"0","tableKey":"541385","ju_shu":15,"round_num":15}]}';
		
		$res = json_decode($res,true);
		if( isset($res['status']) && $res['status'] == '1'){
			$list = $res['result'];
		}else{
			echo '查询失败<br/>';
			$list = [];
		}
		$this->assign('list',$list);
		
		return $this->fetch();
	}
	
	public function yxxfkcSet(){
		$table_id = input('param.tid');
		$table_key = input('param.tkey');
		$this->assign('tableid',$table_id);
		$this->assign('tablekey',$table_key);
		
		$act = "tabletype";
		$param = "&table_id=".$table_id;
		$url = $this->gen_yxx_api_url($act,$param);
		$res = $this->_request($url);
		//var_dump($res);
		//$res = '{"status":1,"result":{"is_table_type":1,"bet_time":33,"bet_data":[{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":6,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3124,"seatId":1}],"nuo_bet_data":[{"bet_type":5,"bet_res":[5,2],"bet_gold":712,"userId":3124,"seatId":1}]}}';
		
		//连串bet_type2  bet_res数组[4,5]
		//string(227) "{"status":1,"result":{"is_table_type":1,"bet_time":6,"bet_data":[{"bet_type":2,"bet_res":[4,5],"bet_gold":200,"userId":3170,"seatId":1},{"bet_type":2,"bet_res":[1,5],"bet_gold":200,"userId":3170,"seatId":1}],"nuo_bet_data":[]}}"
		
		$res = json_decode($res,true);
		if( isset($res['status']) && $res['status'] == '1'){
			$list = $res['result'];
			//print_r($list);
		}else{
			echo '查询失败<br/>';
			$list = [];
		}
		$this->assign('list',$list);
		
		return $this->fetch('yxxfkcset');
	}
	
	public function ajaxYxxfkcSet(){
		$data = request()->post();
		$table_id = $data['tid'];
		
		$act = "tabletype";
		$param = "&table_id=".$table_id;
		$url = $this->gen_yxx_api_url($act,$param);			
		$res = $this->_request($url);
		//var_dump($res);
		//$res = '{"status":1,"result":{"is_table_type":1,"bet_time":30,"bet_data":[{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":6,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3125,"seatId":2},{"bet_type":1,"bet_res":3,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":5,"bet_gold":500,"userId":3124,"seatId":1},{"bet_type":1,"bet_res":2,"bet_gold":500,"userId":3124,"seatId":1}],"nuo_bet_data":[{"bet_type":5,"bet_res":[5,2],"bet_gold":712,"userId":3124,"seatId":1}]}}';
		
		$res = json_decode($res,true);
		if( !isset($res['status']) || $res['status'] != '1'){
			die('error');
		}
		
		$res = $res['result'];
		
		$result = array();
		$result['changetype'] = ($res['is_table_type'] === 1) ? '允许' : '禁止';
		$result['daojishi'] = $res['bet_time'];
		
		$betdata = '<table class="layui-table">					  
					  <thead>
						<tr>
						  <th>座位号</th>
						  <th>用户ID</th>
						  <th>类型</th>
						  <th>押位置</th>
						  <th>金币数</th>
						</tr> 
					  </thead>
					  <tbody>';
					
		foreach( $res['bet_data'] as $k=>$v ){
			$betdata .= '<tr>
						  <td>'.$v['seatId'].'</td><td>'.$v['userId'].'</td>';
			
			switch ($v['bet_type']){
				case 1:
				  $betdata .= '<td>单压</td><td>'.$v['bet_res'].'</td>';
				  break;  
				case 2:
				  $betdata .= '<td>连串</td><td>'.implode(',',$v['bet_res']).'</td>';
				  break;
				case 3:
				  $betdata .= '<td>豹子</td><td>'.$v['bet_res'].'</td>';
				  break;
				default:
				  $betdata .= '<td>'.$v['bet_type'].'</td><td>'.$v['bet_res'].'</td>';
			}
			$betdata .= '<td>'.$v['bet_gold'].'</td>';							
		}
		$betdata .= '</tbody></table>';
		$result['betdata'] = $betdata;
		
		$nuobetdata = '<table class="layui-table">					  
					  <thead>
						<tr>
						  <th>座位号</th>
						  <th>用户ID</th>
						  <th>类型</th>
						  <th>开始位置</th>
						  <th>结束位置</th>
						  <th>金币数</th>
						</tr> 
					  </thead>
					  <tbody>';
						
		foreach( $res['nuo_bet_data'] as $k=>$v ){
			$nuobetdata .= '<tr>';
			$nuobetdata .= '<td>'.$v['seatId'].'</td>';
			$nuobetdata .= '<td>'.$v['userId'].'</td>';
			$nuobetdata .= '<td>挪</td>';
			$nuobetdata .= '<td>'.$v['bet_res'][0].'</td>';
			$nuobetdata .= '<td>'.$v['bet_res'][1].'</td>';
			$nuobetdata .= '<td>'.$v['bet_gold'].'</td>';			
			$nuobetdata .= '</tr>';
		}
		$nuobetdata .= '</tbody></table>';
		$result['nuobetdata'] = $nuobetdata;
		
		echo json_encode($result);
		
	}
	
	public function ajaxyxxfkcsetzjl(){
		$data = request()->post();
		$table_id = $data['tid'];
		$zjl = $data['city'];
		
		$act = "tableResUpdate";
		$param = "&table_id=".$table_id."&res_win=".$zjl;
		$url = $this->gen_yxx_api_url($act,$param);
		$res = $this->_request($url);
		$res = json_decode($res,true);
		if(isset($res) && ($res['status'] == '1') ){
			echo '操作成功';
		}else{
			echo '操作失败';
		}
	}
	
	private function gen_yxx_api_url($act,$param){
			
		$time = strtotime('now');
		$key = 'dkl4234908fjfsn93d';
		$sign = $act.$time.$key;
		$md5sign = md5($sign);
		$url = $this->apiurl.":13850"."/manage/game?act=".$act."&time=".$time."&sign=".$md5sign.$param;
		return $url;
	}
	
}
