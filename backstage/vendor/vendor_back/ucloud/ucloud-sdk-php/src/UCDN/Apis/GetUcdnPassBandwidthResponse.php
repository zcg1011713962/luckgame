<?php
/**
 * Copyright 2021 UCloud Technology Co., Ltd.
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
namespace UCloud\UCDN\Apis;

use UCloud\Core\Response\Response;
use UCloud\UCDN\Models\BandwidthInfoDetail;

class GetUcdnPassBandwidthResponse extends Response
{
    

    /**
     * BandwidthDetail: 回源带宽数据
     *
     * @return BandwidthInfoDetail[]|null
     */
    public function getBandwidthDetail()
    {
        $items = $this->get("BandwidthDetail");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new BandwidthInfoDetail($item));
        }
        return $result;
    }

    /**
     * BandwidthDetail: 回源带宽数据
     *
     * @param BandwidthInfoDetail[] $bandwidthDetail
     */
    public function setBandwidthDetail(array $bandwidthDetail)
    {
        $result = [];
        foreach ($bandwidthDetail as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
