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
namespace UCloud\ULB\Apis;

use UCloud\Core\Response\Response;
use UCloud\ULB\Models\ULBSet;
use UCloud\ULB\Models\ULBIPSet;
use UCloud\ULB\Models\ULBVServerSet;
use UCloud\ULB\Models\ULBSSLSet;
use UCloud\ULB\Models\SSLBindedTargetSet;
use UCloud\ULB\Models\ULBBackendSet;
use UCloud\ULB\Models\ULBPolicySet;
use UCloud\ULB\Models\PolicyBackendSet;
use UCloud\ULB\Models\FirewallSet;
use UCloud\ULB\Models\LoggerSet;

class DescribeULBResponse extends Response
{
    

    /**
     * TotalCount: 满足条件的ULB总数
     *
     * @return integer|null
     */
    public function getTotalCount()
    {
        return $this->get("TotalCount");
    }

    /**
     * TotalCount: 满足条件的ULB总数
     *
     * @param int $totalCount
     */
    public function setTotalCount($totalCount)
    {
        $this->set("TotalCount", $totalCount);
    }

    /**
     * DataSet: ULB列表，每项参数详见 ULBSet
     *
     * @return ULBSet[]|null
     */
    public function getDataSet()
    {
        $items = $this->get("DataSet");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new ULBSet($item));
        }
        return $result;
    }

    /**
     * DataSet: ULB列表，每项参数详见 ULBSet
     *
     * @param ULBSet[] $dataSet
     */
    public function setDataSet(array $dataSet)
    {
        $result = [];
        foreach ($dataSet as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
