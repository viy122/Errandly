<?php
declare(strict_types=1);
if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../api/map_services.php';
try {
    $places=searchMapPlaces(db(),'Rizal Park, Manila');
    if(empty($places['places']))throw new RuntimeException('No public-landmark search results.');
    $route=calculateRoadRoute(db(),['lat'=>14.5995,'lon'=>120.9842],['lat'=>14.5831,'lon'=>120.9794]);
    echo json_encode(['search_results'=>count($places['places']),'first_place'=>$places['places'][0]['label'],'route_meters'=>$route['meters'],'route_seconds'=>$route['seconds'],'geometry_points'=>count($route['points'])],JSON_UNESCAPED_UNICODE)."\n";
}catch(Throwable $e){fwrite(STDERR,$e->getMessage()."\n");exit(1);}
