<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;

class LogsModel extends Model
{
	
	public function yxx1($num = 10){
		
		$list = Db::table('game_log.yu_xia_xie_table_log')
					->order('id desc')
					->paginate($num);
		
		$page = $list->render();
		$list = $list->all();
		$list = $this->yxxLogShow($list);
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	private function yxxLogShow($list){
		if(empty($list)) return [];
		
		foreach($list as $k => $v){
			
			$arr = json_decode($v['table_dict'],true);
			
			$str  = '局数：'.$arr['ju_shu'].'';
			$str .= ' 房卡：'.$arr['fang_ka_shu'].'';
			if( $arr['is_qiang_zhuang'] ){
				$str .= ' 抢庄';
			}else{
				$str .= ' 固定庄';
			}
			$str .= ' 桌号：'.$arr['tableKey'].'';
			$str .= ' [';
			foreach($arr['user_name_dict'] as $k1 => $v1){
				
				if(!$arr['is_qiang_zhuang'] && ($k1==$arr['zhuang'])){
					$str .= ' （庄）'.$v1.'  0 => '.$arr[$k1].' | ';
				}else{
					$str .= ' '.$v1.'  '.$arr['init_gold'].' => '.$arr[$k1].' | ';
				}
				
			}
			$str .= '] ';
			//echo $str;
			$list[$k]['table_dict_show'] = $str;
		}
		
		return $list;
	}
	
	public function yxx1count($search = ''){
		
		return Db::table('game_log.yu_xia_xie_table_log')->count();
		
	}
	
	public function yxx2($num = 10){
		
		$list = Db::table('game_log.yu_xia_xie_club_table_log')
					->order('id desc')
					->paginate($num);
		
		$page = $list->render();
		$list = $list->all();
		$list = $this->yxxLogShow($list);
		
		return array(
			'list' => $list,
			'page' => $page
		);
	}
	
	public function yxx2count($search = ''){
		
		return Db::table('game_log.yu_xia_xie_club_table_log')->count();
		
	}
	
	
}