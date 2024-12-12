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
namespace UCloud\UFile\Apis;

use UCloud\Core\Response\Response;
use UCloud\UFile\Models\UFileBucketSet;
use UCloud\UFile\Models\UFileDomainSet;

class DescribeBucketResponse extends Response
{
    

    /**
     * DataSet: Bucket的描述信息 参数见 UFileBucketSet
     *
     * @return UFileBucketSet[]|null
     */
    public function getDataSet()
    {
        $items = $this->get("DataSet");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new UFileBucketSet($item));
        }
        return $result;
    }

    /**
     * DataSet: Bucket的描述信息 参数见 UFileBucketSet
     *
     * @param UFileBucketSet[] $dataSet
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
