<?php
namespace app\admin\controller;
use think\Controller;
use app\admin\controller\Parents;
use app\admin\model\CdkeyModel;

class Cdkey extends Parents
{
    public function lists()
    {
		$model = new CdkeyModel();
		$num = 100;
		$res = $model->getList($num);
		$list = $res['list']->toArray();
		$list = $list['data'];
		$statusColor = ['red' , 'gren'];
		$statusTips = ['未使用' , '已使用'];
		foreach ($list as $key => &$value) {
			$value['status'] = $value['status'] ? $value['status'] : 0;
			$value['color'] = $statusColor[$value['status']];
			$value['status'] = $statusTips[$value['status']];
			$value['use_time'] > 0 && $value['use_time'] = date('Y-m-d H:i:s' , $value['use_time']);
		}
		$this->assign('list',$list);
		$this->assign('page',$res['page']);
		
		$count = $model->getCount();
		$this->assign('count',$count);
		$useCount = $model->getUseCount();
		$this->assign('useCount',$useCount ? $useCount : 0);
		$this->assign('notCount' , $count == 0 ? 0 : $count - $useCount);
	
        return $this->fetch();
    }
		
	public function add()
	{
	    return $this->fetch();
	}

	public function doPut(){
		$model = new CdkeyModel();
		$arrays = [];
		for ($i = 0 ; $i < 100 ; $i ++){
			$arrays[] = [
				'number' => $this->makeCardPassword() , 
				'status' => 0 , 
			];
		}
		$model->addAll($arrays);
		echo 'success';
	}

	public function doExcel(){
		//1.从数据库中取出数据
        $list = \Think\Db::name('ym_manage.cdkey')->select();
        $statusTips = ['未使用' , '已使用'];
		foreach ($list as $key => &$value) {
			$value['status'] = $value['status'] ? $value['status'] : 0;
			$value['status'] = $statusTips[$value['status']];
			$value['use_time'] > 0 && $value['use_time'] = date('Y-m-d H:i:s' , $value['use_time']);
		}
        //2.加载PHPExcle类库
        $str = substr(dirname(__FILE__), 0 , -28);
        require $str . 'vendor/PHPExcel/PHPExcel.php';
        //3.实例化PHPExcel类
        $objPHPExcel = new \PHPExcel();
        //4.激活当前的sheet表
        $objPHPExcel->setActiveSheetIndex(0);
        //5.设置表格头（即excel表格的第一行）
        $objPHPExcel->setActiveSheetIndex(0)
                ->setCellValue('A1', 'ID')                      
                ->setCellValue('B1', '点卡')
                ->setCellValue('C1', '使用状态')
                ->setCellValue('D1', '使用ID')
                ->setCellValue('E1', '使用时间');
        //设置F列水平居中
        $objPHPExcel->setActiveSheetIndex(0)->getStyle('E')->getAlignment()
                    ->setHorizontal(\PHPExcel_Style_Alignment::HORIZONTAL_CENTER);
        //设置单元格宽度
        $objPHPExcel->setActiveSheetIndex(0)->getColumnDimension('B')->setWidth(30);
        $objPHPExcel->setActiveSheetIndex(0)->getColumnDimension('E')->setWidth(30); 
        //6.循环刚取出来的数组，将数据逐一添加到excel表格。
        for($i=0;$i<count($list);$i++){
            $objPHPExcel->getActiveSheet()->setCellValue('A'.($i+2),$list[$i]['id']);
            $objPHPExcel->getActiveSheet()->setCellValue('B'.($i+2),$list[$i]['number']);
            $objPHPExcel->getActiveSheet()->setCellValue('C'.($i+2),$list[$i]['status']);
            $objPHPExcel->getActiveSheet()->setCellValue('D'.($i+2),$list[$i]['use_id']);
            $objPHPExcel->getActiveSheet()->setCellValue('E'.($i+2),$list[$i]['use_time']);
        }
        //7.设置保存的Excel表格名称
        $filename = '点卡信息'.date('Ymd',time()) . time().'.xls';
        //8.设置当前激活的sheet表格名称；
        $objPHPExcel->getActiveSheet()->setTitle('点卡信息');
        //9.设置浏览器窗口下载表格
        header("Content-Type: application/force-download");  
        header("Content-Type: application/octet-stream");  
        header("Content-Type: application/download");  
        header('Content-Disposition:inline;filename="'.$filename.'"');  
        //生成excel文件
        $objWriter = \PHPExcel_IOFactory::createWriter($objPHPExcel, 'Excel5');
        //下载文件在浏览器窗口
        $objWriter->save('php://output');
        exit;
	}

	//随机生成不重复的8位卡密
	protected function makeCardPassword()
	{
		$code = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
		$rand = $code[rand(0, 25)]
			. strtoupper(dechex(date('m')))
			. date('d') . substr(time(), -5)
			. substr(microtime(), 2, 5)
			. sprintf('%02d', rand(0, 99));
		for (
			$a = md5($rand),
			$s = '0123456789ABCDEFGHIJKLMNOPQRSTUV',
			$d = '',
			$f = 0;
			$f < 17;
			$g = ord($a[$f]),
			$d .= $s[($g ^ ord($a[$f + 8])) - $g & 0x1F],
			$f++
		) ;
		return $d;
	}
	
	public function doDel(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new CdkeyModel();
		$res = $user->doDel($data);
		if($res){
			echo 'success';
		}else{
			echo '编辑管理员失败';
		}		
	}
	
}
