<?php
namespace app\admin\controller;
use think\facade\Request;
use think\facade\Cache;
use think\facade\Cookie;
use app\admin\controller\Parents;
use app\admin\model\OperateSettingModel;

class OperateSetting extends Parents {

    public function black_list() {
        return $this->fetch();
    }

    public function getBlackList() {
        $params = request()->param();
        $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $operateSettingModel = new OperateSettingModel;
        $result = $operateSettingModel->getBlackList($limit);
        return ['code' => 0, 'data' => $result['data'], 'count' => count($result['data']), 'msg' => 'ok'];
    }

    public function add_black() {
        return $this->fetch();
    }

    public function save_black() {
        $params = request()->post();
        $params['admin_id'] = Cookie::get('admin_user_id');
        $params['create_at'] = date('Y-m-d H:i:s');
        unset($params['agent_id']);
        $operateSettingModel = new OperateSettingModel;
        if ($operateSettingModel->saveBlack($params)) {
            return $this->_success();
        }
        return $this->_error('保存失败');
    }

    public function edit_black() {
        $id = request()->param('id');
        $operateSettingModel = new OperateSettingModel;
        $this->assign('data', $operateSettingModel->getBlackList(0,$id));
        return $this->fetch();
    }

    public function delete_black() {
        $id = request()->post('id');
        $operateSettingModel = new OperateSettingModel;
        if ($operateSettingModel->deleteBlack($id)) {
            return $this->_success();
        }
        return $this->_error('删除失败');
    }

    public function led_banner() {
        return $this->fetch();
    }

    public function getLedBanner() {
        $params = request()->param();
        $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $operateSettingModel = new OperateSettingModel;
        $result = $operateSettingModel->getLedBanner($limit);
        return ['code' => 0, 'data' => $result['data'], 'count' => count($result['data']), 'msg' => 'ok'];
    }

    public function add_led() {
        return $this->fetch();
    }

    public function save_led() {
        $params = request()->post();
        $time = time();
        $params['createtime'] = $time;
        $params['updatetime'] = $time;
        $params['begin_time'] = strtotime($params['begin_time']);
        $params['end_time']   = strtotime($params['end_time']);
        unset($params['agent_id']);
        $operateSettingModel = new OperateSettingModel;
        if ($operateSettingModel->saveLed($params)) {
            return $this->_success();
        }
        return $this->_error('保存失败');
    }

    public function edit_led() {
        $id = request()->param('id');
        $operateSettingModel = new OperateSettingModel;
        $this->assign('data', $operateSettingModel->getLedBanner(0,$id));
        return $this->fetch();
    }

    public function delete_led() {
        $id = request()->post('id');
        $status = request()->post('status');
        $operateSettingModel = new OperateSettingModel;
        if ($operateSettingModel->deleteLed($id, $status)) {
            return $this->_success();
        }
        return $this->_error('删除失败');
    }

    public function banner() {
        return $this->fetch();
    }

    public function getBanner() {
        $params = request()->param();
        $limit =  isset($params['limit']) && !empty($params['limit']) ? intval($params['limit']) : 30;
        $operateSettingModel = new OperateSettingModel;
        $result = $operateSettingModel->getBanner($limit);
        return ['code' => 0, 'data' => $result['data'], 'count' => count($result['data']), 'msg' => 'ok'];
    }

    public function add_banner() {
        return $this->fetch();
    }

    public function save_banner() {
        $params = request()->post();
        if (isset($params['id'])) {
            if (!empty(request()->file('banner'))) {
                $file = request()->file('banner');
                $image = $file->validate(['ext'=>'jpg,png,gif'])->move( './uploads');
                if (!$image) {return $this->_error('上传图片失败');}
                $params['image'] = '/uploads/'.str_replace("\\","/",$image->getSaveName());
            } else {
                unset($params['banner']);
            }
        } else {
            $file = request()->file('banner');
            $image = $file->validate(['ext'=>'jpg,png,gif'])->move( './uploads');
            if (!$image) {return $this->_error('上传图片失败');}
            $params['image'] = '/uploads/'.str_replace("\\","/",$image->getSaveName());
        }
        
        $operateSettingModel = new OperateSettingModel;
        if ($operateSettingModel->saveBanner($params)) {
            return $this->_success();
        }
        return $this->_error('保存失败');
    }

    public function delete_banner() {
        $id = request()->post('id');
        $status = request()->post('status');
        $operateSettingModel = new OperateSettingModel;
        if ($operateSettingModel->deleteBanner($id, $status)) {
            return $this->_success();
        }
        return $this->_error('删除失败');
    }

    public function edit_banner() {
        $id = request()->param('id');
        $operateSettingModel = new OperateSettingModel;
        $this->assign('data', $operateSettingModel->getBanner(0,$id));
        return $this->fetch();
    }
}