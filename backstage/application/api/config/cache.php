<?php
return [
	'redis'   =>  [
		'type'   => 'redis',
		#'host'       => '172.24.0.102',
		'host'       => getenv("REIDS_HOST"),
        #'port'  => '6379',
                'port'  => getenv("REDIS_PORT"),
		#'password' => 'root',
		'password' => getenv("REDIS_PASSWORD"),
		'expire'=>  0, // 全局缓存有效期（0为永久有效）		
		'prefix'=>  'api_',
	],
];
