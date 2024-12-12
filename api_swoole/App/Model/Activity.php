<?php

namespace App\Model;

use App\Model\Constants\MysqlTables;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;

class Activity extends Model
{
    // 幸运红包数值
    const LUCKY_REDBAG_CONFIG   = 'lucky_redbag_config';
    // 分享次数数值
    const SHARE_NUMS_CONFIG     = 'share_nums_config';
    // 红包雨数值
    const RAINY_REDBAG_CONFIG   = 'rainy_redbag_config';
    // 成长值数值
    const GROWTH_VALUE_CONFIG   = 'growth_value_config';
    // 幸运宝箱数值
    const LUCKY_BOX_CONFIG      = 'lucky_box_config';
    // 幸运红包开关
    const LUCKY_REDBAG_SWITCH   = 'lucky_redbag_switch';
    // 成长值比例
    const GROWTH_VALUE_RATIO    = 'growth_value_ratio';
    // 成长值开关
    const GROWTH_VALUE_SWITCH   = 'growth_value_switch';

    /**
     * 根据key获取对应的活动配置
     *
     * @param string $key
     * @return string
     */
    public function getValueSettingByKey($key)
    {
        $redis = $this->redis->getDb();
        $redisKey = '{bigbang}:activity:' . $key;
        $value = $redis->get($redisKey);
        if ($value === null) {
            $db = $this->mysql->getDb();
            $rs = $db->where('skey', $key)->getOne(MysqlTables::ACT_SETTING);
            if (empty($rs)) {
                return '';
            }
            $value = $rs['svalue'];
            $redis->set($redisKey, $value);
        }
        return $value;
    }

    /**
     * 获取所有活动配置
     *
     * @return array
     */
    public function getValueSettings()
    {
        $db = $this->mysql->getDb();
        return $db->get(MysqlTables::ACT_SETTING, null, 'skey, svalue');
    }

    public function postValueSettings($key, $value)
    {
        $db = $this->mysql->getDb();
        //开启成长值开关需要判断成长值数值是否已添加
        if ($key == self::GROWTH_VALUE_SWITCH && $value == 1) {
            if (!$this->getValueSettingByKey(self::GROWTH_VALUE_CONFIG)) {
                $this->setErrCode(30001);
                $this->setErrMsg('成长值数值未设定', true);
                return false;
            }
            if (!($this->getValueSettingByKey(self::GROWTH_VALUE_RATIO) > 0)) {
                $this->setErrCode(30002);
                $this->setErrMsg('成长值比例未设定', true);
                return false;
            }
            if (!$this->getValueSettingByKey(self::LUCKY_BOX_CONFIG)) {
                $this->setErrCode(30003);
                $this->setErrMsg('幸运宝箱数值未设定', true);
                return false;
            }
        }
        if ($rs = $db->where('skey', $key)->update(MysqlTables::ACT_SETTING, ['svalue' => $value])) {
            $redis = $this->redis->getDb();
            $redis->set('{bigbang}:activity:' . $key, $value);
        }
        return $rs;
    }

    public function postRainyRedbagSetting($data)
    {
        // 判断当前是否还有其他设置正在进行中
        $time = time();
        $db = $this->mysql->getDb();
        $one = $db->where('status', 0)->where('end_time', $time, '>')->getOne(MysqlTables::ACT_RAINY_REDBAG_SETTING);
        if ($one) {
            $this->setErrCode(30001);
            $this->setErrMsg('红包雨正在进行中', true);
            return false;
        }

        // 判断活动奖池余额是否足够
        $redis = $this->redis->getDb();
        $actJackpot = $redis->get(RedisKey::ACT_JACKPOT);
        if (!$actJackpot || $actJackpot < $data['total'] * 100) {
            $this->setErrCode(30002);
            $this->setErrMsg('活动奖池余额不足', true);
            return false;
        }

        $data['create_time'] = $time;
        $data['status'] = 0;

        if ($db->insert(MysqlTables::ACT_RAINY_REDBAG_SETTING, $data)) {
            // 扣除活动奖池余额
            $this->changeActJackpot(3, -1*$data['total']*100);
            // 初始化当前红包雨奖池
            $redis->set(RedisKey::ACT_JACKPOT_RAINY_REDBAG, $data['total'] * 100);
            // 红包雨设置
            $redis->hMSet(RedisKey::ACT_RAINY_REDBAG_SETTING, ['send_time' => $data['send_time'], 'status' => 0]);
            return true;
        } else {
            return false;
        }
    }

