<?php
declare(strict_types=1);
date_default_timezone_set('UTC');

function config(): array {
    static $config;
    if ($config === null) {
        $config = require __DIR__ . '/config.example.php';
        if (is_file(__DIR__ . '/config.local.php')) {
            $config = array_replace($config, require __DIR__ . '/config.local.php');
        }
        foreach (['host', 'port', 'database', 'username', 'password'] as $key) {
            $value = getenv('ERRANDLY_DB_' . strtoupper($key));
            if ($value !== false) $config[$key] = $value;
        }
        if (getenv('ERRANDLY_DEMO') !== false) $config['demo'] = getenv('ERRANDLY_DEMO') === '1';
        if (getenv('ERRANDLY_SUPPORT_USERS') !== false) $config['support_users'] = array_filter(array_map('trim',explode(',',getenv('ERRANDLY_SUPPORT_USERS'))));
    }
    return $config;
}
function db(bool $withDatabase = true): PDO {
    $c = config();
    $db = new PDO('mysql:host=' . $c['host'] . ';port=' . $c['port'] .
        ($withDatabase ? ';dbname=' . $c['database'] : '') . ';charset=utf8mb4',
        $c['username'], $c['password'], [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES => false]);
    $db->exec("SET time_zone = '+00:00'");
    return $db;
}
function query(PDO $db, string $sql, array $params = []): PDOStatement {
    $q = $db->prepare($sql);
    $q->execute($params);
    return $q;
}
function fail(string $message, int $status = 422): never {
    throw new ApiError($message, $status);
}
class ApiError extends RuntimeException {
    public function __construct(string $message, public int $status = 422, public bool $persist = false) { parent::__construct($message); }
}
function textField(array $data, string $key, int $max = 500, bool $optional = false): string {
    $v = $data[$key] ?? '';
    if (!is_string($v)) fail('Invalid ' . $key . '.');
    $v = trim($v);
    if ((!$optional && $v === '') || mb_strlen($v) > $max) fail('Check ' . $key . '.');
    return $v;
}
function amount(array $data, string $key, float $minimum = 0): float {
    $value = $data[$key] ?? null;
    if (!is_numeric($value) || !is_finite((float)$value) || (float)$value < $minimum || (float)$value > 1000000) fail('Invalid ' . $key . '.');
    return round((float)$value, 2);
}
function iso(?string $value): ?string { return $value === null ? null : str_replace(' ', 'T', $value) . 'Z'; }
function ledger(PDO $db, string $user, string $type, float $value, string $note, ?string $errand = null, string $currency = 'CY', ?float $pesos = null): void {
    query($db, 'INSERT INTO wallet_entries(user_id,errand_id,type,amount,note,currency,peso_amount) VALUES(?,?,?,?,?,?,?)', [$user,$errand,$type,$value,$note,$currency,$pesos]);
}
function notice(PDO $db, string $user, string $type, string $text, ?string $errand = null): void {
    query($db, 'INSERT INTO notifications(user_id,errand_id,type,text) VALUES(?,?,?,?)', [$user,$errand,$type,$text]);
}
function walletLocks(PDO $db, array $users): void {
    $users = array_unique($users); sort($users);
    foreach ($users as $id) query($db, 'SELECT user_id FROM wallets WHERE user_id=? FOR UPDATE', [$id])->fetch();
}
function history(PDO $db, string $id, int $step): void {
    query($db, 'INSERT INTO errand_progress(errand_id,step) VALUES(?,?)', [$id,$step]);
}
function refund(PDO $db, array $e, string $status): void {
    walletLocks($db, [$e['owner_id']]);
    $pesoPurchase = $e['budget_currency'] === 'PHP';
    $total = ($pesoPurchase ? 0 : (float)$e['budget']) + (float)$e['fee'] + (float)$e['service_fee'];
    query($db, 'UPDATE errands SET status=? WHERE id=?', [$status,$e['id']]);
    query($db, 'UPDATE wallets SET available=available+?, refunds=refunds+? WHERE user_id=?', [$total,$total,$e['owner_id']]);
    ledger($db, $e['owner_id'], 'Refund', $total, $e['title'] . ' • ' . $status, $e['id']);
    if ($pesoPurchase && (float)$e['budget'] > 0) {
        ledger($db, $e['owner_id'], 'Refund', (float)$e['budget'], $e['title'] . ' • simulated peso refund • ' . $status, $e['id'], 'PHP');
    }
    notice($db, $e['owner_id'], 'Wallet', $e['title'] . ': ' . $status . '. Funds refunded.', $e['id']);
}
function expire(PDO $db): void {
    $rows = query($db, "SELECT * FROM errands WHERE status='posted' AND deadline<=UTC_TIMESTAMP(6) ORDER BY id FOR UPDATE")->fetchAll();
    foreach ($rows as $e) refund($db,$e,'expired');
}
function requireDemo(): void {
    if (!config()['demo']) fail('This simulation is disabled on this server.',403);
    if (PHP_SAPI !== 'cli' && !in_array($_SERVER['REMOTE_ADDR'] ?? '',['127.0.0.1','::1'],true)) fail('Demo actions are available only on this computer.',403);
}
function isSupportUser(string $user): bool {
    return in_array($user,config()['support_users'] ?? [],true);
}

