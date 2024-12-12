<?php
namespace app\admin\utils;

class gameUtils {

    public static function waterLevelChange($waterLevel) {
        switch (intval($waterLevel)) {
            case 1:
              $waterLevel = 0;
              break;  
            case 2:
              $waterLevel = 5;
              break;
            case 3:
              $waterLevel = 10;
              break;
            case 4:
              $waterLevel = 15;
              break;
            case 5:
              $waterLevel = 20;
              break;
            case 6:
              $waterLevel = 25;
              break;
            case 7:
              $waterLevel = 30;
              break;
            case 8:
              $waterLevel = 35;
              break;
            case 9:
              $waterLevel = 40;
              break;
            case 10:
              $waterLevel = 50;
              break;
        }
        return $waterLevel;
    }

    public static function gameLevelChange($gameLevel) {
        switch (intval($gameLevel)) {
            case '1':
                $BigWinlevel = '0,0,1000';
                $BigWinluck = '0,0,100';
                  break;  
            case '2':
                $BigWinlevel = '0,0,800';
                $BigWinluck = '0,0,90';
                  break;
            case '3':
                $BigWinlevel = '0,0,700';
                $BigWinluck = '0,0,80';
                  break;
            case '4':
                $BigWinlevel = '0,0,600';
                $BigWinluck = '0,0,70';
                 break;
            case '5':
                $BigWinlevel = '0,0,400';
                $BigWinluck = '0,0,60';
                  break;
            case '6':
                $BigWinlevel = '0,0,300';
                $BigWinluck = '0,0,50';
              break;
            case '7':
                $BigWinlevel = '0,0,200';
                $BigWinluck = '0,0,40';
                  break;
            case '8':
                $BigWinlevel = '0,0,100';
                $BigWinluck = '0,0,30';
                  break;
            case '9':
                $BigWinlevel = '0,0,50';
                $BigWinluck = '0,0,20';
                  break;
            case '10':
                $BigWinlevel = '0,0,1';
                $BigWinluck = '0,0,10';
                  break;
        }
        return [$BigWinlevel, $BigWinluck];
    }
}
