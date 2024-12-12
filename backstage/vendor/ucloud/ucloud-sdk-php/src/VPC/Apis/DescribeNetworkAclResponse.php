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
use UCloud\VPC\Models\AclInfo;
use UCloud\VPC\Models\AclEntryInfo;
use UCloud\VPC\Models\TargetResourceInfo;
use UCloud\VPC\Models\AssociationInfo;

class DescribeNetworkAclResponse extends Response
{
    

    /**
     * AclList: ACL的信息，具体结构见下方AclInfo
     *
     * @return AclInfo[]|null
     */
    public function getAclList()
    {
        $items = $this->get("AclList");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new AclInfo($item));
        }
        return $result;
    }

    /**
     * AclList: ACL的信息，具体结构见下方AclInfo
     *
     * @param AclInfo[] $aclList
     */
    public function setAclList(array $aclList)
    {
        $result = [];
        foreach ($aclList as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
