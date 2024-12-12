<?php
/**
 * Copyright 2022 UCloud Technology Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
namespace UCloud\Cube\Apis;

use UCloud\Core\Response\Response;

class GetCubeExecTokenResponse extends Response
{
    

    /**
     * Token: 有效时间5min
     *
     * @return string|null
     */
    public function getToken()
    {
        return $this->get("Token");
    }

    /**
     * Token: 有效时间5min
     *
     * @param string $token
     */
    public function setToken($token)
    {
        $this->set("Token", $token);
    }

    /**
     * TerminalUrl: terminal的登录连接地址，限单点登录，有效时间5min
     *
     * @return string|null
     */
    public function getTerminalUrl()
    {
        return $this->get("TerminalUrl");
    }

    /**
     * TerminalUrl: terminal的登录连接地址，限单点登录，有效时间5min
     *
     * @param string $terminalUrl
     */
    public function setTerminalUrl($terminalUrl)
    {
        $this->set("TerminalUrl", $terminalUrl);
    }
}
