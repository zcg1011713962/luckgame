<?php

namespace app\admin\controller;

use app\admin\model\SystemAuthModel;
use app\admin\model\SystemMenuModel;
use app\admin\utils\DataExtend;
use think\Db;

/**
 * 菜单管理
 * Class Menu
 * @package app\admin\controller
 */
class Menu extends Parents
{

    public function index()
    {

        return $this->fetch('list');
    }

    /**
     * 菜单列表
     */
    public function getMenuList()
    {
        $menuModel = new SystemMenuModel();
        $where = [];
        $menuList = $menuModel->getMenuList($where);

        $menuList['data'] = DataExtend::arr2table($menuList['data']);

        return ['code' => 0, 'count' => $menuList['total'], 'data' => $menuList['data'], 'msg' => 'ok'];
    }

    /**
     * 添加菜单
     * @return mixed
     */
    public function addMenu()
    {
        if ($this->request->isGet()) {
            $parentMenu = SystemMenuModel::where('pid', 0)->field('id, title')->select();
            $this->assign('parentMenu', $parentMenu);
            return $this->fetch('menu_form');
        } else {

            $this->_form_filter();
        }
    }

    /**
     * 添加菜单
     * @return mixed
     */
    public function editMenu()
    {
        if ($this->request->isGet()) {

            $parentMenu = SystemMenuModel::where('pid', 0)->field('id, title')->select();
            $this->assign('parentMenu', $parentMenu);

            $id = $this->request->get('id');
            $info = SystemMenuModel::getMenuInfo(['id' => $id]);
            $this->assign('info', $info);
            return $this->fetch('menu_form');
        } else {

            $this->_form_filter();
        }
    }

    /**
     * 数据处理
     * @return array
     */
    public function _form_filter()
    {
        $post = $this->request->post();

        $pid = isset($post['pid']) ? $post['pid'] : 0;
        $title = isset($post['title']) ? $post['title'] : '';
        $icon = isset($post['icon']) ? $post['icon'] : '';
        $node = isset($post['node']) ? $post['node'] : '';
        $url = isset($post['url']) ? $post['url'] : '';
        $type = isset($post['type']) ? $post['type'] : 1;
        $status = isset($post['status']) ? $post['status'] : 1;
        $params = isset($post['params']) ? $post['params'] : '';
        if (empty($title)) {
            return $this->_error('菜单名称不能为空');
        }
        if (empty($url)) {
            return $this->_error('链接节点不能为空');
        }
//        if (empty($node)) {
//            return $this->_error('节点代码不能为空');
//        }

        $data = [
            'pid' => $pid,
            'title' => $title,
            'icon' => $icon,
            'node' => $node,
            'url' => $url,
            'type' => $type,
            'status' => $status,
            'params' => $params,
            'create_at' => date('Y-m-d H:i:s')
        ];
        if (!empty($post['id'])) {
            $data['id'] = $post['id'];
            $res = SystemMenuModel::updateMenu($data);
        } else {
            $res = SystemMenuModel::addMenuInfo($data);
        }

        if ($res === false) {
            $this->error('编辑失败');
        }
        $this->success('编辑成功');
    }

    /**
     * 更新状态
     * @return void
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public function menuState()
    {
        $post = $this->request->post();
        $res = SystemMenuModel::updateMenu($post);

        if ($res === false) {
            $this->error('更新失败');
        }
        $this->success('成功');
    }

    /**
     * 删除菜单
     * @return void
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public function delMenu()
    {
        $id = $this->request->param('id');
        $data = [
            'id' => $id,
            'deleted_at' => time()
        ];
        $res = SystemMenuModel::updateMenu($data);

        if ($res === false) {
            $this->error('删除失败');
        }
        $this->success('删除成功');
    }

    /**
     * 权限列表
     */
    public function authList()
    {

        return $this->fetch('auth_list');
    }

