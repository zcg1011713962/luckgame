<?php
namespace app\admin\controller;
use app\admin\model\ActivitysModel;
use think\Controller;
use app\admin\controller\Parents;
use app\admin\model\CdkeyModel;

class Activitys extends Parents
{
    public function lists()
    {
		$model = new ActivitysModel();
		$num = 100;
		$res = $model->getList($num);
		$list = $res['list']->toArray();
		$list = $list['data'];
		foreach ($list as $key => &$value) {
			$value['created_at'] = date('Y-m-d H:i:s' , $value['created_at']);
		}
		$this->assign('list',$list);
		$this->assign('page',$res['page']);
		
		$count = $model->getCount();
		$this->assign('count',$count);
        return $this->fetch();
    }
		
	public function add()
	{
        $id = input('id');
        $find = [];
        if ($id > 0){
            $find = ActivitysModel::where('id' , $id)->find();
            if ($find){
                $find = $find->toArray();
                $find['image'] = str_replace('\\' , '/' , $find['image']);
            }else{
                $find = [];
            }
        }
        $this->assign('find' , $find);
	    return $this->fetch();
	}

    // 上传文件
    public function upload(){
        $file = $this->request->file('file');
        $info = $file->validate(['ext'=>'jpg,png,gif'])->move('uploads');
        if ($info) {
            return json([
                'code' => 0 ,
                'msg' => '文件上传成功' ,
                'data' => [
                    'src' => '/uploads/' . str_replace('\\' , '/' , $info->getSaveName()) ,
                ]
            ]);
        }
        return json([
            'code' => 0 ,
            'msg' => '文件上传失败' ,
            'data' => []
        ]);
    }

	public function doAdd(){
		$title = input('title');
		$image = input('image');
		$content = input('content');
		$id = input('id');
        if (!$title){
            echo '请输入标题';exit();
        }
        if (!$image){
            echo '请上传图片';exit();
        }
        if (!$content){
            echo '请输入内容';exit();
        }
        $saveData = [
            'title' => $title ,
            'content' => $content ,
            'image' => $image ,
        ];
        if ($id > 0){
            ActivitysModel::where('id' , $id)->update($saveData);
        }else{
            $saveData['created_at'] = time();
            ActivitysModel::create($saveData);
        }
		echo 'success';
	}
	
	public function doDel(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new ActivitysModel();
		$res = $user->doDel($data);
		if($res){
			echo 'success';
		}else{
			echo '编辑管理员失败';
		}		
	}
	
}
