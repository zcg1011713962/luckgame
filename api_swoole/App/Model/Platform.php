<?php

namespace App\Model;

use App\Model\Constants\MysqlTables;
use App\Model\Constants\RedisKey;
use App\Utility\Helper;
use App\Utility\EncryptString;

class Platform extends Model
{
    private $_parent_agent_id = '1001';
    /**
     * api密码秘钥
     * @var string
     */
    private $_encode_key = 'plat@#^^--form';

    /**
     * 获取平台列表
     * @param  string $name
     * @param  int $page
     * @return array
     */
    public function getPlatforms($name, $page)
    {
        $limitValue = 20;
        $offset = ($page = abs(intval($page))) > 0 ? ($page - 1) * $limitValue : 0;

        $db = $this->mysql->getDb();

        $name && $db->where('name', $name);

        $list = $db->withTotalCount()->orderBy('id', 'desc')->get(MysqlTables::PLATFORM, [$offset, $limitValue], 'id, name, api_account, api_whitelist, create_time');
        $count = $db->getTotalCount();
        return ['list' => $list, 'total' => $count];
    }

    /**
     * 新增平台
     * @param  string $name
     * @param  string $apiWhitelist
     * @param  string $agentUsername
     * @param  string $agentPassword
     * @param  string $remark
     * @return bool
     */
    public function postPlatform($name, $apiWhitelist, $agentUsername, $agentPassword, $remark = '')
    {
        $db = $this->mysql->getDb();

        if ($db->where('name', $name)->getOne(MysqlTables::PLATFORM)) {
            $this->setErrCode(3004);
            $this->setErrMsg('平台已存在');
            return false;
        }

        if ($db->where('username', $agentUsername)->getOne(MysqlTables::ACCOUNT)) {
            $this->setErrCode(3004);
            $this->setErrMsg('代理账号已存在');
            return false;
        }

        $db->startTransaction();
        try {
            $apiAccount = $this->generateApiAccount();
            $apiPassword = $this->encodePassword($this->generateApiPassword());

            $insertData = [
                'name' => $name,
                'api_account' => $apiAccount,
                'api_password' => $apiPassword,
                'api_whitelist' => $apiWhitelist,
                'create_time' => time()
            ];
            $remark && $insertData['remark'] = $remark;

            $db->insert(MysqlTables::PLATFORM, $insertData);

            if (!($appid = $db->getInsertId())) {
                $db->rollback();
                return false;
            }

            /**
             * 添加代理账号
             * 默认上级为 1001
             */
            if (!$this->models->account_model->addAgent(1001, $agentUsername, $agentPassword, 2, $appid)) {
                $db->rollback();
                return false;
            }

            //代理账号添加到redis已存在库
            $this->models->rediscli_model->getDb()->sAdd(RedisKey::SETS_USERNAME, $agentUsername);

            $db->commit();
            return true;
        } catch (\Exception $e) {
            $db->rollback();
            return false;
        }
    }

    /**
     * 修改平台信息
     * @param  int $id
     * @param  string $name
     * @param  string $apiWhitelist
     * @param  string $remark
     * @return bool
     */
    public function putPlatform($id, $name, $apiWhitelist, $remark)
    {
        $db = $this->mysql->getDb();

        if (!$db->where('id', $id)->getOne(MysqlTables::PLATFORM)) {
            return false;
        }

        $updateData = [];
        $name && $updateData['name'] = $name;
        $apiWhitelist && $updateData['api_whitelist'] = $apiWhitelist;
        $remark && $updateData['remark'] = $remark;
        if ($updateData) {
            $updateData['update_time'] = time();
            if ($db->where('id', $id)->update(MysqlTables::PLATFORM, $updateData)) {
                return true;
            }
        }
        return false;
    }

    /**
     * 获取平台对应的代理信息
     * @param  int $id
     * @return array
     */
    public function getPlatform($id)
    {
        $db = $this->mysql->getDb();
        $rs = $db->where('id', $id)->getOne(MysqlTables::PLATFORM);
        if (!$rs) {
            return false;
        }
        // 获取代理信息
        $account = $db->where('appid', $id)->where('agent', 0, '>')->getOne(MysqlTables::ACCOUNT);
        $rs['username'] = $account['username'];
        $rs['coin'] = $account['coin'];
        return $rs;
    }

    /**
     * 获取api明文密码
     * @param  int $id
     * @return mixed
     */
    public function getApiPassword($id)
    {
        $db = $this->mysql->getDb();
        $rs = $db->where('id', $id)->getOne(MysqlTables::PLATFORM);
        if (!$rs) {
            return false;
        }
        return $this->decodePassword($rs['api_password']);
    }