    /**
     * 权限列表
     */
    public function getAuthList()
    {
        $menuModel = new SystemAuthModel();
        $where = [];
        $menuList = $menuModel->getAuthList($where);

        return ['code' => 0, 'count' => $menuList['total'], 'data' => $menuList['data'], 'msg' => 'ok'];
    }

    /**
     * 添加菜单
     * @return mixed
     */
    public function addAuth()
    {
        if ($this->request->isGet()) {

            return $this->fetch('auth_form');
        } else {

            $this->_auth_form_filter();
        }
    }

    /**
     * 添加菜单
     * @return mixed
     */
    public function editAuth()
    {
        if ($this->request->isGet()) {

            $id = $this->request->get('id');
            $info = SystemAuthModel::getAuthInfo(['id' => $id]);
            $this->assign('info', $info);
            return $this->fetch('auth_form');
        } else {

            $this->_auth_form_filter();
        }
    }

    /**
     * 数据处理
     * @return array
     */
    public function _auth_form_filter()
    {
        $post = $this->request->post();

        $title = isset($post['title']) ? $post['title'] : '';
        $params = isset($post['desc']) ? $post['desc'] : '';
        if (empty($title)) {
            return $this->_error('权限名称不能为空');
        }

        $data = [

            'title' => $title,
            'desc' => $params,
            'create_at' => date('Y-m-d H:i:s')
        ];
        if (!empty($post['id'])) {
            $data['id'] = $post['id'];
            $res = SystemAuthModel::updateAuth($data);
        } else {
            $res = SystemAuthModel::addAuthInfo($data);
        }

        if ($res === false) {
            $this->error('编辑失败');
        }
        $this->success('编辑成功');
    }

    /**
     * 更新状态
     * @return void
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public function authState()
    {
        $post = $this->request->post();
        $res = SystemAuthModel::updateAuth($post);

        if ($res === false) {
            $this->error('更新失败');
        }
        $this->success('成功');
    }

    /**
     * 删除菜单
     * @return void
     * @throws \think\Exception
     * @throws \think\exception\PDOException
     */
    public function delAuth()
    {
        $id = $this->request->param('id');
        $data = [
            'id' => $id,
            'deleted_at' => time()
        ];
        $res = SystemAuthModel::updateAuth($data);

        if ($res === false) {
            $this->error('删除失败');
        }
        $this->success('删除成功');
    }

