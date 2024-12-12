<?php

namespace app\admin\model;

use think\Model;
use think\Db;

class SystemAuthModel extends Model
{
    protected $table = 'system_auth';

    /**
     * 权限列表
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public function getAuthList($where, $limit = 30)
    {
        $list = Db::table('ym_manage.system_auth')
            ->where($where)
            ->order('sort desc')
            ->paginate($limit)
            ->toArray();
        return $list;
    }

    /**
     * 权限详情
     * @param $where
     * @param $limit
     * @return array
     * @throws \think\exception\DbException
     */
    public static function getAuthInfo($where)
    {
        $list = Db::table('ym_manage.system_auth')
            ->where($where)
            ->find();
        return $list;
    }

    /**
     * 添加权限
     * @param $data
     * @return int|string
     */
    public static function addAuthInfo($data)
    {
        return Db::table('ym_manage.system_auth')->insertGetId($data);
    }

    /**
     * 更新权限
     * @param $id
     * @return int|string
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public static function updateAuth($data)
    {
        $id = isset($data['id']) ? $data['id'] : 0;
        unset($data['id']);
        return Db::table('ym_manage.system_auth')->where('id', $id)->update($data);
    }

    /**
     * 添加访问权限
     * @param $data
     * @param int $role
     * @return bool
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public static function updateAuthNodes($data, $role = 0)
    {
        $res = Db::table('ym_manage.system_auth_node')->where('auth', $role)->delete();
        if ($res === false) {
            return false;
        }
        $res = Db::table('ym_manage.system_auth_node')->insertAll($data);
        if ($res === false) {
            return false;
        }
        return true;
    }

    /**
     * 访问权限数据
     * @param int $roleId
     * @return array|\PDOStatement|string|\think\Collection|\think\model\Collection
     * @throws \think\db\exception\DataNotFoundException
     * @throws \think\db\exception\ModelNotFoundException
     * @throws \think\exception\DbException
     */
    public static function getAuthNodeList($roleId = 0)
    {
        $list = Db::table('ym_manage.system_auth_node')
            ->where('auth', $roleId)
            ->select();
        return array_column($list, 'node');
    }
	
}