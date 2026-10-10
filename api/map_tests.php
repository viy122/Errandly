<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__.'/commands.php';
function mapsCheck(bool $ok,string $message):void { if(!$ok)throw new RuntimeException($message); }
function mapsReject(callable $action):void { try{$action();}catch(ApiError $e){return;}throw new RuntimeException('Expected invalid map input to fail.'); }
$db=db();$db->beginTransaction();
try {
    mapsReject(fn()=>mapPoint(['lat'=>91,'lon'=>0]));
    mapsReject(fn()=>mapPoint(['lat'=>0]));
    mapsReject(fn()=>mapPoint(['lat'=>INF,'lon'=>0]));
    mapsReject(fn()=>searchMapPlaces($db,'ab'));
    $name='QA map search '.bin2hex(random_bytes(6));$calls=0;
    query($db,"DELETE FROM map_cache WHERE cache_key='geocoder_last_request'");
    $fetch=function(string $url)use(&$calls):array{$calls++;mapsCheck(str_contains($url,'format=jsonv2'),'Explicit geocode search must request JSON.');return [['lat'=>'14.5995','lon'=>'120.9842','display_name'=>'Manila test landmark']];};
    $places=searchMapPlaces($db,$name,$fetch);
    mapsCheck($places['places'][0]['point']['lat']===14.5995,'Geocode result must have actual coordinates.');
    mapsCheck(searchMapPlaces($db,$name,$fetch)===$places && $calls===1,'Repeated search must use cache.');
    mapsReject(fn()=>searchMapPlaces($db,$name.' second',$fetch));
    $from=['lat'=>14.5995,'lon'=>120.9842];$to=['lat'=>14.5831,'lon'=>120.9794];
    $routeKey=hash('sha256','route|'.rtrim(config()['routing_url'],'/').'|120.9842,14.5995;120.9794,14.5831');
    query($db,'DELETE FROM map_cache WHERE cache_key=?',[$routeKey]);
    $routeCalls=0;
    $route=calculateRoadRoute($db,$from,$to,function(string $url)use(&$routeCalls):array{$routeCalls++;mapsCheck(str_contains($url,'120.9842,14.5995;120.9794,14.5831'),'OSRM expects longitude then latitude.');return ['code'=>'Ok','routes'=>[['distance'=>2345.6,'duration'=>500,'geometry'=>['coordinates'=>[[120.9842,14.5995],[120.9794,14.5831]]]]]];});
    calculateRoadRoute($db,$from,$to,fn()=>throw new RuntimeException('Cached route should not make another request.'));
    mapsCheck($routeCalls===1 && $route['meters']===2345.6 && $route['points'][1]===$to,'Route must preserve measured meters and geometry.');
    mapsReject(fn()=>calculateRoadRoute($db,['lat'=>0,'lon'=>0],['lat'=>1,'lon'=>1],fn()=>['code'=>'NoRoute']));
    $id='test_maps_'.bin2hex(random_bytes(8));
    $post=['errand'=>['id'=>$id,'title'=>'Map persistence test','category'=>'Delivery','description'=>'Rolled-back map test.','pickup'=>'Test public landmark','destination'=>'Test public destination','area'=>'Manila','transport'=>'Car','instructions'=>'Test only','budget'=>0,'fee'=>40,'distance'=>2345.6,'deadline'=>gmdate('c',time()+86400),'urgent'=>false,'pickupPoint'=>$from,'destinationPoint'=>$to,'distanceSource'=>'osrm_driving','routeSeconds'=>500],'method'=>'Errandly Wallet'];
    command($db,'anna','post',$post);
    $balance=(float)query($db,'SELECT available FROM wallets WHERE user_id=?',['anna'])->fetchColumn();
    command($db,'anna','post',$post);
    mapsCheck((float)query($db,'SELECT available FROM wallets WHERE user_id=?',['anna'])->fetchColumn()===$balance,'Retry must not secure funds twice.');
    $task=array_values(array_filter(snapshot($db,'ben')['errands'],fn($e)=>$e['id']===$id))[0];
    mapsCheck($task['pickupPoint']===$from && $task['destinationPoint']===$to && $task['distanceSource']==='osrm_driving' && $task['routeSeconds']===500.0,'Map fields must survive a fresh participant snapshot.');
    $changed=$post;$changed['errand']['pickupPoint']['lat']=15;
    mapsReject(fn()=>command($db,'anna','post',$changed));
    $invalid=$post;$invalid['errand']['id'].='_invalid';$invalid['errand']['pickupPoint']=null;
    mapsReject(fn()=>command($db,'anna','post',$invalid));
    $db->rollBack();echo "PASS: pin validation, explicit search/cache/global throttling, OSRM geometry/units, no-route errors, persisted map fields and idempotent posting. Test data rolled back.\n";
}catch(Throwable $e){if($db->inTransaction())$db->rollBack();fwrite(STDERR,$e->getMessage()."\n");exit(1);}