function closeCancellationReports(PDO $db, string $id, string $status): void {
    query($db,"UPDATE reports SET status=? WHERE errand_id=? AND reason LIKE 'Cancellation request:%' AND status IN ('Submitted','Under Review')",[$status,$id]);
}

function settleCancellation(PDO $db, array $e, float $compensation, string $reviewer): void {
    walletLocks($db,[$e['owner_id'],$e['runner_id']]);
    $cost = $e['actual_cost'] === null ? 0.0 : (float)$e['actual_cost'];
    if ($cost > 0 && (!$e['receipt'] || !$e['item_photo'])) fail('Purchase proof must be reviewed before reimbursement.');
    $pesoPurchase = $e['budget_currency'] === 'PHP';
    $coins = round(($pesoPurchase ? 0 : (float)$e['budget']-$cost) + (float)$e['fee'] + (float)$e['service_fee'] - $compensation,2);
    $purchaseRefund = $pesoPurchase ? round((float)$e['budget']-$cost,2) : 0.0;
    query($db,"UPDATE errands SET status='cancelled',cancel_requested_by=NULL,cancel_requested_at=NULL,cancel_reviewed_by=?,cancel_refund_coins=?,cancel_refund_purchase=?,cancel_runner_payment=? WHERE id=?",[$reviewer,$coins,$purchaseRefund,$compensation,$e['id']]);
    query($db,'UPDATE wallets SET available=available+?,refunds=refunds+? WHERE user_id=?',[$coins,$coins,$e['owner_id']]);
    ledger($db,$e['owner_id'],'Refund',$coins,$e['title'] . ' • cancellation • reviewed by ' . $reviewer,$e['id']);
    if ($purchaseRefund > 0) ledger($db,$e['owner_id'],'Refund',$purchaseRefund,$e['title'] . ' • cancellation • simulated peso refund',$e['id'],'PHP');
    if ($cost > 0) {
        ledger($db,$e['owner_id'],'Purchase Budget',-$cost,$e['title'] . ' • cancellation • allocated from secured funds',$e['id'],$pesoPurchase ? 'PHP' : 'CY');
        if (!$pesoPurchase) query($db,'UPDATE wallets SET available=available+? WHERE user_id=?',[$cost,$e['runner_id']]);
        ledger($db,$e['runner_id'],'Purchase Reimbursement',$cost,$e['title'] . ' • cancellation • ' . ($pesoPurchase ? 'simulated peso transfer' : 'original secured coins'),$e['id'],$pesoPurchase ? 'PHP' : 'CY');
    }
    if ($compensation > 0) {
        query($db,'UPDATE wallets SET available=available+?,total_earnings=total_earnings+? WHERE user_id=?',[$compensation,$compensation,$e['runner_id']]);
        ledger($db,$e['runner_id'],'Runner Earnings',$compensation,$e['title'] . ' • cancellation compensation',$e['id']);
    }
    closeCancellationReports($db,$e['id'],'Resolved');
    foreach ([$e['owner_id'],$e['runner_id']] as $participant) notice($db,$participant,'Wallet',$e['title'] . ': cancellation resolved. See your refund/reimbursement in wallet history.',$e['id']);
}
function sessionToken(PDO $db, string $user): string {
    $token = bin2hex(random_bytes(32));
    query($db, 'DELETE FROM sessions WHERE expires_at<=UTC_TIMESTAMP()');
    query($db, 'INSERT INTO sessions(token_hash,user_id,expires_at) VALUES(?,?,DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 DAY))', [hash('sha256',$token),$user]);
    return $token;
}
function authorization(): string {
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('getallheaders')) {
        foreach (getallheaders() as $key=>$value) if (strtolower($key)==='authorization') return $value;
    }
    return $header;
}
function authenticate(PDO $db): string {
    $header = authorization();
    if (!preg_match('/^Bearer ([a-f0-9]{64})$/', $header, $m)) fail('Please log in.',401);
    $s = query($db, 'SELECT user_id FROM sessions WHERE token_hash=? AND expires_at>UTC_TIMESTAMP()', [hash('sha256',$m[1])])->fetch();
    if (!$s) fail('Your session expired. Please log in.',401);
    return $s['user_id'];
}
function snapshot(PDO $db, string $user): array {
    $profiles = [];
    $friends = query($db, "SELECT target_id FROM user_links WHERE user_id=? AND type='friend'",[$user])->fetchAll(PDO::FETCH_COLUMN);
    foreach (query($db, 'SELECT * FROM users ORDER BY created_at,id')->fetchAll() as $u) {
        $own = $u['id'] === $user;
        $isFriend = in_array($u['id'],$friends,true);
        $visible = fn($privacy) => $own || $privacy === 'Public' || ($privacy === 'Friends Only' && $isFriend);
        $profiles[] = ['id'=>$u['id'], 'name'=>$u['name'],
            'email'=>$visible($u['email_privacy']) ? $u['email'] : '',
            'phone'=>$visible($u['phone_privacy']) ? $u['phone'] : '',
            'bio'=>$u['bio'], 'location'=>$u['location'], 'rating'=>(float)$u['rating'],
            'completed'=>(int)$u['completed'], 'verified'=>(bool)$u['verified'],
            'emailVerified'=>$own && (bool)$u['email_verified'], 'phoneVerified'=>$own && (bool)$u['phone_verified'],
            'idVerified'=>$own && (bool)$u['id_verified'], 'photo'=>(bool)$u['photo'],
            'locationAllowed'=>$own && (bool)$u['location_allowed'], 'phonePrivacy'=>$u['phone_privacy'], 'emailPrivacy'=>$u['email_privacy']];
    }
    $proofs = [];
    foreach (query($db,'SELECT f.id,f.errand_id,f.kind,f.file_name,f.mime_type,f.byte_size,f.created_at FROM proof_files f JOIN errands e ON e.id=f.errand_id WHERE e.owner_id=? OR e.runner_id=? OR ?=1',[$user,$user,isSupportUser($user) ? 1 : 0])->fetchAll() as $f) {
        $proofs[$f['errand_id']][] = ['id'=>$f['id'],'kind'=>$f['kind'],'name'=>$f['file_name'],'mime'=>$f['mime_type'],'size'=>(int)$f['byte_size'],'date'=>iso($f['created_at'])];
    }
    $errands = [];
    foreach (query($db, 'SELECT * FROM errands ORDER BY posted_at DESC,id')->fetchAll() as $e) {
        $timeline = [];
        foreach (query($db, 'SELECT step,happened_at FROM errand_progress WHERE errand_id=? ORDER BY step',[$e['id']])->fetchAll() as $h) $timeline[(string)$h['step']] = iso($h['happened_at']);
        $participant = $e['owner_id'] === $user || $e['runner_id'] === $user || isSupportUser($user);
        $errands[] = ['id'=>$e['id'], 'ownerId'=>$e['owner_id'], 'runnerId'=>$e['runner_id'],
            'title'=>$e['title'], 'category'=>$e['category'], 'description'=>$e['description'],
            'pickup'=>$e['pickup'], 'destination'=>$e['destination'], 'area'=>$e['area'], 'transport'=>$e['transport'],
            'instructions'=>$e['instructions'], 'budget'=>(float)$e['budget'], 'budgetCurrency'=>$e['budget_currency'], 'fee'=>(float)$e['fee'],
            'distance'=>(float)$e['distance'], 'deadline'=>iso($e['deadline']), 'postedAt'=>iso($e['posted_at']),
            'pickupPoint'=>$e['pickup_lat']===null?null:['lat'=>(float)$e['pickup_lat'],'lon'=>(float)$e['pickup_lon']],
            'destinationPoint'=>$e['destination_lat']===null?null:['lat'=>(float)$e['destination_lat'],'lon'=>(float)$e['destination_lon']],
            'distanceSource'=>$e['distance_source'], 'routeSeconds'=>$e['route_seconds']===null?null:(float)$e['route_seconds'],
            'urgent'=>(bool)$e['urgent'], 'status'=>$e['status'], 'progress'=>(int)$e['progress'],
            'actualCost'=>$participant && $e['actual_cost'] !== null ? (float)$e['actual_cost'] : null,
            'receipt'=>$participant && (bool)$e['receipt'], 'itemPhoto'=>$participant && (bool)$e['item_photo'],
            'proofFiles'=>$participant ? ($proofs[$e['id']] ?? []) : [],
            'handoffVerified'=>$participant && (bool)$e['handoff_verified'], 'history'=>(object)$timeline,
            'pin'=>$e['owner_id'] === $user ? $e['completion_pin'] : null, 'cancellationReason'=>$e['cancellation_reason'],
            'pinAttempts'=>$participant ? (int)$e['pin_attempts'] : 0,
            'pinResetAt'=>$participant ? iso($e['pin_reset_at']) : null,
            'cancelRequestedBy'=>($participant || isSupportUser($user)) ? $e['cancel_requested_by'] : null,
            'cancelRefundCoins'=>$participant && $e['cancel_refund_coins'] !== null ? (float)$e['cancel_refund_coins'] : null,
            'cancelRefundPurchase'=>$participant && $e['cancel_refund_purchase'] !== null ? (float)$e['cancel_refund_purchase'] : null,
            'cancelRunnerPayment'=>$participant && $e['cancel_runner_payment'] !== null ? (float)$e['cancel_runner_payment'] : null];
    }
    $w = query($db, 'SELECT * FROM wallets WHERE user_id=?',[$user])->fetch();
    $entries = array_map(fn($r)=>['id'=>(string)$r['id'],'errandId'=>$r['errand_id'],'pesoAmount'=>$r['peso_amount']===null ? null : (float)$r['peso_amount'],'userId'=>$r['user_id'],'type'=>$r['type'],'amount'=>(float)$r['amount'],'currency'=>$r['currency'],'note'=>$r['note'],'status'=>$r['status'],'date'=>iso($r['created_at'])],
        query($db,'SELECT * FROM wallet_entries WHERE user_id=? ORDER BY id DESC',[$user])->fetchAll());
    $notices = array_map(fn($r)=>['id'=>(string)$r['id'],'userId'=>$r['user_id'],'type'=>$r['type'],'text'=>$r['text'],'errandId'=>$r['errand_id'],'read'=>(bool)$r['is_read'],'date'=>iso($r['created_at'])],
        query($db,'SELECT * FROM notifications WHERE user_id=? ORDER BY id DESC',[$user])->fetchAll());
    $messages = array_map(fn($r)=>['errandId'=>$r['errand_id'],'senderId'=>$r['sender_id'],'recipientId'=>$r['recipient_id'],'text'=>$r['text'],'date'=>iso($r['created_at'])],
        query($db,'SELECT m.* FROM messages m JOIN errands e ON e.id=m.errand_id WHERE (m.recipient_id IS NOT NULL AND (m.sender_id=? OR m.recipient_id=?)) OR (m.recipient_id IS NULL AND (e.owner_id=? OR e.runner_id=?)) ORDER BY m.id',[$user,$user,$user,$user])->fetchAll());
    $reviews = array_map(fn($r)=>['errandId'=>$r['errand_id'],'fromId'=>$r['from_id'],'toId'=>$r['to_id'],'stars'=>(int)$r['stars'],'text'=>$r['text'],'scores'=>json_decode($r['scores'],true)],
        query($db,'SELECT * FROM reviews ORDER BY id')->fetchAll());
    $reports = array_map(fn($r)=>['id'=>(string)$r['id'],'userId'=>$r['user_id'],'reason'=>$r['reason'],'description'=>$r['description'],'errandId'=>$r['errand_id'],'evidence'=>(bool)$r['evidence'],'status'=>$r['status']],
        query($db,'SELECT * FROM reports WHERE user_id=? ORDER BY id',[$user])->fetchAll());
    $links = ['friends'=>[],'favorites'=>[],'blocked'=>[]];
    foreach(query($db,'SELECT type,target_id FROM user_links WHERE user_id=?',[$user])->fetchAll() as $r) {
        $key = ['friend'=>'friends','favorite'=>'favorites','blocked'=>'blocked'][$r['type']]; $links[$key][] = $r['target_id'];
    }
    return array_merge(['currentId'=>$user, 'demo'=>config()['demo'], 'support'=>isSupportUser($user), 'users'=>$profiles,'errands'=>$errands,
        'wallet'=>['available'=>(float)$w['available'],'totalEarnings'=>(float)$w['total_earnings'],'refunds'=>(float)$w['refunds']],
        'transactions'=>$entries,'notifications'=>$notices,'messages'=>$messages,'reviews'=>$reviews,'reports'=>$reports,
        'saved'=>query($db,'SELECT errand_id FROM saved_errands WHERE user_id=?',[$user])->fetchAll(PDO::FETCH_COLUMN)],$links);
}
