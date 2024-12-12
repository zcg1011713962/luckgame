<?php
return [
	'deploy'      => 1,
    // 数据库类型
    'type'        => 'mysql',
    // 服务器地址
    'hostname'    => "127.0.0.1",
    // 数据库名
    'database'    => 'ym_manage',
    // 数据库用户名
    'username'    => 'root',
    // 数据库密码
    'password'    => 'yx168168',
    //'password'    => 'root',
    // 数据库连接端口
    'hostport'    => 3406,
    // 数据库连接参数
    'params'      => ["allowPublicKeyRetrieval=True"],
    'break_reconnect' => true,
     'query_start_transaction' => true,
    // 数据库编码默认采用utf8
    'charset'     => 'utf8',
    // 数据库表前缀
    'prefix'      => '',

    //数据库配置1
	'db_gameaccount' => [
        'type'        => 'mysql',
        'hostname'    => '127.0.0.1',
        'database'    => 'gameaccount',
        'username'    => 'root',
        'password' => 'yx168168',
        'charset'     => 'utf8',
        'prefix'      => '',
        'break_reconnect' => true,
         'query_start_transaction' => true,
    ],
    'db_ddzbsc' => [
        'type'        => 'mysql',
        'hostname'    => "127.0.0.1",
        'database'    => 'landlords',
        'username'    => 'root',
        'password' => 'yx168168',
        'charset'     => 'utf8',
        'prefix'      => '',
        'break_reconnect' => true,
        'query_start_transaction' => true,
    ],
    'db_laba' => [
        'type'        => 'mysql',
        'hostname'    => '127.0.0.1',
        'database'    => 'la_ba',
        'username'    => 'root',
        'password' => 'yx168168',
        'charset'     => 'utf8',
        'refix'      => '',
        'break_reconnect' => true,
        'query_start_transaction' => true,
    ],
];
?>
