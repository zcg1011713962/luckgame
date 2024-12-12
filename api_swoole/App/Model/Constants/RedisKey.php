<?php
namespace App\Model\Constants;

class RedisKey
{
    /**
     * 玩家账号PID集合
     * 集合
     * @var string
     */
    const SETS_PID = "{bigbang}:sets:pid";
    const SETS_PCODE = "{bigbang}:sets:pcode";
    /**
     * 账号ID(UID)集合
     * 集合
     * @var string
     */
    const SETS_ID = "{bigbang}:sets:id";
    /**
     * 玩家账号 token
     * string
     * @var string
     */
    const PLAYER_TOKEN_ = "{bigbang}:player:token:";
    /**
     * 玩家账号 uid
     * string
     * @var string
     */
    const PLAYER_USERS_UID_ = "{bigbang}:player:users:uid:";
    /**
     * 玩家账号 pid
     * string
     * @var string
     */
    const PLAYER_USERS_PID_ = "{bigbang}:player:users:pid:";
    /**
     * 账号
     * 哈希hash
     * @var string
     */
    const USERS_ = "{bigbang}:users:";
    
    const OPENAPI_GAMEURL = "{bigbang}:openapi:gameurl";
    
    const LOGS_COINS_PLAYER = "{bigbang}:logs:coins:player";
    const LOGS_COINS_PLAYER_HISTORY = "{bigbang}:logs:coins:player:history";
    
    const LOGS_GPOOL = "{bigbang}:logs:gpool";
    const LOGS_GPOOL_HISTORY = "{bigbang}:logs:gpool:history";
    
    const LOGS_GEVENT = "{bigbang}:logs:gevent";
    const LOGS_GEVENT_HISTORY = "{bigbang}:logs:gevent:history";
    
    const LOGS_GPLAY = "{bigbang}:logs:gplay";
    const LOGS_GPLAY_HISTORY = "{bigbang}:logs:gplay:history";
    
    const LOGS_TPGPLAY = "{bigbang}:logs:tpgplay";
    const LOGS_TPGPLAY_HISTORY = "{bigbang}:logs:tpgplay:history";

    const LOGS_INNER_POOL_TAX = "{bigbang}:logs:tax";
    const LOGS_INNER_POOL_TAX_HISTORY = "{bigbang}:logs:tax";
    const LOGS_INNER_POOL_JP = "{bigbang}:logs:pool:jp";
    const LOGS_INNER_POOL_JP_HISTORY = "{bigbang}:logs:pool:jp";
    const LOGS_INNER_POOL_NORMAL = "{bigbang}:logs:pool:normal";
    const LOGS_INNER_POOL_NORMAL_HISTORY = "{bigbang}:logs:pool:normal";

    /**
     * 税池
     * 抽税开关 1=关闭
     * 设置了过期时间
     * @var string
     */
    const SYSTEM_BALANCE_TAX_CLOSE = "{bigbang}:system:balance:tax:close";
    /**
     * 税池
     * 当前税池余额
     * @var string
     */
    const SYSTEM_BALANCE_TAX_NOW = "{bigbang}:system:balance:tax:now";
    /**
     * 税池
     * 当前税池余额
     * 设置了过期时间
     * @var string
     */
    const SYSTEM_BALANCE_TAX_LAST = "{bigbang}:system:balance:tax:last";
    /**
     * 池子余额
     * string
     * 普通池 poolnormal
     * @var string
     */
    const SYSTEM_BALANCE_POOLNORMAL = "{bigbang}:system:balance:poolnormal";
    /**
     * 池子余额
     * string
     * JP池 pooljp
     * @var string
     */
    const SYSTEM_BALANCE_POOLJP = "{bigbang}:system:balance:pooljp";
    /**
     * 账号登录锁定时间，单位：秒
     * string
     * @var string
     */
    const ACCOUNT_LOGIN_MATCHPWD_LOCKSEC_ = "{bigbang}:account:login:matchpwd:locksec:";
    /**
     * 账号登录锁定，错误次数
     * string
     * @var string
     */
    const ACCOUNT_LOGIN_MATCHPWD_TIME_ = "{bigbang}:account:login:matchpwd:time:";
    /**
     * 账号密码1分钟内输入错误5次
     * string
     * @var string
     */
    const ACCOUNT_LOGIN_MATCHPWD_INIT_ = "{bigbang}:account:login:matchpwd:init:";
    
    const ACCOUNT_CAPTCHA_EMAIL_ = "{bigbang}:account:captcha:email:";
    