    /**
     * 授权
     * @return mixed
     */
    public function authApply()
    {
        if ($this->request->isGet()) {

            $action = input('action');
            if ($action == 'ajax') {

                $roleId = input('id', 0);
                $where = [
                    'status' => 1
                ];
                $menuList = Db::table('ym_manage.system_menu')
                    ->where('deleted_at', 0)
                    ->where($where)
                    ->field('id, pid, title, node, type')
                    ->order('sort desc')
                    ->select();

                $authNodes = SystemAuthModel::getAuthNodeList($roleId);

                $pnodeArr = array_column($menuList, 'node', 'id');
                foreach ($menuList as $k => $v) {
                    $menuList[$k]['pnode'] = $v['pid'] == 0 ? '' : $pnodeArr[$v['pid']];
                    $menuList[$k]['checked'] = in_array($v['node'], $authNodes) ? true : false;
                }

                $menuList = DataExtend::arr2tree($menuList, 'id', 'pid', '_sub_');
//                print_r($menuList);exit;
                $data = $menuList;
//                $data = array (
//                    0 =>
//                        array (
//                            'node' => 'admin',
//                            'title' => 'Admin',
//                            'pnode' => '',
//                            'checked' => false,
//                            '_sub_' =>
//                                array (
//                                    0 =>
//                                        array (
//                                            'node' => 'admin/auth',
//                                            'title' => '系统权限管理',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/auth/index',
//                                                            'title' => '系统权限管理',
//                                                            'pnode' => 'admin/auth',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/auth/add',
//                                                            'title' => '添加系统权限',
//                                                            'pnode' => 'admin/auth',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/auth/edit',
//                                                            'title' => '编辑系统权限',
//                                                            'pnode' => 'admin/auth',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'admin/auth/state',
//                                                            'title' => '修改权限状态',
//                                                            'pnode' => 'admin/auth',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'admin/auth/remove',
//                                                            'title' => '删除系统权限',
//                                                            'pnode' => 'admin/auth',
//                                                            'checked' => false,
//                                                        ),
//                                                    5 =>
//                                                        array (
//                                                            'node' => 'admin/auth/apply',
//                                                            'title' => '权限配置节点',
//                                                            'pnode' => 'admin/auth',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    1 =>
//                                        array (
//                                            'node' => 'admin/base',
//                                            'title' => '数据字典管理',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/base/index',
//                                                            'title' => '数据字典管理',
//                                                            'pnode' => 'admin/base',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/base/add',
//                                                            'title' => '添加数据字典',
//                                                            'pnode' => 'admin/base',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/base/edit',
//                                                            'title' => '编辑数据字典',
//                                                            'pnode' => 'admin/base',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'admin/base/state',
//                                                            'title' => '修改数据状态',
//                                                            'pnode' => 'admin/base',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'admin/base/remove',
//                                                            'title' => '删除数据记录',
//                                                            'pnode' => 'admin/base',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    2 =>
//                                        array (
//                                            'node' => 'admin/config',
//                                            'title' => '系统参数配置',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/config/index',
//                                                            'title' => '系统参数配置',
//                                                            'pnode' => 'admin/config',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/config/system',
//                                                            'title' => '修改系统参数',
//                                                            'pnode' => 'admin/config',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/config/storage',
//                                                            'title' => '修改文件存储',
//                                                            'pnode' => 'admin/config',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    3 =>
//                                        array (
//                                            'node' => 'admin/file',
//                                            'title' => '系统文件管理',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/file/index',
//                                                            'title' => '系统文件管理',
//                                                            'pnode' => 'admin/file',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/file/edit',
//                                                            'title' => '编辑系统文件',
//                                                            'pnode' => 'admin/file',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/file/remove',
//                                                            'title' => '删除系统文件',
//                                                            'pnode' => 'admin/file',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'admin/file/distinct',
//                                                            'title' => '清理重复文件',
//                                                            'pnode' => 'admin/file',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    4 =>
//                                        array (
//                                            'node' => 'admin/menu',
//                                            'title' => '系统菜单管理',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/menu/index',
//                                                            'title' => '系统菜单管理',
//                                                            'pnode' => 'admin/menu',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/menu/add',
//                                                            'title' => '添加系统菜单',
//                                                            'pnode' => 'admin/menu',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/menu/edit',
//                                                            'title' => '编辑系统菜单',
//                                                            'pnode' => 'admin/menu',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'admin/menu/state',
//                                                            'title' => '修改菜单状态',
//                                                            'pnode' => 'admin/menu',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'admin/menu/remove',
//                                                            'title' => '删除系统菜单',
//                                                            'pnode' => 'admin/menu',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    5 =>
//                                        array (
//                                            'node' => 'admin/oplog',
//                                            'title' => '系统日志管理',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/oplog/index',
//                                                            'title' => '系统日志管理',
//                                                            'pnode' => 'admin/oplog',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/oplog/clear',
//                                                            'title' => '清理系统日志',
//                                                            'pnode' => 'admin/oplog',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/oplog/remove',
//                                                            'title' => '删除系统日志',
//                                                            'pnode' => 'admin/oplog',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    6 =>
//                                        array (
//                                            'node' => 'admin/queue',
//                                            'title' => '系统任务管理',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/queue/index',
//                                                            'title' => '系统任务管理',
//                                                            'pnode' => 'admin/queue',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/queue/redo',
//                                                            'title' => '重启系统任务',
//                                                            'pnode' => 'admin/queue',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/queue/clean',
//                                                            'title' => '清理运行数据',
//                                                            'pnode' => 'admin/queue',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'admin/queue/remove',
//                                                            'title' => '删除系统任务',
//                                                            'pnode' => 'admin/queue',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    7 =>
//                                        array (
//                                            'node' => 'admin/user',
//                                            'title' => '系统用户管理',
//                                            'pnode' => 'admin',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'admin/user/index',
//                                                            'title' => '系统用户管理',
//                                                            'pnode' => 'admin/user',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'admin/user/add',
//                                                            'title' => '添加系统用户',
//                                                            'pnode' => 'admin/user',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'admin/user/edit',
//                                                            'title' => '编辑系统用户',
//                                                            'pnode' => 'admin/user',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'admin/user/pass',
//                                                            'title' => '修改用户密码',
//                                                            'pnode' => 'admin/user',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'admin/user/state',
//                                                            'title' => '修改用户状态',
//                                                            'pnode' => 'admin/user',
//                                                            'checked' => false,
//                                                        ),
//                                                    5 =>
//                                                        array (
//                                                            'node' => 'admin/user/remove',
//                                                            'title' => '删除系统用户',
//                                                            'pnode' => 'admin/user',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                ),
//                        ),
//                    1 =>
//                        array (
//                            'node' => 'manage',
//                            'title' => 'Manage',
//                            'pnode' => '',
//                            'checked' => false,
//                            '_sub_' =>
//                                array (
//                                    0 =>
//                                        array (
//                                            'node' => 'manage/article.article',
//                                            'title' => '外刊文章管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/article.article/index',
//                                                            'title' => '外刊文章管理',
//                                                            'pnode' => 'manage/article.article',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/article.article/add',
//                                                            'title' => '添加外刊文章',
//                                                            'pnode' => 'manage/article.article',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/article.article/edit',
//                                                            'title' => '编辑外刊文章',
//                                                            'pnode' => 'manage/article.article',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/article.article/state',
//                                                            'title' => '修改外刊文章状态',
//                                                            'pnode' => 'manage/article.article',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/article.article/remove',
//                                                            'title' => '删除外刊文章',
//                                                            'pnode' => 'manage/article.article',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    1 =>
//                                        array (
//                                            'node' => 'manage/article.article_category',
//                                            'title' => '外刊外刊文章分类管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_category/index',
//                                                            'title' => '外刊文章分类管理',
//                                                            'pnode' => 'manage/article.article_category',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_category/add',
//                                                            'title' => '添加外刊文章分类',
//                                                            'pnode' => 'manage/article.article_category',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_category/edit',
//                                                            'title' => '编辑外刊文章分类',
//                                                            'pnode' => 'manage/article.article_category',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_category/state',
//                                                            'title' => '修改外刊文章分类状态',
//                                                            'pnode' => 'manage/article.article_category',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_category/remove',
//                                                            'title' => '删除外刊文章分类',
//                                                            'pnode' => 'manage/article.article_category',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    2 =>
//                                        array (
//                                            'node' => 'manage/article.article_question',
//                                            'title' => '外刊测试题管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_question/index',
//                                                            'title' => '外刊测试题管理',
//                                                            'pnode' => 'manage/article.article_question',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_question/add',
//                                                            'title' => '添加外刊测试题',
//                                                            'pnode' => 'manage/article.article_question',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_question/edit',
//                                                            'title' => '编辑外刊测试题',
//                                                            'pnode' => 'manage/article.article_question',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_question/state',
//                                                            'title' => '修改外刊测试题状态',
//                                                            'pnode' => 'manage/article.article_question',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_question/remove',
//                                                            'title' => '删除外刊测试题',
//                                                            'pnode' => 'manage/article.article_question',
//                                                            'checked' => false,
//                                                        ),
//                                                    5 =>
//                                                        array (
//                                                            'node' => 'manage/article.article_question/questions',
//                                                            'title' => '添加测试题',
//                                                            'pnode' => 'manage/article.article_question',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    3 =>
//                                        array (
//                                            'node' => 'manage/base.about',
//                                            'title' => '关于我们',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/base.about/index',
//                                                            'title' => '关于我们管理',
//                                                            'pnode' => 'manage/base.about',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    4 =>
//                                        array (
//                                            'node' => 'manage/base.banner',
//                                            'title' => '轮播图管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/base.banner/index',
//                                                            'title' => '轮播图管理',
//                                                            'pnode' => 'manage/base.banner',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/base.banner/add',
//                                                            'title' => '添加轮播图',
//                                                            'pnode' => 'manage/base.banner',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/base.banner/edit',
//                                                            'title' => '编辑轮播图',
//                                                            'pnode' => 'manage/base.banner',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/base.banner/state',
//                                                            'title' => '修改轮播图状态',
//                                                            'pnode' => 'manage/base.banner',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/base.banner/remove',
//                                                            'title' => '删除轮播图',
//                                                            'pnode' => 'manage/base.banner',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    5 =>
//                                        array (
//                                            'node' => 'manage/base.broadcast',
//                                            'title' => '直播管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/base.broadcast/index',
//                                                            'title' => '直播管理',
//                                                            'pnode' => 'manage/base.broadcast',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/base.broadcast/add',
//                                                            'title' => '添加直播',
//                                                            'pnode' => 'manage/base.broadcast',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/base.broadcast/edit',
//                                                            'title' => '编辑直播',
//                                                            'pnode' => 'manage/base.broadcast',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/base.broadcast/state',
//                                                            'title' => '修改直播状态',
//                                                            'pnode' => 'manage/base.broadcast',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/base.broadcast/remove',
//                                                            'title' => '删除直播',
//                                                            'pnode' => 'manage/base.broadcast',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    6 =>
//                                        array (
//                                            'node' => 'manage/base.mottoes',
//                                            'title' => '励志格言管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/base.mottoes/index',
//                                                            'title' => '励志格言管理',
//                                                            'pnode' => 'manage/base.mottoes',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/base.mottoes/add',
//                                                            'title' => '添加励志格言',
//                                                            'pnode' => 'manage/base.mottoes',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/base.mottoes/edit',
//                                                            'title' => '编辑励志格言',
//                                                            'pnode' => 'manage/base.mottoes',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/base.mottoes/state',
//                                                            'title' => '修改励志格言状态',
//                                                            'pnode' => 'manage/base.mottoes',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/base.mottoes/remove',
//                                                            'title' => '删除励志格言',
//                                                            'pnode' => 'manage/base.mottoes',
//                                                            'checked' => false,
//                                                        ),
//                                                    5 =>
//                                                        array (
//                                                            'node' => 'manage/base.mottoes/import',
//                                                            'title' => '导入物料',
//                                                            'pnode' => 'manage/base.mottoes',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    7 =>
//                                        array (
//                                            'node' => 'manage/base.other',
//                                            'title' => '其他配置管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/base.other/index',
//                                                            'title' => '其他配置管理',
//                                                            'pnode' => 'manage/base.other',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    8 =>
//                                        array (
//                                            'node' => 'manage/base.teacher',
//                                            'title' => '员工管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/base.teacher/index',
//                                                            'title' => '员工管理',
//                                                            'pnode' => 'manage/base.teacher',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/base.teacher/add',
//                                                            'title' => '添加员工',
//                                                            'pnode' => 'manage/base.teacher',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/base.teacher/edit',
//                                                            'title' => '编辑员工',
//                                                            'pnode' => 'manage/base.teacher',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/base.teacher/state',
//                                                            'title' => '修改员工状态',
//                                                            'pnode' => 'manage/base.teacher',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/base.teacher/remove',
//                                                            'title' => '删除员工',
//                                                            'pnode' => 'manage/base.teacher',
//                                                            'checked' => false,
//                                                        ),
//                                                    5 =>
//                                                        array (
//                                                            'node' => 'manage/base.teacher/export',
//                                                            'title' => '导出员工',
//                                                            'pnode' => 'manage/base.teacher',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    9 =>
//                                        array (
//                                            'node' => 'manage/base.user',
//                                            'title' => '会员管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/base.user/index',
//                                                            'title' => '会员管理',
//                                                            'pnode' => 'manage/base.user',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/base.user/state',
//                                                            'title' => '修改会员状态',
//                                                            'pnode' => 'manage/base.user',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/base.user/remove',
//                                                            'title' => '删除会员',
//                                                            'pnode' => 'manage/base.user',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    10 =>
//                                        array (
//                                            'node' => 'manage/finance.account_log',
//                                            'title' => '员工消费管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/finance.account_log/index',
//                                                            'title' => '员工消费记录管理',
//                                                            'pnode' => 'manage/finance.account_log',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/finance.account_log/detail',
//                                                            'title' => '员工消费记录详情',
//                                                            'pnode' => 'manage/finance.account_log',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/finance.account_log/remove',
//                                                            'title' => '删除记录',
//                                                            'pnode' => 'manage/finance.account_log',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/finance.account_log/export',
//                                                            'title' => '导出消费记录',
//                                                            'pnode' => 'manage/finance.account_log',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/finance.account_log/consumelog',
//                                                            'title' => '员工消费记录',
//                                                            'pnode' => 'manage/finance.account_log',
//                                                            'checked' => false,
//                                                        ),
//                                                    5 =>
//                                                        array (
//                                                            'node' => 'manage/finance.account_log/cardrefund',
//                                                            'title' => '退款',
//                                                            'pnode' => 'manage/finance.account_log',
//                                                            'checked' => false,
//                                                        ),
//                                                    6 =>
//                                                        array (
//                                                            'node' => 'manage/finance.account_log/consumelogexport',
//                                                            'title' => '导出员工消费记录',
//                                                            'pnode' => 'manage/finance.account_log',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    11 =>
//                                        array (
//                                            'node' => 'manage/finance.wechat_pay_log',
//                                            'title' => '微信支付记录',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/finance.wechat_pay_log/index',
//                                                            'title' => '微信支付记录管理',
//                                                            'pnode' => 'manage/finance.wechat_pay_log',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/finance.wechat_pay_log/export',
//                                                            'title' => '导出消费记录',
//                                                            'pnode' => 'manage/finance.wechat_pay_log',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    12 =>
//                                        array (
//                                            'node' => 'manage/order.order',
//                                            'title' => '订单管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/order.order/index',
//                                                            'title' => '订单管理',
//                                                            'pnode' => 'manage/order.order',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/order.order/state',
//                                                            'title' => '修改订单状态',
//                                                            'pnode' => 'manage/order.order',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/order.order/remove',
//                                                            'title' => '删除订单',
//                                                            'pnode' => 'manage/order.order',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/order.order/orderprint',
//                                                            'title' => '打印厨房单',
//                                                            'pnode' => 'manage/order.order',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/order.order/export',
//                                                            'title' => '导出订单记录',
//                                                            'pnode' => 'manage/order.order',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    13 =>
//                                        array (
//                                            'node' => 'manage/subject.canteen',
//                                            'title' => '餐厅管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/subject.canteen/index',
//                                                            'title' => '餐厅管理',
//                                                            'pnode' => 'manage/subject.canteen',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/subject.canteen/add',
//                                                            'title' => '添加餐厅',
//                                                            'pnode' => 'manage/subject.canteen',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/subject.canteen/edit',
//                                                            'title' => '编辑餐厅',
//                                                            'pnode' => 'manage/subject.canteen',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/subject.canteen/state',
//                                                            'title' => '修改餐厅状态',
//                                                            'pnode' => 'manage/subject.canteen',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/subject.canteen/remove',
//                                                            'title' => '删除餐厅',
//                                                            'pnode' => 'manage/subject.canteen',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    14 =>
//                                        array (
//                                            'node' => 'manage/subject.category',
//                                            'title' => '课程类别管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/subject.category/index',
//                                                            'title' => '课程类别管理',
//                                                            'pnode' => 'manage/subject.category',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/subject.category/add',
//                                                            'title' => '添加课程类别',
//                                                            'pnode' => 'manage/subject.category',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/subject.category/edit',
//                                                            'title' => '编辑课程类别',
//                                                            'pnode' => 'manage/subject.category',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/subject.category/state',
//                                                            'title' => '修改课程类别状态',
//                                                            'pnode' => 'manage/subject.category',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/subject.category/remove',
//                                                            'title' => '删除课程类别',
//                                                            'pnode' => 'manage/subject.category',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    15 =>
//                                        array (
//                                            'node' => 'manage/subject.subject',
//                                            'title' => '课程管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject/index',
//                                                            'title' => '课程管理',
//                                                            'pnode' => 'manage/subject.subject',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject/add',
//                                                            'title' => '添加课程',
//                                                            'pnode' => 'manage/subject.subject',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject/edit',
//                                                            'title' => '编辑课程',
//                                                            'pnode' => 'manage/subject.subject',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject/state',
//                                                            'title' => '修改课程状态',
//                                                            'pnode' => 'manage/subject.subject',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject/remove',
//                                                            'title' => '删除课程',
//                                                            'pnode' => 'manage/subject.subject',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                    16 =>
//                                        array (
//                                            'node' => 'manage/subject.subject_ology',
//                                            'title' => '学科学科管理',
//                                            'pnode' => 'manage',
//                                            'checked' => false,
//                                            '_sub_' =>
//                                                array (
//                                                    0 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject_ology/index',
//                                                            'title' => '学科学科管理',
//                                                            'pnode' => 'manage/subject.subject_ology',
//                                                            'checked' => false,
//                                                        ),
//                                                    1 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject_ology/add',
//                                                            'title' => '添加学科类别',
//                                                            'pnode' => 'manage/subject.subject_ology',
//                                                            'checked' => false,
//                                                        ),
//                                                    2 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject_ology/edit',
//                                                            'title' => '编辑学科类别',
//                                                            'pnode' => 'manage/subject.subject_ology',
//                                                            'checked' => false,
//                                                        ),
//                                                    3 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject_ology/state',
//                                                            'title' => '修改学科类别状态',
//                                                            'pnode' => 'manage/subject.subject_ology',
//                                                            'checked' => false,
//                                                        ),
//                                                    4 =>
//                                                        array (
//                                                            'node' => 'manage/subject.subject_ology/remove',
//                                                            'title' => '删除学科类别',
//                                                            'pnode' => 'manage/subject.subject_ology',
//                                                            'checked' => false,
//                                                        ),
//                                                ),
//                                        ),
//                                ),
//                        ),
//                );
                $this->success('成功', '', $data);

            } else {
                $id = $this->request->get('id');
                $info = SystemAuthModel::getAuthInfo(['id' => $id]);
                $this->assign('info', $info);
                return $this->fetch();
            }

        } else {
            $post = $this->request->post();

            $roleId = isset($post['id']) ? $post['id'] : 0;
            $nodes = isset($post['nodes']) ? $post['nodes'] : [];
//            print_r($post);
//            exit();

            if (empty($roleId)) {
                $this->error('角色不能为空');
            }
            if (empty($nodes)) {
                $this->error('请选择授权菜单');
            }
            $data = [];
            if ($post['action'] == 'save') {
                foreach ($post['nodes'] as $v) {
                    $data[] = [
                        'auth' => $post['id'],
                        'node' => $v
                    ];
                }
            }

            $res = SystemAuthModel::updateAuthNodes($data, $roleId);
            if (!$res) {
                $this->error('保存失败');
            }
            $this->success('保存成功');
        }

    }

}
