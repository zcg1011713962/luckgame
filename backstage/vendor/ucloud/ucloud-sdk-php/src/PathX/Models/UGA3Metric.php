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
namespace UCloud\PathX\Models;

use UCloud\Core\Response\Response;

class UGA3Metric extends Response
{
    

    /**
     * NetworkOut: 出向带宽
     *
     * @return MatricPoint[]|null
     */
    public function getNetworkOut()
    {
        $items = $this->get("NetworkOut");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * NetworkOut: 出向带宽
     *
     * @param MatricPoint[] $networkOut
     */
    public function setNetworkOut(array $networkOut)
    {
        $result = [];
        foreach ($networkOut as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * NetworkIn: 入向带宽
     *
     * @return MatricPoint[]|null
     */
    public function getNetworkIn()
    {
        $items = $this->get("NetworkIn");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * NetworkIn: 入向带宽
     *
     * @param MatricPoint[] $networkIn
     */
    public function setNetworkIn(array $networkIn)
    {
        $result = [];
        foreach ($networkIn as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * NetworkOutUsage: 出向带宽使用率
     *
     * @return MatricPoint[]|null
     */
    public function getNetworkOutUsage()
    {
        $items = $this->get("NetworkOutUsage");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * NetworkOutUsage: 出向带宽使用率
     *
     * @param MatricPoint[] $networkOutUsage
     */
    public function setNetworkOutUsage(array $networkOutUsage)
    {
        $result = [];
        foreach ($networkOutUsage as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * NetworkInUsage: 入向带宽使用率
     *
     * @return MatricPoint[]|null
     */
    public function getNetworkInUsage()
    {
        $items = $this->get("NetworkInUsage");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * NetworkInUsage: 入向带宽使用率
     *
     * @param MatricPoint[] $networkInUsage
     */
    public function setNetworkInUsage(array $networkInUsage)
    {
        $result = [];
        foreach ($networkInUsage as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * NetworkOutSubline: 子线路出口带宽
     *
     * @return MatricPoint[]|null
     */
    public function getNetworkOutSubline()
    {
        $items = $this->get("NetworkOutSubline");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * NetworkOutSubline: 子线路出口带宽
     *
     * @param MatricPoint[] $networkOutSubline
     */
    public function setNetworkOutSubline(array $networkOutSubline)
    {
        $result = [];
        foreach ($networkOutSubline as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * NetworkInSubline: 子线路入口带宽
     *
     * @return MatricPoint[]|null
     */
    public function getNetworkInSubline()
    {
        $items = $this->get("NetworkInSubline");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * NetworkInSubline: 子线路入口带宽
     *
     * @param MatricPoint[] $networkInSubline
     */
    public function setNetworkInSubline(array $networkInSubline)
    {
        $result = [];
        foreach ($networkInSubline as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * Delay: 线路平均延迟
     *
     * @return MatricPoint[]|null
     */
    public function getDelay()
    {
        $items = $this->get("Delay");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * Delay: 线路平均延迟
     *
     * @param MatricPoint[] $delay
     */
    public function setDelay(array $delay)
    {
        $result = [];
        foreach ($delay as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * DelaySubline: 子线路延迟
     *
     * @return MatricPoint[]|null
     */
    public function getDelaySubline()
    {
        $items = $this->get("DelaySubline");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * DelaySubline: 子线路延迟
     *
     * @param MatricPoint[] $delaySubline
     */
    public function setDelaySubline(array $delaySubline)
    {
        $result = [];
        foreach ($delaySubline as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * DelayPromote: 延迟提升
     *
     * @return MatricPoint[]|null
     */
    public function getDelayPromote()
    {
        $items = $this->get("DelayPromote");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * DelayPromote: 延迟提升
     *
     * @param MatricPoint[] $delayPromote
     */
    public function setDelayPromote(array $delayPromote)
    {
        $result = [];
        foreach ($delayPromote as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * DelayPromoteSubline: 子线路延迟提升
     *
     * @return MatricPoint[]|null
     */
    public function getDelayPromoteSubline()
    {
        $items = $this->get("DelayPromoteSubline");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * DelayPromoteSubline: 子线路延迟提升
     *
     * @param MatricPoint[] $delayPromoteSubline
     */
    public function setDelayPromoteSubline(array $delayPromoteSubline)
    {
        $result = [];
        foreach ($delayPromoteSubline as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * ConnectCount: 当前连接数
     *
     * @return MatricPoint[]|null
     */
    public function getConnectCount()
    {
        $items = $this->get("ConnectCount");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * ConnectCount: 当前连接数
     *
     * @param MatricPoint[] $connectCount
     */
    public function setConnectCount(array $connectCount)
    {
        $result = [];
        foreach ($connectCount as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }

    /**
     * ConnectCountSubline: 子线路当前连接数
     *
     * @return MatricPoint[]|null
     */
    public function getConnectCountSubline()
    {
        $items = $this->get("ConnectCountSubline");
        if ($items == null) {
            return [];
        }
        $result = [];
        foreach ($items as $i => $item) {
            array_push($result, new MatricPoint($item));
        }
        return $result;
    }

    /**
     * ConnectCountSubline: 子线路当前连接数
     *
     * @param MatricPoint[] $connectCountSubline
     */
    public function setConnectCountSubline(array $connectCountSubline)
    {
        $result = [];
        foreach ($connectCountSubline as $i => $item) {
            array_push($result, $item->getAll());
        }
        return $result;
    }
}
