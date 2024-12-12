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
namespace UCloud\UCDN\Models;

use UCloud\Core\Response\Response;

class LogSetList extends Response
{
    

    /**
     * Domain: 域名
     *
     * @return string|null
     */
    public function getDomain()
    {
        return $this->get("Domain");
    }

    /**
     * Domain: 域名
     *
     * @param string $domain
     */
    public function setDomain($domain)
    {
        $this->set("Domain", $domain);
    }

    /**
     * Logs: 域名信息列表，参考LogSetInfo
     *
     * @return LogSetInfo[]|null
     */
    public function getLogs()
    {
        $items = $this->get("Logs");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new LogSetInfo($item));
        }
        return $result;
    }

    /**
     * Logs: 域名信息列表，参考LogSetInfo
     *
     * @param LogSetInfo[] $logs
     */
    public function setLogs(array $logs)
    {
        $result = [];
        foreach ($logs as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
