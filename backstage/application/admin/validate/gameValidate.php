<?php
namespace app\admin\validate;
use think\Validate;

class gameValidate extends Validate {

    protected $rule =   [
        'id' => 'require|number',
        'gameId' => 'require|number',
        'gameName' => 'require',
        'gamePort' => 'require|number',
        'gameType' => 'require|number|gt:0|lt:4',
        'choushuilv' => 'require|number|between:0,14',
        'nandulv' => 'require|number|between:0,10',
        'waterGame' => 'number',
        'waterLevel' => 'requireWith:waterGame|number',
        'balance' => 'requireWith:waterGame|number',
        'winPool' => 'requireWith:waterGame|number',
        'bigWinLevel' => 'requireWith:waterGame|checkbigWin:123',
        'bigWinLuck' => 'requireWith:waterGame|checkbigWin:123',
        'rtp' => 'requireWith:waterGame|number',
    ];
    
    protected $message  =   [
        'id.require' => 'id不能为空',
        'id.number'     => 'id必须为数字',
        'gameId.require' => '请填写游戏ID',
        'gameId.number'     => '游戏ID必须为数字',
        'gameName.require'   => '请填写游戏名称',
        'gamePort.require'  => '请填写游戏端口',
        'gamePort.number' => '游戏端口必须为数字',
        'gameType.require' => '请选择游戏类型',
        'gameType.number' => '游戏类型必须为数字',
        'gameType.gt' => '游戏类型必须大于0',
        'gameType.lt' => '游戏类型必须小于4',
        'choushuilv.between' => '抽水等级必须在1-14之间',
        'nandulv.between' => '难度等级必须在1-10之间',
        'choushuilv.number' => '抽水难度必须为数字',
        'nandulv.number' => '游戏难度必须为数字',
        'waterLevel.requireWith' => '水位值不能为空',
        'waterLevel.number' => '水位值必须为数字',
        'balance.requireWith' => '水位库存不能为空',
        'balance.number' => '水位库存必须为数字',
        'winPool.requireWith' => '奖池不能为空',
        'winPool.number' => '奖池必须为数字',
        'bigWinLevel.requireWith' => '大奖幸运等级不能为空',
        'bigWinLuck.requireWith' => '大奖幸运概率不能为空',
        'rtp.requireWith' => 'RTP值不能为空',
        'rtp.number' => 'RTP值必须为数字'
    ];
    
    protected $scene = [
        'add'  =>  ['gameId','gameName','gamePort','gameType','choushuilv','nandulv','waterGame','balance','winPool','rtp'],
        'deleteAndEdit' => ['gameId'],
        'edit' => ['id','gameId','gameName','gamePort','gameType','choushuilv','nandulv','waterGame','balance','winPool','rtp'],
    ];

    protected function checkbigWin($value, $rule, $data = []) {
        if ($data['waterGame'] > 0) {
            $formatArr = explode(',',$value);
            if (count($formatArr) != 3) {
              return '输入格式有误，只能输入 x,x,x';
            }
            foreach ($formatArr as $v) {
                if (!is_numeric($v)) {
                    return '只能填写数字';
                }
            }
            return true;
        } else {
            return true;
        }
    }
}