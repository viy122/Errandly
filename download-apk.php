<?php
declare(strict_types=1);

// Fixed development artifact; never accept a client-supplied file path.
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if (!in_array($method, ['GET', 'HEAD'], true)) {
    http_response_code(405);
    header('Allow: GET, HEAD');
    exit;
}

$path = __DIR__ . '/build/app/outputs/flutter-apk/Errandly-Phone-Test.apk';
if (!is_file($path) || !is_readable($path)) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    exit('The test APK has not been built yet.');
}

header('Content-Type: application/vnd.android.package-archive');
header('Content-Disposition: attachment; filename="Errandly-Phone-Test.apk"');
header('Content-Length: ' . filesize($path));
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
if ($method === 'HEAD') exit;

set_time_limit(0);
readfile($path);
