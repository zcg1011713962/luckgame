<?php
namespace app\admin\controller;
use think\Controller;
use think\facade\Request;
use app\admin\controller\Parents;
use app\admin\model\NewsModel;
use app\admin\model\ConfigModel;

class News extends Parents
{

	public function category()
	{
		$game = new NewsModel;
		
		$list = $game->getcategoryList();
		$this->assign('list',$list);
		
		$count = $game->getcategoryCount();
		$this->assign('count',$count);
	
	    return $this->fetch();
	}
	public function addcategory()
	{
	    return $this->fetch('addcategory');
	}
	
	public function doAddcategory(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['gonggao'])){ die('分类名称不能为空'); }
		
		$user = new NewsModel;
		$res = $user->doAddcategory($data);
		if($res){
			echo 'success';
		}else{
			echo '新增分类失败';
		}		
	}
	public function editcategory()
	{
		$id = Request::param('id');		
		if(empty($id)){ die('参数有误'); }
		
		$user = new NewsModel;
		$info = $user->getcategoryInfo($id);
		$this->assign('info',$info);
		
	    return $this->fetch('editcategory');
	}
	public function doEditcategory(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['gonggao'])){ die('分类名称不能为空'); }
		if(empty($data['ggid'])){ die('分类ID有误'); }
		
		$user = new NewsModel;
		$res = $user->doEditcategory($data);
		if($res){
			echo 'success';
		}else{
			echo '分类修改失败';
		}		
	}
	
	public function docategoryDel(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new NewsModel;
		$res = $user->docategoryDel($data);
		if($res){
			echo 'success';
		}else{
			echo '分类删除失败';
		}		
	}
    
	public function lists()
	{
		$game = new NewsModel;
		
		$list = $game->getGongGaoList();
		$this->assign('list',$list);
		
		$count = $game->getGongGaoCount();
		$this->assign('count',$count);
	
	    return $this->fetch('gonggao');
	}
	public function addGongGao()
	{
		$game = new NewsModel;
		$category = $game->getcategoryList();
		$this->assign('category',$category);

	    return $this->fetch('addgonggao');
	}
	
	public function doAddGongGao(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['cid'])){ die('请选择分类'); }
		if(empty($data['title'])){ die('标题不能为空'); }
		if(empty($data['content'])){ die('内容不能为空'); }
		
		$user = new NewsModel;
		$res = $user->doAddGongGao($data);
		if($res){
			echo 'success';
		}else{
			echo '新增文章失败';
		}		
	}
	public function editGongGao()
	{
		$id = Request::param('id');		
		if(empty($id)){ die('参数有误'); }
		
		$user = new NewsModel;
		$info = $user->getGongGaoInfo($id);
		$this->assign('info',$info);

		$category = $user->getcategoryList();
		$this->assign('category',$category);
		
	    return $this->fetch('editgonggao');
	}
	public function doEditGongGao(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		
		if(empty($data['cid'])){ die('请选择分类'); }
		if(empty($data['title'])){ die('标题不能为空'); }
		if(empty($data['content'])){ die('内容不能为空'); }
		if(empty($data['ggid'])){ die('文章ID有误'); }
		
		$user = new NewsModel;
		$res = $user->doEditGongGao($data);
		if($res){
			echo 'success';
		}else{
			echo '文章修改失败';
		}		
	}
	
	public function doGongGaoDel(){
		$data = request()->post();
		if(empty($data)){ die('参数有误'); }
		if(empty($data['id'])){ die('参数有误'); }
		
		$user = new NewsModel;
		$res = $user->doGongGaoDel($data);
		if($res){
			echo 'success';
		}else{
			echo '文章删除失败';
		}		
	}
		
}
