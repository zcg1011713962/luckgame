<?php
return [
	// 缓存配置为复合类型
    'type'  =>  'complex', 
	
    'default'	=>	[
      'type'	=>	'file',      
      'expire'=>  3600*24, // 全局缓存有效期（0为永久有效）
      'prefix'=>  'file_',
      'path'  =>  '../runtime/cache/',
    ],
	
	// redis缓存
	'redis'   =>  [
		'type'   => 'redis',
		'host'       => '127.0.0.1',
		//'host'       => '192.168.18.7',
		'password' => 'yx168168',
		'expire'=>  3600*24, // 全局缓存有效期（0为永久有效）		
		'prefix'=>  'redis_',
	],  
];
?>
