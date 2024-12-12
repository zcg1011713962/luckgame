<?php
namespace App\Model\Constants;

use PhpParser\Node\Const_;

class MysqlTables
{
    /**
     * 账号-代理子账号
     * @var string
     */
    const ACCOUNT_CHILD_AGENT                           = "account_child_agent";
    /**
     * 帐号-主
     * @var string
     */
    const ACCOUNT                                       = "account";
    /**
     * 账号-禁用关系
     * @var string
     */
    const ACCOUNT_BAN                                   = "account_ban";
    /**
     * 账号登录IP限制
     * @var string
     */
    const ACCOUNT_LOGINIP                                   = "account_loginip";
    /**
     * --
     * @var string
     */
    const LOG_API_BACKOFFICE                            = "log_api_backoffice";
    /**
     * 账号-日志-登录
     * @var string
     */
    const LOG_LOGIN_PLAYER                              = "log_login_player";
    /**
     * 账号-树关系
     * @var string
     */
    const ACCOUNT_TREE                                  = "account_tree";
    /**
     * 余额-PoolJP池-重置历史
     * @var string
     */
    const POOL_JP_RESET                                 = "pool_jp_reset";
    /**
     * 余额-PoolNormal彩池-重置历史
     * @var string
     */
    const POOL_NORMAL_RESET                             = "pool_normal_reset";
    /**
     * 余额-PoolTax池-重置历史
     * @var string
     */
    const POOL_TAX_RESET                                = "pool_tax_reset";
    
    const COINS_PLAYER                                  = "coins_player";
    const COINS_PLAYER_DAY                              = "coins_player_day";
    const POOL_JP                                       = "pool_jp";
    const POOL_NORMAL                                   = "pool_normal";
    const POOL_TAX                                      = "pool_tax";
    const REDBAG                                        = "redbag";
    const SCORE_LOG                                     = "score_log";
    const SCORE_RELATION_LOG                            = "score_relation_log";
    const SOUL_S1_ACCOUNT                               = "soul_s1_account";
    const REDBAG_ZONGDAI                                = "redbag_zongdai"; //总代给游戏内玩家发的
    const REDBAG_AGENT                                  = "redbag_agent"; //代理创建玩家给发随机红包
    /**
     * COIN-bigbang开奖记录
     * @var string
     */
    const COINS_BIGBANG                                 = "coins_bigbang";
    /**
     * 日期表（辅助查询）
     * @var string
     */
    const ASSIST_DATELIST                               = "assist_datelist";
    /**
     * 游戏配置表
     * @var string
     */
    const SYS_GAME_CONFIG                               = "sys_game_config";
    /**
     * 游戏记录
     * @var string
     */
    const GAMESERVER_GAMELOG                            = "gameserver_gamelog";
    const GAMESERVER_GAMEPOOL                           = "gameserver_gamepool";
    const GAMESERVER_GAMEEVENT                          = "gameserver_gameevent";
    /**
     * 游戏记录-第三方平台-evo
     * @var string
     */
    const GAMESERVER_GAMELOG_EVO                        = "gameserver_gamelog_evo";
    const GAMESERVER_GAMELOG_                           = "gameserver_gamelog_";
    /**
     * 公告-客户端，代理直属玩家可见
     * @var string
     */
    const SYS_CLIENTNOTICE                              = "sys_clientnotice";
    /**
     * 公告-跑马灯全局
     * @var string
     */
    const SYS_ROLLINGNOTICE                             = "sys_rollingnotice";
    /**
     * 公告-系统全局
     * @var string
     */
    const SYS_GLOBALNOTICE                              = "sys_globalnotice";
    /**
     * 权限-组
     * @var string
     */
    const ACCOUNT_GROUP                                 = "account_group";
    /**
     * 权限-组权限
     * @var string
     */
    const API_PERMISSION                                = "api_permission";
    /**
     * 权限
     * @var string
     */
    const API_METHODS                                   = "api_methods";
    /**
     * 概率-设置表
     * @var string
     */
    const SYS_GAME_PROB                                 = "sys_game_prob";
    /**
     * 每个游戏下注次数
     * @var string
     */
    const STAT_BET_NUMS                                 = "stat_bet_nums";
    /**
     * 报表-30分钟-玩家分数存量
     * @var string
     */
    const STAT_COIN_PLAYER                              = "stat_coin_player";
    /**
     * 报表-日-系统总赢分
     * @var string
     */
    const STAT_SYSWIN                                   = "stat_syswin";
    /**
     * 每个游戏库存数据
     * @var string
     */
    const STAT_MAINPOLL                                 = "stat_mainpoll";
    /**
     * 报表-5分钟-指定游戏的玩家在线数
     * @var string
     */
    const STAT_ONLINE_GAME                              = "stat_online_game";
    /**
     * 报表-30分钟-玩家在线数
     * @var string
     */
    const STAT_ONLINE_PLAYER                            = "stat_online_player";
    /**
     * 报表-5分钟-JP奖池库存
     * @var string
     */
    const STAT_POOL_JP                                  = "stat_pool_jp";
    /**
     * 报表-5分钟-普通奖池（彩池）库存
     * @var string
     */
    const STAT_POOL_NORMAL                              = "stat_pool_normal";
    /**
     * 报表-5分钟-系统抽税TAX
     * @var string
     */
    const STAT_POOL_TAX                                 = "stat_pool_tax";
    /**
     * 系统-设置参数
     * @var string
     */
    const SYS_SETTING                                   = "sys_setting";
    /**
     * 每日分数统计表
     * @var string
     */
    const STAT_COUNT                                    = "stat_count";
    /**
     * 对账报警表
     * @var string
     */
    const STAT_ALARM                                    = "stat_alarm";

    const PLATFORM                                      = "platform";
    const ACCOUNT_AUTH                                  = "account_auth";
    const AUTH                                          = "auth";
    const REGION                                        = "region";

    const ACT_RAINY_REDBAG_SETTING                      = "act_rainy_redbag_setting";
    const ACT_LUCKY_REDBAG_LOG                          = "act_lucky_redbag_log";
    const ACT_RAINY_REDBAG_LOG                          = "act_rainy_redbag_log";
    const ACT_JACKPOT_LOG                               = "act_jackpot_log";
    const ACT_SHARE_NUMS                                = "act_share_nums";
    const ACT_SETTING                                   = "act_setting";
    const ACT_LUCKY_BOX_LOG                             = "act_lucky_box_log";
    
    const STAT_SOUL_ACCOUNT                             = "stat_soul_account";
    const ACCOUNT_SETTING                               = "account_setting";
    
    const LOG_PROFIT_PLAYER                             = "log_profit_player";
    
    const CI_EVOLUTION_GAME_HISTORY                     = "ci_evolution_game_history";
    
    const STAT_GAMES                                    = "stat_games";
    const STAT_GAMES_LOG                                = "stat_games_log";
    
    const LOG_ALERT                                     = "log_alert";

    /**
     * 与第3方的流水交互
     * @var string
     */
    const TRANSACTION_ORDER                              = "transaction_order";
}