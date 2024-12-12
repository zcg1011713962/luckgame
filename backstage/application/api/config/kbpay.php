<?php

return [
    'merchant_no' => '', // 商户号
    'order_no' => '', //订单号
    'order_amount' => '', //交易金额
    'notify_url' => '', // 回调地址
    'timestamp' => time(), // 时间戳
    'sign' => '', // 签名
    'payin_key' => '', // 代收密钥
    'payout_key' => '', // 代付密钥
    'sandbox' => 'https://api.kbpay.io/sandbox/payin/submit', // 沙盒地址
    'payment_url' => 'https://api.kbpay.io/payin/submit',
    'payin_method' => ['1127','1089']
];