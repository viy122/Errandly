<?php
declare(strict_types=1);
ini_set('display_errors','0'); // API responses stay JSON; diagnostics go to the PHP log.
require_once __DIR__ . '/commands.php';
require_once __DIR__ . '/map_services.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
if ($origin !== '') {
    if (!in_array($origin,config()['origins'],true)) {
        http_response_code(403); echo json_encode(['error'=>'This origin is not allowed.']); exit;
    }
    header('Access-Control-Allow-Origin: ' . $origin);
    header('Vary: Origin');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
}
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
$db = null;
try {
    $method = $_SERVER['REQUEST_METHOD'];
    if (!in_array($method,['GET','POST'],true)) fail('Method not allowed.',405);
    $multipart = str_starts_with(strtolower($_SERVER['CONTENT_TYPE'] ?? ''),'multipart/form-data');
    if ($multipart) {
        if ((int)($_SERVER['CONTENT_LENGTH'] ?? 0) > 5 * 1024 * 1024 || !isset($_POST['action'])) fail('Upload is too large or interrupted. Choose images up to 2 MB each.',413);
        $data = $_POST;
        if (!in_array($data['action'],['proof','deliveryProof'],true)) fail('Invalid upload action.');
    } else {
        $raw = file_get_contents('php://input');
        if (strlen($raw) > 100000) fail('Request is too large.',413);
        $data = $raw === '' ? [] : json_decode($raw,true,512,JSON_THROW_ON_ERROR);
    }
    if (!is_array($data)) fail('Invalid JSON.');
    $action = $_GET['action'] ?? $data['action'] ?? 'state';
    $db = db();
    if ($action === 'health') {
        echo json_encode(['ok'=>true,'storage'=>'mysql','database'=>config()['database'],'demo'=>config()['demo']]); exit;
    }
    if ($action === 'proofFile') {
        if ($method !== 'GET') fail('Use GET for proof images.',405);
        $file = privateProofFile($db,authenticate($db),textField($_GET,'id',32));
        header('Content-Type: ' . $file['mime_type']);
        header('Content-Length: ' . $file['byte_size']);
        header('Content-Disposition: inline; filename="proof.' . ['image/jpeg'=>'jpg','image/png'=>'png','image/webp'=>'webp'][$file['mime_type']] . '"');
        echo $file['payload']; exit;
    }
    if ($action !== 'state' && $method !== 'POST') fail('Use POST for this action.',405);
    if (in_array($action,['placeSearch','roadRoute'],true)) {
        authenticate($db);
        $result = $action === 'placeSearch'
            ? searchMapPlaces($db,textField($data,'query',180))
            : calculateRoadRoute($db,mapPoint($data['from']??null) ?? throw new ApiError('Choose a pickup pin.'),mapPoint($data['to']??null) ?? throw new ApiError('Choose a drop-off pin.'));
        echo json_encode($result,JSON_UNESCAPED_UNICODE|JSON_THROW_ON_ERROR); exit;
    }
    $db->beginTransaction();
    $token = null;
    if ($action === 'login') {
        $email = strtolower(textField($data,'email',254));
        $u = query($db,'SELECT id,password_hash FROM users WHERE email=?',[$email])->fetch();
        if (!$u || !password_verify(textField($data,'password',128),$u['password_hash'])) fail('Email or password is incorrect.',401);
        $user = $u['id']; $token = sessionToken($db,$user);
    } elseif ($action === 'register') {
        $p = $data['profile'] ?? [];
        $email = strtolower(textField($p,'email',254)); $password = textField($data,'password',128);
        $phone = textField($p,'phone',24);
        if (!filter_var($email,FILTER_VALIDATE_EMAIL) || !preg_match('/^\+?\d{7,15}$/',$phone) || strlen($password)<6 || strlen($password)>72) fail('Check email, phone and password (6–72 characters).');
        if (query($db,'SELECT id FROM users WHERE email=?',[$email])->fetch()) fail('This email already has an account.',409);
        $user = 'u' . bin2hex(random_bytes(16));
        query($db,'INSERT INTO users(id,email,password_hash,name,phone,location,bio,photo) VALUES(?,?,?,?,?,?,?,?)',
            [$user,$email,password_hash($password,PASSWORD_DEFAULT),textField($p,'name',120),$phone,textField($p,'location',255),textField($p,'bio',5000,true),!empty($p['photo']) ? 1 : 0]);
        query($db,'INSERT INTO wallets(user_id) VALUES(?)',[$user]);
        $token = sessionToken($db,$user);
    } elseif ($action === 'demo') {
        requireDemo();
        $user = textField($data,'userId',64);
        if (!in_array($user,['ben','anna','maria','joshua'],true)) fail('Choose a demo account.');
        if (!query($db,'SELECT id FROM users WHERE id=?',[$user])->fetch()) fail('Run the CLI demo seed first.',503);
        $token = sessionToken($db,$user);
    } else {
        $user = authenticate($db);
        if ($action === 'logout') {
            query($db,'DELETE FROM sessions WHERE token_hash=?',[hash('sha256',substr(authorization(),7))]);
            $db->commit(); echo json_encode(['ok'=>true]); exit;
        }
    }
    expire($db);
    if (!in_array($action,['state','login','register','demo'],true)) command($db,$user,$action,$data,$multipart ? incomingProofFiles() : []);
    $state = snapshot($db,$user);
    $db->commit();
    echo json_encode(['state'=>$state,'token'=>$token],JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
} catch (ApiError $error) {
    if ($db && $db->inTransaction()) { $error->persist ? $db->commit() : $db->rollBack(); }
    http_response_code($error->status); echo json_encode(['error'=>$error->getMessage()]);
} catch (JsonException $error) {
    if ($db && $db->inTransaction()) $db->rollBack();
    http_response_code(400); echo json_encode(['error'=>'Invalid JSON request.']);
} catch (Throwable $error) {
    if ($db && $db->inTransaction()) $db->rollBack();
    error_log('Errandly API: ' . $error->getMessage());
    http_response_code(503); echo json_encode(['error'=>'Database service unavailable. Check MySQL and run api/setup.php.']);
}
