#### With Draw 协议

错误码:

```
['DRAW_EMPTY_ACCOUNT']  = 540, --账号不能为空
['DRAW_EMPTY_USERNAME'] = 541, --UserName不能为空
['DRAW_EMPTY_IFSC']     = 542, --IFSC不能为空
['DRAW_EMPTY_BANK']     = 543, --银行名不能为空
['DRAW_EMPTY_EMAIL']    = 544, --Email不能为空
['DRAW_EMPTY_PHONE']    = 545, --Phone不能为空
['DRAW_EMPTY_UPI']      = 546, --UPI不能为空
['DRAW_EMPTY_USDTADDR'] = 547, --Usdt Addr 不能为空
['DRAW_ERR_PARAM_COIN'] = 548, --draw 金币必须大于0
['DRAW_ERR_BANKINFO']   = 549, --draw 账户信息不存在
```



##### 1、获取绑定的账户信息

Req:

```
{
	c: 130,
	uid:100100,
}
```

Resp:

```
{
    c:130,
    code:200,
    spcode:0,
    uid:100100,
	coin:20000, --可用余额
	dcoin:100, --可提金额
    bankList: [ --银行信息列表
    	{
    	  account:112312321321321, --账户
    	  username:'sdsfsdfs', --用户名
    	  ifsc:'ifsc_code',
    	  bankname: '银行名',
    	  email:'42222@gmail.com',
    	  id:1, --bank id
    	},
    	...
    ],
    upiList:[ --upi列表
    	{
    		upi:'2332323', --upi地址
    		username:'账户名',
    		phone:'9112323232', --手机号
    		id:2, --bank id
    	},
    	...
    ],
    usdtList:[ --usdt列表
    	{
    		addr:'xxxxxx', --usdt地址
    		id:3, --bank id
    	}
    	...
    ]
}
```

##### 2、绑定账户信息

Req:

```
{
	c:131,
	cat:1, --1:银行 2:upi 3:usdt
	uid:100100,
	account:'我是银行账户/upi地址/usdt 地址',
	username: '账户名', --银行或upi专属
	ifsc:'ifsc_code', --银行专属字段
	bankname: '银行名', --银行名,银行专属字段
	email: 'xxxx@gmail.com', --email,银行专属字段
	phone:'911111', --手机号, upi专属字段
}
```

Resp:

```
{
    c:131, --操作成功时, 和130协议返回一样的结构
    code:200,
    spcode:0,
    uid:100100,
    bankList: [ --银行信息列表
    	{
    	  account:112312321321321, --账户
    	  username:'sdsfsdfs', --用户名
    	  ifsc:'ifsc_code',
    	  bankname: '银行名',
    	  email:'42222@gmail.com',
    	  id:1, --bank id
    	},
    	...
    ],
    upiList:[ --upi列表
    	{
    		upi:'2332323', --upi地址
    		username:'账户名',
    		phone:'9112323232', --手机号
    		id:2, --bank id
    	},
    	...
    ],
    usdtList:[ --usdt列表
    	{
    		addr:'xxxxxx', --usdt地址
    		id:3, --bank id
    	}
    	...
    ]
}
```

##### 3、Draw 操作

Req:

```
{
	c:132,
	uid:100100,
	coin:100, --操作的金币数
	bankid:1, --bank id
}
```

Resp:

```
{
	c:132,
	uid:100100,
	code:200,
	spcode:0,
	coin:100, --操作的金币数
	bankid:1, --bank id
}
```

##### 4、历史记录

Req:

```
{
	c:133,
	uid:100100,
	cat: 1, --1:pay log; 2: draw log
}
```

Resp:

```
{
	c:133,
	code:200,
	spcode:0,
	uid:100100,
	cat: 1,
	dataList:[
		{
			coin:100,
			create_time:12321321,--时间戳
			status: 0, --0:待处理, 1:处理中, 2:已处理完毕
		},
		...
	]
}
```

