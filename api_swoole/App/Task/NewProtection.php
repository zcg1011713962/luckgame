<?php

namespace App\Task;

use App\Model\Constants\MysqlTables;
use App\Model\Constants\RedisKey;
use App\Model\ModelAssemble;
use EasySwoole\EasySwoole\Swoole\Task\AbstractAsyncTask;
use App\Utility\RDB;
use App\Utility\MDBSC;

//新人保护机制 下注
class NewProtection extends AbstractAsyncTask
{
    protected function run($taskData, $taskId, $fromWorkerId, $flags = null)
    {
        echo "游戏灵魂任务开始\n";
        $redis = new RDB();
        $mysql = new MDBSC();

        /**
         * 游戏灵魂 - 开始
         */
        if ($redis->getDb()->sismember(RedisKey::SOUL_S1_SET_ACCOUNTS, $taskData['account_id'])
            //是否属于活动账号+是否在有效期内
            && !! ($vt = $redis->getDb()->zScore(RedisKey::SOUL_S1_SSET_ACCOUNTS, $taskData['account_id']))
            //是否在有效期内
            && $vt > time()
        ) {
            if($taskData['type'] == 'win') {
                //判断是否已经达到余额限制
                if($taskData['after'] > $redis->getDb()->hGet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $taskData['account_id'], 'limitbalance')) {
                    //移除小赢概率
                    $model = new ModelAssemble();
                    if ($model->account_model->putSoulS1Prob($taskData['account_id'], 1)) {
                        //取消有效资格
                        $redis->getDb()->zAdd(RedisKey::SOUL_S1_SSET_ACCOUNTS, 0, $taskData['account_id']);
                        $mysql->getDb()->where('account_id', $taskData['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, ['available'=> 0]);
                    }
                }

                $redis->getDb()->hSet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $taskData['account_id'], 'balance', $taskData['after']);
                $mysql->getDb()->where('account_id', $taskData['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, [
                    'balance'=> $taskData['after']
                ]);
            } else {
                //判断是否已经达到下注总额限制
                if($mysql->getDb()->where('account_id', $taskData['account_id'])->where('type', 3)->sum(MysqlTables::COINS_PLAYER, 'coin') * -1 > $redis->getDb()->hGet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $taskData['account_id'], 'limitbets')) {
                    //移除小赢概率
                    $model = new ModelAssemble();
                    if ($model->getModels()->account_model->putSoulS1Prob($taskData['account_id'], 1)) {
                        //取消有效资格
                        $redis->getDb()->zAdd(RedisKey::SOUL_S1_SSET_ACCOUNTS, 0, $taskData['account_id']);
                        $mysql->getDb()->where('account_id', $taskData['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, ['available'=> 0]);
                    }
                }

                $totalbets = $mysql->getDb()->where('account_id', $taskData['account_id'])->where('type', 3)->sum(MysqlTables::COINS_PLAYER, 'coin') * -1;
                $redis->getDb()->hSet(RedisKey::SOUL_S1_HASH_ACCOUNT_ . $taskData['account_id'], 'totalbets', $totalbets);
                $mysql->getDb()->where('account_id', $taskData['account_id'])->update(MysqlTables::SOUL_S1_ACCOUNT, [
                    'totalbets'=> $totalbets
                ]);
            }
        }



        //游戏灵魂 - 结束
    }

    function finish($result, $task_id)
    {
        //Logger::getInstance()->log( "ok ".time() );
        echo "task模板任务完成\n";
        return true;
    }
}