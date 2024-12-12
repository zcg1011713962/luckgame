<?php
namespace app\agent\controller;
use think\Controller;
use app\agent\controller\Parents;
use app\agent\model\LogsModel;

class Logs extends Parents
{
    public function yxx()
    {	
		$logs = new LogsModel;
		$num = 10;//每页显示数
		
		$res = $logs->yxx1($num);
		$this->assign('list',$res['list']);
		$this->assign('page',$res['page']);
		
		$count = $logs->yxx1count();
		$this->assign('count',$count);
		
		$res2 = $logs->yxx2($num);
		$this->assign('list1',$res2['list']);
		$this->assign('page1',$res2['page']);
		
		$count2 = $logs->yxx2count();
		$this->assign('count1',$count2);
		
        return $this->fetch();
    }
	
	
}