    /**
     * api账号密码验证
     * @param  string $apiAccount
     * @param  string $apiPassword
     * @return bool
     */
    public function checkApiPassword($apiAccount, $apiPassword)
    {
        $db = $this->mysql->getDb();
        $rs = $db->where('api_account', $apiAccount)->getOne(MysqlTables::PLATFORM);
        if (!$rs) {
            return false;
        }

        return $this->encodePassword($apiPassword) === $rs['api_password'];
    }

    /**
     * 平台充值
     * @param  int $appid
     * @param  float $coin
     * @param  str $ipaddr
     * @return bool
     */
    public function recharge($appid, $coin, $ipaddr)
    {
        $db = $this->mysql->getDb();
        //获取目标用户
        $agent = $db->where('appid', $appid)->where('agent', 0, '>')->getOne(MysqlTables::ACCOUNT);
        if (empty($agent)) {
            $this->setErrMsg('平台对应的代理不存在');
            return false;
        }
        if ($coin < 0 && $agent['coin'] < abs($coin)) {
            $this->setErrCode(3002);
            $this->setErrMsg('额度不足');
            return false;
        }

        $db->startTransaction();
        try {
            //金币变化
            $data = [
                'account_id'=> $agent['id'],
                'agent'=> $agent['agent'],
                'type'=> $coin > 0 ? 1 : 2,
                'before'=> $agent['coin'],
                'coin'=> $coin,
                'after'=> Helper::format_money($agent['coin'] + $coin),
                'create_time'=> time(),
                'ipaddr'=> $ipaddr
            ];
            
            $db->insert(MysqlTables::SCORE_LOG, $data);
            if ($db->getInsertId()) {
                //减
                $db->where('id', $agent['parent_id'])->setDec(MysqlTables::ACCOUNT, 'coin', $coin);
                //加
                $db->where('id', $agent['id'])->setInc(MysqlTables::ACCOUNT, 'coin', $coin);
                $db->commit();
                return true;
            } else {
                $db->rollback();
                $this->setErrMsg('数据库操作');
                return false;
            }
        } catch (\Exception $e) {
            $db->rollback();
            $this->setErrMsg('数据库操作');
            return false;
        }
    }

    /**
     * 生成api账号 'N' + 7位随机数
     * @return string
     */
    private function generateApiAccount()
    {
        $str = "0123456789";

        $apiAccount = 'N';
        for ($i = 0; $i < 7; $i++) {
            $apiAccount .= $str{mt_rand(0, strlen($str) - 1)};
        }

        $db = $this->mysql->getDb();
        if ($db->where('api_account', $apiAccount)->getOne(MysqlTables::PLATFORM)) {
            return $this->generateApiAccount();
        }

        return $apiAccount;
    }

    /**
     * 生成api密码 14位随机数
     * @return string
     */
    private function generateApiPassword()
    {
        $str = "0123456789abcdefghijkmnpqrstuvwxyzABCDEFGHIJKMNPQRSTUVWXYZ";

        $apiPassword = '';
        for ($i = 0; $i < 14; $i++) {
            $apiPassword .= $str{mt_rand(0, strlen($str) - 1)};
        }

        return $apiPassword;
    }

    /**
     * api密码加密
     * @param  string $password
     * @return string
     */
    private function encodePassword($password)
    {
        return $this->encrypt($password, $this->_encode_key);
    }

    /**
     * api密码解密
     * @param  string $password
     * @return string
     */
    private function decodePassword($password)
    {
        return $this->decrypt($password, $this->_encode_key);
    }

    private function encrypt($data, $key)
    {
        $key    = md5($key);
        $x      = 0;
        $len    = strlen($data);
        $l      = strlen($key);
        $char   = '';
        $str    = '';
        for ($i = 0; $i < $len; $i++) {
            if ($x == $l) {
                $x = 0;
            }
            $char .= $key{$x};
            $x++;
        }
        for ($i = 0; $i < $len; $i++) {
            $str .= chr(ord($data{$i}) + (ord($char{$i})) % 256);
        }
        return base64_encode($str);
    }

    private function decrypt($data, $key)
    {
        $key    = md5($key);
        $x      = 0;
        $data   = base64_decode($data);
        $len    = strlen($data);
        $l      = strlen($key);
        $char   = '';
        $str    = '';
        for ($i = 0; $i < $len; $i++) {
            if ($x == $l) {
                $x = 0;
            }
            $char .= substr($key, $x, 1);
            $x++;
        }
        for ($i = 0; $i < $len; $i++) {
            if (ord(substr($data, $i, 1)) < ord(substr($char, $i, 1))) {
                $str .= chr((ord(substr($data, $i, 1)) + 256) - ord(substr($char, $i, 1)));
            } else {
                $str .= chr(ord(substr($data, $i, 1)) - ord(substr($char, $i, 1)));
            }
        }
        return $str;
    }
}