    public function getLuckyRedbagSetting()
    {
        $db = $this->mysql->getDb();
        return $db->getOne(MysqlTables::ACT_LUCKY_REDBAG_SETTING);
    }

    public function getRainyRedbagSettings($page, $limitValue)
    {
        $db = $this->mysql->getDb();
        $offset = ($page - 1) * $limitValue;
        $db->orderBy('create_time', 'desc');
        $list = $db->withTotalCount()->get(MysqlTables::ACT_RAINY_REDBAG_SETTING, [$offset, $limitValue]);
        $result = ['list' => $list, 'total' => $db->getTotalCount()];
        return $result;
    }

    public function putRainyRedbagSettings($id)
    {
        $db = $this->mysql->getDb();
        if ($db->where('id', $id)->update(MysqlTables::ACT_RAINY_REDBAG_SETTING, ['status' => 1])) {
            $redis = $this->redis->getDb();
            $redis->hSet(RedisKey::ACT_RAINY_REDBAG_SETTING, 'status', 1);
            return true;
        } else {
            return false;
        }
    }

    public function getLuckyRedbag($accountId)
    {
        $db = $this->mysql->getDb();

        // 获取幸运红包设置
        if ($this->getValueSettingByKey(self::LUCKY_REDBAG_SWITCH) != 1) {
            $this->setErrCode(4003);
            $this->setErrMsg('幸运红包未开启', true);
            return false;
        }

        // 获取分享次数
        $date = date('Ymd');
        $share = $db->where('account_id', $accountId)->where('date', $date)->getOne(MysqlTables::ACT_SHARE_NUMS);
        $shareNums = $share ? $share['nums'] : 0;
        if ($share) {
            $db->where('account_id', $accountId)->where('date', $date)->update(MysqlTables::ACT_SHARE_NUMS, ['nums' => ($share['nums'] + 1)]);
        } else {
            $db->insert(MysqlTables::ACT_SHARE_NUMS, [
                'account_id' => $accountId,
                'date' => $date,
                'nums' => 1
            ]);
        }

        $setting = $this->getValueSettingByKey(self::SHARE_NUMS_CONFIG);
        $settingNums = array_column(json_decode($setting, true), 'redbag_nums', 'share_nums');
        if (!isset($settingNums[$shareNums])) {
            $this->setErrCode(4004);
            $this->setErrMsg('未达到分享次数', true);
            return false;
        }

        $redbagNums = $settingNums[$shareNums];

        $coins = [];
        $rs = json_decode($this->getValueSettingByKey(self::LUCKY_REDBAG_CONFIG), true);
        $probArray = array_column($rs, null, 'id'); 

        for ($i = 1 ; $i <= $redbagNums; $i++) {
            $probId = $this->getRand(array_column($rs, 'prob', 'id'));
            $redbag = $probArray[$probId];
            $coin = mt_rand($redbag['min_value'] * 100, $redbag['max_value'] * 100);
            $coins[] = $coin;
        }

        $db->startTransaction();
        try {
            $data = [];
            $redis = $this->redis->getDb();
            $totalCoins = array_sum($coins);
            $rs = $this->changeActJackpot(2, -1*$totalCoins);
            if (!$rs) {
                $db->rollback();
                return false;
            }
            
            $insertData = [];
            foreach ($coins as $coin) {
                // 添加幸运红包记录
                $insertData[] = [
                    'account_id' => $accountId,
                    'coin' => $coin / 100,
                    'status' => 0,
                    'create_time' => time()
                ];
            }
            $lastInsertIds = $db->insertMulti(MysqlTables::ACT_LUCKY_REDBAG_LOG, $insertData);
            if (!$lastInsertIds) {
                $db->rollback();
                return false;
            }
            $data = [];
            foreach ($lastInsertIds as $key => $value) {
                $data[] = ['id' => $value, 'coin' => $coins[$key] / 100];
            }
            $db->commit();
            return $data;
        } catch (\Exception $e) {
            $db->rollback();
            return false;
        }
    }

