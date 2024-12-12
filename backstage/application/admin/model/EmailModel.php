<?php
namespace app\admin\model;
use think\Model;
use think\Db;
use app\admin\utils\emailUtils;
use app\admin\model\GameModel;

class EmailModel extends Model {
    public function getEmailList() {
        $result = Db::table('gameaccount.email')->alias('em')
        ->field('em.isread,em.title,em.content,em.type,em.userid,em.sendid,em.timeStamp,u.Account as username')
        ->leftJoin('gameaccount.newuseraccounts u', 'em.userid = u.Id')
        ->whereIn('em.type','2,999')
        ->order('em.timeStamp','desc')
        ->select();
        return emailUtils::getEmail($result);
    }

    public static function addEmail($params) {
        $data = [];
        // 私信
        if ($params['emailType'] == 2) {
            foreach ($params['userList'] as $k => $v) {
                array_push($data,[
                    'isread' => 0,
                    'title' => $params['title'],
                    'content' => $params['content'],
                    'type' => 2,
                    'otherId' => 0,
                    'userid' => $v['uid'],
                    'sendid' => 0,
                ]);
            }
        }
        // 群发
        if ($params['emailType'] == 1) {
            array_push($data,[
                'isread' => 0,
                'title' => $params['title'],
                'content' => $params['content'],
                'type' => 999,
                'otherId' => 0,
                'userid' => 0,
                'sendid' => 0,
            ]);
        }

        // 循环发送请求服务端发送邮件
        $gameModel = new GameModel;
        foreach ($data as $k => $v) {
            $gameModel->notifyGameEmail('sendEmail',$v['type'],$v['userid']);
        } 

        Db::table('gameaccount.email')->insertAll($data);
    }
}
