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
use UCloud\UCDN\Models\HttpCodeInfoV2;
use UCloud\UCDN\Models\HttpCodeV2Detail;
use UCloud\UCDN\Models\HttpCodeV2Detail;
use UCloud\UCDN\Models\HttpCodeV2Detail;
use UCloud\UCDN\Models\HttpCodeV2Detail;
use UCloud\UCDN\Models\HttpCodeV2Detail;
use UCloud\UCDN\Models\HttpCodeV2Detail;

class GetUcdnDomainHttpCodeV2Response extends Response
{
    

    /**
     * HttpCodeDetail: 状态码实例表。详细见HttpCodeInfoV2
     *
     * @return HttpCodeInfoV2[]|null
     */
    public function getHttpCodeDetail()
    {
        $items = $this->get("HttpCodeDetail");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new HttpCodeInfoV2($item));
        }
        return $result;
    }

    /**
     * HttpCodeDetail: 状态码实例表。详细见HttpCodeInfoV2
     *
     * @param HttpCodeInfoV2[] $httpCodeDetail
     */
    public function setHttpCodeDetail(array $httpCodeDetail)
    {
        $result = [];
        foreach ($httpCodeDetail as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