    /**
     * 新创建的玩家账号，日志
     * 左入右出
     * list
     * @var string
     */
    const LOGS_PLAYERS = "{bigbang}:logs:players";
    /**
     * 系统设置
     * string
     * @var string
     */
    const SYSTEM_SETTING = "{bigbang}:system:setting";
    /**
     * 客户端公告
     * string
     * @var string
     */
    const SYSTEM_CLIENT_NOTICE_ = "{bigbang}:system:client:notice:";
    /**
     * username集合
     * 集合
     * @var string
     */
    const SETS_USERNAME = "{bigbang}:sets:username";
    const SETS_USEREMAIL = "{bigbang}:sets:useremail";
    /**
     * vusername集合
     * 集合
     * @var string
     */
    const SETS_VUSERNAME = "{bigbang}:sets:vusername";
    /**
     * 系统余额
     * 集合
     * 普通池 poolnormal
     * 归零记录集合
     * @var string
     */
    const SYSTEM_BALANCE_POOLNORMAL_HISSET = "{bigbang}:system:balance:poolnormal:hisset";
    /**
     * 系统余额
     * 集合
     * 普通池 pooljp
     * 归零记录集合
     * @var string
     */
    const SYSTEM_BALANCE_POOLJP_HISSET = "{bigbang}:system:balance:pooljp:hisset";
    /**
     * 系统余额
     * 集合
     * Tax池 pooltax
     * 归零记录集合
     * @var string
     */
    const SYSTEM_BALANCE_POOLTAX_HISSET = "{bigbang}:system:balance:pooltax:hisset";
    /**
     * 跑马灯广告
     * string
     * @var string
     */
    const SYSTEM_NOTICE_ROLLING_ITEM_ = "{bigbang}:system:notice:rolling:item_";
    /**
     * 代理账号 token
     * string
     * @var string
     */
    const AGENT_TOKEN_ = "{bigbang}:agent:token:";
    /**
     * 代理账号 uid
     * @var string
     */
    const AGENT_USERS_UID_ = "{bigbang}:agent:users:uid:";
    /**
     * 代理账号 username
     * @var string
     */
    const AGENT_USERS_USERNAME_ = "{bigbang}:agent:users:username:";
    const PROB_SET_UID_ = "{bigbang}:prob:set:uid:";
    const PROB_SET_AGENT_ = "{bigbang}:prob:set:agent:";
    /**
     * http请求日志
     * 普通池 poolnormal
     * 借款
     * @var string
     */
    const POOLNORMAL_HTTPLOG_LOAN = "{bigbang}:poolnormal:httplog:loan";
    /**
     * http请求日志
     * 普通池 poolnormal
     * 还款
     * @var string
     */
    const POOLNORMAL_HTTPLOG_REVERT = "{bigbang}:poolnormal:httplog:revert";
    /**
     * 玩家游戏的下注额（上限和下限）
     */
    const BET_MIN_MAX = "{bigbang}:bet_min_max:";
    
    //被直接禁用的账号UID集合
    const COM_SET_BANUIDS = "{bigbang}:set:banuids";
    
    //某账号的祖先UID集合
    const COM_SET_TEMP_ANCESTORIDS_ = "{bigbang}:set:temp:ancestorids:";
    
    //某账号的子孙UID集合
    const COM_SET_TEMP_DESCENDANTIDS_ = "{bigbang}:set:temp:descendantids:";

    /**
     * 活动红包配置
     */
    // 幸运红包数值
    const ACT_LUCKY_REDBAG_CONFIG = "{bigbang}:activity:lucky_redbag_config";
    // 分享次数数值
    const ACT_SHARE_NUMS_CONFIG = "{bigbang}:activity:share_nums_config";
    // 红包雨数值
    const ACT_RAINY_REDBAG_CONFIG = "{bigbang}:activity:rainy_redbag_config";
    // 成长值数值
    const ACT_GROWTH_VALUE_CONFIG = "{bigbang}:activity:growth_value_config";
    // 幸运宝箱数值
    const ACT_LUCKY_BOX_CONFIG = "{bigbang}:activity:lucky_box_config";
    // 幸运红包开关
    const ACT_LUCKY_REDBAG_SWITCH = "{bigbang}:activity:lucky_redbag_switch";
    // 成长值比例
    const ACT_GROWTH_VALUE_RATIO = "{bigbang}:activity:growth_value_ratio";
    // 成长值开关
    const ACT_GROWTH_VALUE_SWITCH = "{bigbang}:activity:growth_value_switch";
    /**
     * 活动奖池
     */
    const ACT_JACKPOT = "{bigbang}:activity:jackpot";
    /**
     * 红包雨奖池
     */
    const ACT_JACKPOT_RAINY_REDBAG = "{bigbang}:activity:jackpot:rainy_redbag";

    const ACT_RAINY_REDBAG_SETTING = "{bigbang}:activity:rainy_redbag_setting";
    /**
     * IP地址重复数
     * @var string
     */
    const SOUL_S1_STRING_IPADDR_ = "{bigbang}:soul:s1:string:ipaddr:";
    /**
     * UUID重复数
     * @var string
     */
    const SOUL_S1_STRING_UUID_ = "{bigbang}:soul:s1:string:uuid:";
    /**
     * 账号属性
     * 登录时间               login_time
     * 终结时间点           expires_time
     * 首次上分额度       reload
     * 下注限额              limitbets
     * 总下注                  totalbets
     * 输赢限额              limitbalance
     * 当前输赢              balance
     * 设备UUID       uuid
     * @var string
     */
    const SOUL_S1_HASH_ACCOUNT_ = "{bigbang}:soul:s1:hash:account:";
    /**
     * 当前账号集合
     * @var string
     */
    const SOUL_S1_SSET_ACCOUNTS = "{bigbang}:soul:s1:sset:accounts";
    /**
     * 代理上分限制判断，被允许的账号集合
     * @var string
     */
    const SOUL_S1_SET_ACCOUNTS = "{bigbang}:soul:s1:set:accounts";
    /**
     * 代理上分总额记录
     * @var string
     */
    const SOUL_S1_HASH_AGENT_ = "{bigbang}:soul:s1:hash:agent:";
    
    const STAT_GAME_SET_ = "{bigbang}:stat:game:set:";
    
    const GAME_LIST_HASH_ = "{bigbang}:game:list:hash:";

    const LOCK_CHINA = "lock_china";

    const USER_STRATEGY = "you9sdkapi:rewardrate:user:"; //玩家输赢策略
    const USER_STRATEGY_LIMIT     = "account_maxlimit"; //玩家能否中免费和小游戏，配合大输的情况
}