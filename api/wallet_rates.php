<?php
declare(strict_types=1);

const TOP_UP_PESOS = 100.0;
const TOP_UP_COINS = 110.0;
const CASH_OUT_COINS = 110.0;
const CASH_OUT_PESOS = 80.0;

function top_up_coins(float $pesos): float {
    return round($pesos * TOP_UP_COINS / TOP_UP_PESOS, 2);
}

function cash_out_pesos(float $coins): float {
    return round($coins * CASH_OUT_PESOS / CASH_OUT_COINS, 2);
}
