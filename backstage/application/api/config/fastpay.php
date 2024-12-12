<?php
return [
    'fastpay' => [
        'mer_no' => '',
        'key' => '',
        'returnurl' => '',
        'gateway' => 'http://www.fast-pay.cc/gateway.aspx',
        'currency' => 'BRL',
        'paytypecode' => '18001',
        'payment' => 'payment',
        'payout' => 'payout',
    ],
    'kppay' => [
        'merchantId' => '',
        'key' => '',
        'notifyUrl' => '',
        'payment_gateway' => 'https://pp.kppay.live/api/version1/pay',
        'payout_gateway' => 'https://pp.kppay.live/api/version1/payout',
        'payType' => 'PIX',
        'payment' => 'payment',
        'payout' => 'payout',
    ]
];