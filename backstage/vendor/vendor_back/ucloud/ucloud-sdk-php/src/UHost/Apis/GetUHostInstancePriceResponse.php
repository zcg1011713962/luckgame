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
namespace UCloud\UHost\Apis;

use UCloud\Core\Response\Response;
use UCloud\UHost\Models\UHostPriceSet;

class GetUHostInstancePriceResponse extends Response
{
    

    /**
     * PriceSet: 价格列表 UHostPriceSet
     *
     * @return UHostPriceSet[]|null
     */
    public function getPriceSet()
    {
        $items = $this->get("PriceSet");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new UHostPriceSet($item));
        }
        return $result;
    }

    /**
     * PriceSet: 价格列表 UHostPriceSet
     *
     * @param UHostPriceSet[] $priceSet
     */
    public function setPriceSet(array $priceSet)
    {
        $result = [];
        foreach ($priceSet as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