    public function openLuckyRedbag($accountId, $redbagId)
    {
        $db = $this->mysql->getDb();
        $rs = $db->where('id', $redbagId)->where('account_id', $accountId)->getOne(MysqlTables::ACT_LUCKY_REDBAG_LOG);
        if (empty($rs)) {
            $this->setErrCode(4005);
            $this->setErrMsg('红包不存在', true);
            return false;
        }
        if ($rs['status'] == 1) {
            $this->setErrCode(4006);
            $this->setErrMsg('该红包已领取', true);
            return false;
        }
        if ($db->where('id', $redbagId)->update(MysqlTables::ACT_LUCKY_REDBAG_LOG, ['status' => 1, 'receive_time' => time()])) {
            return ['coin' => $rs['coin']];
        }
        return false;
    }

    public function getRainyRedbag($accountId)
    {
        $db = $this->mysql->getDb();
        // 获取红包雨设置
        $setting = $db->where('status', 0)->where('end_time', time(), '>')->getOne(MysqlTables::ACT_RAINY_REDBAG_SETTING);

        // 判断该时间段内是否有红包雨
        if (!$this->checkRainyRedbagTime($setting['send_time'])) {
            $this->setErrCode(4006);
            $this->setErrMsg('红包雨未开启', true);
            return false;
        }

        // 奖池为0，直接未中奖
        $redis = $this->redis->getDb();
        $jackpot = $redis->get(RedisKey::ACT_JACKPOT_RAINY_REDBAG);
        if ($jackpot <= 0) {
            $this->setErrCode(4005);
            $this->setErrMsg('奖池为0，未中奖', true);
            return false;
        }

        // 是否能中红包雨
        $settingProbArray = [
            0 => 100 - $setting['prob'], //未中奖
            1 => $setting['prob']
        ];
        if (!$this->getRand($settingProbArray)) {
            $this->setErrCode(4007);
            $this->setErrMsg('未中奖', true);
            return false;
        }
        
        $wincoin = $this->redis->getDb()->hget(RedisKey::USERS_ . $accountId, 'account_wincoin');
        if($wincoin > 0) {
            //赢钱的用户40%概率不给红包雨
            if (mt_rand(1, 10000) < 4000) {
                $this->setErrCode(4007);
                $this->setErrMsg('未中奖', true);
                return false;
            }
            
        }

        $rs = json_decode($this->getValueSettingByKey(self::RAINY_REDBAG_CONFIG), true);
        $probArray = array_column($rs, 'prob', 'id');
        $probId = $this->getRand($probArray);
        $probArray = array_column($rs, null, 'id');
        $redbag = $probArray[$probId];
        $coinArray = [
            'min' => $redbag['min_prob'],
            'max' => $redbag['max_prob'],
            'other' => $redbag['other_prob']
        ];
        $coinId = $this->getRand($coinArray);
        if ($coinId == 'min') {
            $coin = $redbag['min_value'] * 100;
        } elseif ($coinId == 'max') {
            $coin = $redbag['max_value'] * 100;
        } else { //其他值，去掉最大最小值
            $coin = mt_rand($redbag['min_value'] * 100 + 1, $redbag['max_value'] * 100 - 1);
        }
        
        // 判断余额是否足够，不够直接扣完奖池
        if ($jackpot < $coin) {
            $coin = $jackpot;
        }

        // 添加红包雨记录
        $insertData = [
            'account_id' => $accountId,
            'coin' => $coin / 100,
            'status' => 1, //直接到账，不需要领取
            'create_time' => time()
        ];

        if ($redis->decrBy(RedisKey::ACT_JACKPOT_RAINY_REDBAG, $coin) < 0) {
            $redis->incrBy(RedisKey::ACT_JACKPOT_RAINY_REDBAG, $coin);
            $this->setErrCode(4005);
            $this->setErrMsg('奖池为0，未中奖', true);
            return false;
        }
        $lastInsertId = $db->insert(MysqlTables::ACT_RAINY_REDBAG_LOG, $insertData);
        if (!$lastInsertId) {
            $this->setErrCode(4008);
            $this->setErrMsg('数据库操作失败，未中奖', true);
            return false;
        }

        return ['id' => $lastInsertId, 'coin' => $coin / 100];
    }

