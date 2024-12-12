<?php
namespace app\admin\controller;
use think\Db;
use think\Controller;
use app\admin\controller\Parents;
use think\facade\Config;
use app\admin\model\GameModel;
use think\facade\Request;
use app\admin\model\ConfigModel;

class SystemConfig extends Parents {
    public function base() {
        $config = ConfigModel::getSystemConfig();
        $this->assign('config',$config);
        return $this->fetch();
    }
    public function saveconfig() {
        $params = request()->post();
        ConfigModel::setSystemConfig($params);
        return $this->_success('','保存成功。');
    }

    public function icon() {
        $iconList = json_decode(ConfigModel::getIcon(),true);
        $this->assign('iconList',$iconList);
        return $this->fetch();
    }

    public function saveicon() {
        $actName = request()->get('act');
        $file = request()->file('image');
        $info = $file->validate(['ext'=>'png'])->move( './uploads');
        if ($info) {
            $url = request()->domain().'/uploads/';
            $saveName = str_replace("\\","/",$info->getSaveName());
            // 保存icon图片
            ConfigModel::saveIcon($actName,$url.$saveName);
            return $this->_success(['url' => $url.$saveName]);
        }
        return $this->_error($file->getError());
    }

    public function addEmail() {
        return $this->fetch();
    }

    public function payScaleSetup() {
        $payScale = ConfigModel::getPayScale();
        $this->assign('payScale',$payScale);
        //$taxationScale = configModel::getGameConfig('taxation');
        //$this->assign('taxationScale',$taxationScale);
        return $this->fetch();
    }

    public function savePayConfig() {
        $params = request()->post();
        ConfigModel::setPayConfig($params);
        return $this->_success('','保存成功。');
    }

    /**
     * 充值赠送配置
     * @return void
     */
    public function rechargeGift()
    {
        return $this->fetch();
    }

    public function getRechargeGift()
    {
        $params = $this->request->get();
        $where = [];
        if (!empty($params['type'])) {
            $where[] = ['type', '=', $params['type']];
        }
        $result = ConfigModel::getRechargeGiftList($where);
        return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    /**
     * 添加充值赠送
     * @return mixed
     */
    public function addRechargeGift()
    {
        if ($this->request->isGet()) {
            return $this->fetch();
        } else {

            $post = $this->request->post();
            $type = isset($post['type']) ? $post['type'] : '';
            $rechargeMoney = isset($post['recharge_money']) ? $post['recharge_money'] : '';
            $giftMoney = isset($post['gift_money']) ? $post['gift_money'] : '';
            if (empty($type)) {
                return $this->_error('类型不能为空');
            }
            if (empty($rechargeMoney)) {
                return $this->_error('充值金额不能为空');
            }
            if (empty($giftMoney)) {
                return $this->_error('赠送金额不能为空');
            }

            $res = ConfigModel::saveRechargeGift([
                'type' => $type,
                'recharge_money' => $rechargeMoney,
                'gift_money' => $giftMoney,
                'create_at' => date('Y-m-d H:i:s')
            ]);
            if ($res === false) {
                return $this->_error('添加失败');
            }
            return $this->_success([],'添加成功');
        }
    }

    /**
     * 删除充值赠送
     * @return array
     */
    public function delRechargeGift()
    {
        $id = $this->request->post('id');
        if (empty($id)) {
            return $this->_error('参数为空');
        }
        $res = ConfigModel::delRechargeGift($id);
        if ($res === false) {
            return $this->_error('删除失败');
        }
        return $this->_success([],'删除成功');
    }

    /**
     * 充值宝箱配置
     * @return void
     */
    public function rechargeBox()
    {
        return $this->fetch();
    }

    public function getRechargeBox()
    {
        $params = $this->request->get();
        $where = [];
        $result = ConfigModel::getRechargeBoxList($where);
        return ['code' => 0, 'count' => $result['total'], 'data' => $result['data'], 'msg' => 'ok'];
    }

    /**
     * 添加充值宝箱
     * @return mixed
     */
    public function addRechargeBox()
    {
        if ($this->request->isGet()) {
            return $this->fetch();
        } else {

            $post = $this->request->post();
            $rechargeMoney = isset($post['recharge_money']) ? $post['recharge_money'] : '';
            $giftMoney = isset($post['box_money']) ? $post['box_money'] : '';
            if (empty($rechargeMoney)) {
                return $this->_error('累计充值金额不能为空');
            }
            if (empty($giftMoney)) {
                return $this->_error('宝箱面额不能为空');
            }

            $res = ConfigModel::saveRechargeBox([
                'recharge_money' => $rechargeMoney,
                'box_money' => $giftMoney,
                'create_at' => date('Y-m-d H:i:s')
            ]);
            if ($res === false) {
                return $this->_error('添加失败');
            }
            return $this->_success([],'添加成功');
        }
    }

    /**
     * 删除充值宝箱
     * @return array
     */
    public function delRechargeBox()
    {
        $id = $this->request->post('id');
        if (empty($id)) {
            return $this->_error('参数为空');
        }
        $res = ConfigModel::delRechargeBox($id);
        if ($res === false) {
            return $this->_error('删除失败');
        }
        return $this->_success([],'删除成功');
    }

    /**
     * 设置提现流水限制
     * @return array|mixed
     */
    public function withdrawalLimit()
    {
        $ConfigModel = new ConfigModel();
        if ($this->request->isGet()) {

            $info = $ConfigModel->getConfig('WITHDRAWALFLOWLIMIT');
            $info = $info['value'] ? json_decode($info['value'], true) : [];
            $this->assign('info', $info);

            return $this->fetch();
        } else {

            $recharge = $this->request->post('recharge');
            if (empty($recharge) || $recharge < 1) {
                return $this->_error('充值流水倍数不能为空且不能低于1');
            }
            $give = $this->request->post('give');
            if (empty($give) || $give < 1) {
                return $this->_error('赠送流水倍数不能为空且不能低于1');
            }
            $value = [
                'recharge' => $recharge,
                'give' => $give,
            ];
            $value = json_encode($value);
            $res = $ConfigModel->setConfig('WITHDRAWALFLOWLIMIT', $value);
            if ($res === false) {
                return $this->_error('设置失败');
            }
            return $this->_success([], '设置成功');

        }
    }

}
