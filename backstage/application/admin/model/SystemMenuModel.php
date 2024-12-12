<?php

namespace app\admin\model;

use think\Model;
use think\Db;

class SystemMenuModel extends Model
{
    protected $table = 'system_menu';

    /**
     * 菜单列表
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public function getMenuList($where, $limit = 30)
    {
        $list = Db::table('ym_manage.system_menu')
            ->where('deleted_at', 0)
            ->where($where)
            ->order('sort desc')
            ->paginate($limit)
            ->toArray();
        return $list;
    }

    /**
     * 菜单详情
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public static function getMenuInfo($where)
    {
        $list = Db::table('ym_manage.system_menu')
            ->where($where)
            ->find();
        return $list;
    }

    /**
     * 添加菜单
     * @param $data
     * @return int|string
     */
    public static function addMenuInfo($data)
    {
        return Db::table('ym_manage.system_menu')->insertGetId($data);
    }

    /**
     * 更新菜单
     * @param $id
     * @return int|string
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public static function updateMenu($data)
    {
        $id = isset($data['id']) ? $data['id'] : 0;
        unset($data['id']);
        return Db::table('ym_manage.system_menu')->where('id', $id)->update($data);
    }
	
}