    public function getLuckyBox($accountId)
    {
        $db = $this->mysql->getDb();

        // 奖池为0，直接未中奖
        $redis = $this->redis->getDb();
        $jackpot = $redis->get(RedisKey::ACT_JACKPOT);
        if ($jackpot <= 0) {
            $this->setErrCode(4005);
            $this->setErrMsg('奖池为0，未中奖', true);
            return false;
        }

        $setting = json_decode($this->getValueSettingByKey(self::LUCKY_BOX_CONFIG), true);
        $setting = array_column($setting, 'prob', 'coin');
        $coin = 100 * $this->getRand($setting);
        if ($coin > $jackpot) {
            $this->setErrCode(4006);
            $this->setErrMsg('奖池余额不足，未中奖', true);
            return false;
        }

        $db->startTransaction();
        try {
            if (!$rs = $this->changeActJackpot(4, -1*$coin)) {
                $db->rollback();
                return false;
            }

            // 添加幸运宝箱记录
            $insertData = [
                'account_id' => $accountId,
                'coin' => $coin / 100,
                'status' => 1, //直接到账，不需要领取
                'create_time' => time()
            ];

            $lastInsertId = $db->insert(MysqlTables::ACT_LUCKY_BOX_LOG, $insertData);
            if (!$lastInsertId) {
                $db->rollback();
                $this->setErrCode(4008);
                $this->setErrMsg('数据库操作失败，未中奖', true);
                return false;
            }
            $data = ['coin' => $coin / 100, 'lists' => $setting];
            $db->commit();
            return $data;
        } catch (\Exception $e) {
            $db->rollback();
            return false;
        }
    }

    public function checkRainyRedbagTime($sendTimeStr)
    {
        $sendTimeArray = explode('#', $sendTimeStr);
        $time = time();
        foreach ($sendTimeArray as $row) {
            list($startTime, $endTime) = explode('|', $row);
            if ($time > $startTime && $time < $endTime) {
                return true;
            }
        }
        return false;
    }

    /**
     * 活动奖池变化
     * @param  int $type [1 充值 2 幸运红包 3 红包雨 4 幸运宝箱]
     * @param  number $coin
     * @return bool
     */
    public function changeActJackpot($type, $coin)
    {
        $db = $this->mysql->getDb();
        $redis = $this->redis->getDb();
        if ($coin > 0) {
            $rs = $redis->incrBy(RedisKey::ACT_JACKPOT, abs($coin));
        } else {
            $rs = $redis->decrBy(RedisKey::ACT_JACKPOT, abs($coin));
        }
        if ($rs < 0) {
            $redis->incrBy(RedisKey::ACT_JACKPOT, -1*$coin);
            $this->setErrCode(4006);
            $this->setErrMsg('奖池余额不足，未中奖', true);
            return false;
        }
        // 获取活动奖池余额
        $data = [
            'type' => $type,
            'coin' => $coin / 100,
            'create_time' => time()
        ];
        if ($db->insert(MysqlTables::ACT_JACKPOT_LOG, $data)) {
            return true;
        }
        return false;
    }

