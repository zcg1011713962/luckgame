<?php
return [
    'SERVER_NAME' => "Indiarummy API Swoole",
    'MAIN_SERVER' => [
        'LISTEN_ADDRESS' => '0.0.0.0',
        'PORT' => 9638,
        'SERVER_TYPE' => EASYSWOOLE_WEB_SERVER,
        'SOCK_TYPE' => SWOOLE_TCP,
        'RUN_MODEL' => SWOOLE_PROCESS,
        'SETTING' => [
            'worker_num' => 3,
            'max_request' => 10000,
            'task_worker_num' => 3,
            'task_max_request' => 100000,
            'task_enable_coroutine' => true,
            'task_async' => true
        ],
    ],
    
    'TEMP_DIR' => null,
    'LOG_DIR' => null,
    'CONSOLE' => [
        'ENABLE' => true,
        'LISTEN_ADDRESS' => '127.0.0.1',
        'HOST' => '127.0.0.1',
        'PORT' => 9648,
        'EXPIRE' => '120',
        'PUSH_LOG' => true,
        'AUTH' => [
            [
                'USER' => 'root',
                'PASSWORD' => '123456',
                'MODULES' => [
                    'auth','server','help'
                ],
                'PUSH_LOG' => true,
            ]
        ]
    ],
    'FAST_CACHE' => [
        'PROCESS_NUM' => 0,
        'BACKLOG' => 256,
    ],
    'DISPLAY_ERROR' => true,
    /*################ MYSQL CONFIG ##################*/
    'MYSQL' => [
        'host'          => '127.0.0.1',
        'port'          => '3306',
        'user'          => 'root',
        'timeout'       => '5',
        'charset'       => 'utf8mb4',
        'password'      => 'yx168168',
        'database'      => 'indiarummy_adm',
        'POOL_MAX_NUM'  => '8',
        'POOL_MIN_NUM'  => '3',
        'POOL_TIME_OUT' => '0.1',
    ],
    /*################ REDIS CONFIG ##################*/
    'REDIS' => [
        'host'          => '127.0.0.1',
        'port'          => '6379',
        'auth'          => 'yx168168',
        'db'            => '6',
        'POOL_MAX_NUM'  => '100',
        'POOL_MIN_NUM'  => '5',
        'POOL_TIME_OUT' => '0.1',
    ],
    /*############# GAME SERVER CONFIG ###############*/
    'GAMESERVER' => [
        'HOST'          => 'http://127.0.0.1',
        'PORT'          => '6920',
    ],
    'OPENAPIGAMEURL'=> 'http://47.99.169.162/h5/poly/web-mobile',
    'OPENAPIGAMEICON'=> 'http://47.99.169.162/',
    'EVOLUTION' => [
        'HOST'=> 'http://staging.evolution.asia-live.com',
        'HOST2'=> 'http://staging.evolution.asia-live.com',
        'CID'=> '139014',
        'CURRENCY'=> 'MYR',
        'KEY'=> 'moz3rgsfhrqw2uwv',
        'TOKEN'=> 'aec9ba2f62ac5f262b38fd518841ed4a'
    ],
    'APPTYPE'=> 10, //1=BB,2=POLY,3=LAMI , 5=lamislots
    'AREACODE'=> '1', //马来/文莱/新加坡 60， 印尼 62， 香港 52 泰国 66
    'GAME_DBNAME' => 'indiarummy_game',
];
