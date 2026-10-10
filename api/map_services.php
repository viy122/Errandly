<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';

function mapPoint(mixed $value): ?array {
    if ($value === null) return null;
    if (!is_array($value)) fail('Invalid map pin.');
    foreach (['lat'=>90,'lon'=>180] as $key=>$limit) {
        if (!isset($value[$key]) || !is_numeric($value[$key]) || !is_finite((float)$value[$key]) || abs((float)$value[$key]) > $limit) fail('Invalid map pin.');
    }
    return ['lat'=>(float)$value['lat'],'lon'=>(float)$value['lon']];
}
function mapGetJson(string $url): array {
    $body = ''; $curl = curl_init($url);
    curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER=>false, CURLOPT_CONNECTTIMEOUT=>4, CURLOPT_TIMEOUT=>12,
        CURLOPT_FOLLOWLOCATION=>false, CURLOPT_PROTOCOLS=>CURLPROTO_HTTPS,
        CURLOPT_USERAGENT=>config()['maps_user_agent'], CURLOPT_HTTPHEADER=>['Accept: application/json'],
        CURLOPT_WRITEFUNCTION=>static function($handle,string $part) use (&$body): int {
            if (strlen($body)+strlen($part)>2000000) return 0;
            $body .= $part; return strlen($part);
        }]);
    $ok = curl_exec($curl); $status = curl_getinfo($curl,CURLINFO_RESPONSE_CODE); curl_close($curl);
    if ($ok === false || $status !== 200) fail('Map service is unavailable. Try again later or use a manual address and distance.',503);
    try { $result = json_decode($body,true,512,JSON_THROW_ON_ERROR); }
    catch (JsonException $e) { fail('Map service returned an invalid result. Try again later.',503); }
    if (!is_array($result)) fail('Map service returned an invalid result.',503);
    return $result;
}
function cachedMap(PDO $db,string $key): ?array {
    $value = query($db,'SELECT payload FROM map_cache WHERE cache_key=? AND expires_at>UTC_TIMESTAMP(6)',[$key])->fetchColumn();
    return $value === false ? null : json_decode($value,true,512,JSON_THROW_ON_ERROR);
}
function saveMapCache(PDO $db,string $key,array $value): void {
    query($db,'INSERT INTO map_cache(cache_key,payload,expires_at) VALUES(?,?,DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY)) ON DUPLICATE KEY UPDATE payload=VALUES(payload),expires_at=VALUES(expires_at)',[$key,json_encode($value,JSON_THROW_ON_ERROR)]);
}
function searchMapPlaces(PDO $db,string $term,?callable $fetch=null): array {
    $term = trim($term);
    if (mb_strlen($term)<3 || mb_strlen($term)>180) fail('Enter a place name between 3 and 180 characters.');
    $base = rtrim(config()['geocoding_url'],'/');
    $key = hash('sha256','place|'.$base.'|'.mb_strtolower($term));
    if (($cached=cachedMap($db,$key)) !== null) return $cached;
    $lock = 'errandly_nominatim';
    if (!query($db,'SELECT GET_LOCK(?,0)',[$lock])->fetchColumn()) fail('Another location search is running. Try again shortly.',429);
    try {
        // Global rate limit, including searches from different users. No autocomplete.
        $last = query($db,"SELECT TIMESTAMPDIFF(MICROSECOND,expires_at,UTC_TIMESTAMP(6)) FROM map_cache WHERE cache_key='geocoder_last_request'")->fetchColumn();
        if ($last !== false && (int)$last<1100000) fail('Please wait a moment before searching again.',429);
        query($db,"INSERT INTO map_cache(cache_key,payload,expires_at) VALUES('geocoder_last_request','{}',UTC_TIMESTAMP(6)) ON DUPLICATE KEY UPDATE expires_at=UTC_TIMESTAMP(6)");
        $json = ($fetch ?? 'mapGetJson')($base.'/search?'.http_build_query(['q'=>$term,'format'=>'jsonv2','limit'=>5,'addressdetails'=>0]));
        $places=[];
        foreach (array_slice($json,0,5) as $place) {
            $point=mapPoint(['lat'=>$place['lat']??null,'lon'=>$place['lon']??null]);
            $places[]=['label'=>mb_substr((string)($place['display_name']??$term),0,500),'point'=>$point];
        }
        $result=['places'=>$places]; saveMapCache($db,$key,$result); return $result;
    } finally { query($db,'SELECT RELEASE_LOCK(?)',[$lock]); }
}
function calculateRoadRoute(PDO $db,array $from,array $to,?callable $fetch=null): array {
    $from=mapPoint($from); $to=mapPoint($to);
    $base=rtrim(config()['routing_url'],'/');
    $coordinates=$from['lon'].','.$from['lat'].';'.$to['lon'].','.$to['lat'];
    $key=hash('sha256','route|'.$base.'|'.$coordinates);
    if (($cached=cachedMap($db,$key)) !== null) return $cached;
    $json=($fetch ?? 'mapGetJson')($base.'/route/v1/driving/'.$coordinates.'?overview=simplified&geometries=geojson&steps=false');
    if (($json['code']??'') !== 'Ok' || empty($json['routes'][0])) fail('No road route found between these pins. Choose different pins or enter a manual trip distance.',422);
    $route=$json['routes'][0]; $meters=$route['distance']??null; $seconds=$route['duration']??null;
    if (!is_numeric($meters) || !is_finite((float)$meters) || $meters<=0 || $meters>50000000 || !is_numeric($seconds) || !is_finite((float)$seconds) || $seconds<0) fail('Map service returned an invalid route.',503);
    $geometry=$route['geometry']['coordinates']??[];
    if (!is_array($geometry) || count($geometry)>10000 || count($geometry)<2) fail('Map service returned an invalid route.',503);
    $points=[];
    foreach ($geometry as $p) $points[]=mapPoint(['lat'=>$p[1]??null,'lon'=>$p[0]??null]);
    $result=['meters'=>(float)$meters,'seconds'=>(float)$seconds,'points'=>$points];
    saveMapCache($db,$key,$result); return $result;
}