    public function addJackpot($coin)
    {
        // 向彩池借款
        list($newCoin, $poolnormal) = $this->models->rediscli_model->_loan($coin);
        if ($poolnormal == 0) {
            $this->setErrCode(4001);
            $this->setErrMsg('普通奖池余额不足', true);
            return false;
        }
        $redis = $this->redis->getDb();
        $db = $this->mysql->getDb();
        $db->startTransaction();
        try {
            $insertData = [];
            $insertData['log_id'] = 0;
            $insertData['account_id'] = 0;
            $insertData['game_id'] = 0;
            $insertData['type'] = 7; // 活动奖池充值
            $insertData['coin'] = -1*$coin;
            $insertData['create_time'] = time();
            if (!$this->mysql->getDb()->insert(MysqlTables::POOL_NORMAL, $insertData)) {
                // 回滚，就还款
                $this->models->rediscli_model->_loan($coin);
                $this->setErrCode(4002);
                $this->setErrMsg('数据库操作失败', true);
                $db->rollback();
                return false;
            }

            if (!$this->changeActJackpot(1, $coin * 100)) {
                // 回滚，就还款
                $this->models->rediscli_model->_loan($coin);
                $this->setErrCode(4002);
                $this->setErrMsg('数据库操作失败', true);
                $db->rollback();
                return false;
            }

            $db->commit();
            return true;
        } catch (\Exception $e) {
            // 回滚，就还款
            $this->rediscli_model->_loan($coin);
            $db->rollback();
            return false;
        }
    }

    public function getActivityJackpot()
    {
        $redis = $this->redis->getDb();
        $rs = $redis->get(RedisKey::ACT_JACKPOT);
        return $rs ? $rs / 100 : 0;
    }

    private function getRand($proArr)
    {
        // 将概率放大100倍
        foreach ($proArr as &$one) {
            $one *= 100;
        }
        $result = '';
        //概率数组的总概率精度
        $proSum = array_sum($proArr);
        //概率数组循环
        foreach ($proArr as $key => $proCur) {
            $randNum = mt_rand(1, $proSum);
            if ($randNum <= $proCur) {
                $result = $key;
                break;
            } else {
                $proSum -= $proCur;
            }
        }
        unset ($proArr);
        return $result;
    }

    public function getStatLuckyRedbag($page, $limitValue, $startTime = '', $endTime = '')
    {
        $result = ['list' => [], 'total' => 0];
        $offset = ($page - 1) * $limitValue;
        $db = $this->mysql->getDb();
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'between');
        }
        $fields = "FROM_UNIXTIME(create_time,'%Y-%m-%d') AS date, count(DISTINCT account_id) AS user_nums, count(1) AS send_nums, sum(coin) AS total_coin";
        $db->groupBy('date')->orderBy('date', 'desc');
        $result['list'] = $db->withTotalCount()->get(MysqlTables::ACT_LUCKY_REDBAG_LOG, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    public function getStatRainyRedbag($page, $limitValue, $startTime = '', $endTime = '')
    {
        $result = ['list' => [], 'total' => 0];
        $offset = ($page - 1) * $limitValue;
        $db = $this->mysql->getDb();
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'between');
        }
        $fields = "FROM_UNIXTIME(create_time,'%Y-%m-%d') AS date, count(DISTINCT account_id) AS user_nums, count(1) AS send_nums, sum(coin) AS total_coin";
        $db->groupBy('date')->orderBy('date', 'desc');
        $result['list'] = $db->withTotalCount()->get(MysqlTables::ACT_RAINY_REDBAG_LOG, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }

    public function getStatLuckyBox($page, $limitValue, $startTime = '', $endTime = '')
    {
        $result = ['list' => [], 'total' => 0];
        $offset = ($page - 1) * $limitValue;
        $db = $this->mysql->getDb();
        if ($startTime && $endTime) {
            $db->where('create_time', [$startTime, $endTime], 'between');
        }
        $fields = "FROM_UNIXTIME(create_time,'%Y-%m-%d') AS date, count(DISTINCT account_id) AS user_nums, sum(coin) AS total_coin";
        $db->groupBy('date')->orderBy('date', 'desc');
        $result['list'] = $db->withTotalCount()->get(MysqlTables::ACT_LUCKY_BOX_LOG, [$offset, $limitValue], $fields);
        $result['total'] = $db->getTotalCount();
        return $result;
    }
}