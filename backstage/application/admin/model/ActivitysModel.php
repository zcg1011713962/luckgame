<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use think\facade\Cookie;
use think\facade\Config;

class ActivitysModel extends Model
{
    public static $tableName = 'activitys';
    protected $table = 'activitys';

    public function getList($num = 10){
        $where = [];
        $title = isset($_POST['title']) ? $_POST['title'] : '';
        if ($title) {
            $where['title'] = ['like' , '%' . $title . '%'];
        }
        $list = Db::table('ym_manage.' . self::$tableName)->where($where)->paginate($num);
        $page = $list->render();
        return array(
            'list' => $list,
            'page' => $page
        );
    }

    public function getCount(){
        return Db::table('ym_manage.' . self::$tableName)->count();
    }

    public function addAll($datas){
        Db::name('ym_manage.' . self::$tableName)->insertAll($datas);
        Db::table('ym_manage.' . self::$tableName)->where('id',$data['id'])->delete();
        $this->query("set autocommit=1");
        return true;
    }

    public function doDel($data){
        if(empty($data)){ return false; }
        if(empty($data['id'])){ return false; }

        Db::table('ym_manage.' . self::$tableName)->where('id',$data['id'])->delete();
        $this->query("set autocommit=1");
        return true;
    }
}
