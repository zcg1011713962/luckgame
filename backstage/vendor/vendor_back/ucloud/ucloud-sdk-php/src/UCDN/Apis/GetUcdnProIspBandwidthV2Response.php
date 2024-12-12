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
namespace UCloud\UCDN\Apis;

use UCloud\Core\Response\Response;
use UCloud\UCDN\Models\ProIspBandwidthSet;
use UCloud\UCDN\Models\ProIspBandwidthList;

class GetUcdnProIspBandwidthV2Response extends Response
{
    

    /**
     * BandwidthSet: 按省份的带宽流量实例表。具体参考下面BandwidthSet
     *
     * @return ProIspBandwidthSet[]|null
     */
    public function getBandwidthSet()
    {
        $items = $this->get("BandwidthSet");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new ProIspBandwidthSet($item));
        }
        return $result;
    }

    /**
     * BandwidthSet: 按省份的带宽流量实例表。具体参考下面BandwidthSet
     *
     * @param ProIspBandwidthSet[] $bandwidthSet
     */
    public function setBandwidthSet(array $bandwidthSet)
    {
        $result = [];
        foreach ($bandwidthSet as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
