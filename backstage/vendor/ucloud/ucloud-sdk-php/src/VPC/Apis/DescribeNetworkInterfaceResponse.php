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
namespace UCloud\VPC\Apis;

use UCloud\Core\Response\Response;
use UCloud\VPC\Models\NetworkInterface;
use UCloud\VPC\Models\UNIIpInfo;
use UCloud\VPC\Models\UNIQuotaInfo;

class DescribeNetworkInterfaceResponse extends Response
{
    

    /**
     * NetworkInterfaceSet: 虚拟网卡信息
     *
     * @return NetworkInterface[]|null
     */
    public function getNetworkInterfaceSet()
    {
        $items = $this->get("NetworkInterfaceSet");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new NetworkInterface($item));
        }
        return $result;
    }

    /**
     * NetworkInterfaceSet: 虚拟网卡信息
     *
     * @param NetworkInterface[] $networkInterfaceSet
     */
    public function setNetworkInterfaceSet(array $networkInterfaceSet)
    {
        $result = [];
        foreach ($networkInterfaceSet as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * TotalCount: 虚拟网卡总数
     *
     * @return integer|null
     */
    public function getTotalCount()
    {
        return $this->get("TotalCount");
    }

    /**
     * TotalCount: 虚拟网卡总数
     *
     * @param int $totalCount
     */
    public function setTotalCount($totalCount)
    {
        $this->set("TotalCount", $totalCount);
    }
}
