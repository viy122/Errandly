<?php
declare(strict_types=1);
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/wallet_rates.php';
require_once __DIR__ . '/proof_files.php';
require_once __DIR__ . '/map_services.php';

function command(PDO $db, string $user, string $action, array $data, array $files = []): void {
    $profile = query($db,'SELECT * FROM users WHERE id=?',[$user])->fetch();
    $id = isset($data['errandId']) ? textField($data,'errandId',64) : null;
    $e = $id ? query($db,'SELECT * FROM errands WHERE id=? FOR UPDATE',[$id])->fetch() : null;
    if ($id && !$e) fail('Errand not found.',404);
    $owner = $e && $e['owner_id'] === $user;
    $runner = $e && $e['runner_id'] === $user;
    $terminal = $e && in_array($e['status'],['completed','cancelled','expired'],true);
    if ($e && $e['cancel_requested_by'] && in_array($action,['advance','proof','deliveryProof','pin','complete','resetPin'],true)) fail('Resolve or withdraw the cancellation request before continuing.',409);
    if ($action === 'post') {
        if (!$profile['verified']) fail('Verify your account before posting.',403);
        $p = $data['errand'] ?? [];
        $postId = textField($p,'id',64);
        $pickupPoint=mapPoint($p['pickupPoint']??null);
        $destinationPoint=mapPoint($p['destinationPoint']??null);
        $distanceSource=$p['distanceSource']??'manual';
        if (!in_array($distanceSource,['manual','osrm_driving'],true)) fail('Invalid trip distance source.');
        $routeSeconds=$p['routeSeconds']??null;
        if ($distanceSource === 'osrm_driving' && (!$pickupPoint || !$destinationPoint || !is_numeric($routeSeconds) || !is_finite((float)$routeSeconds) || $routeSeconds<0)) fail('Calculate a route for both map pins.');
        if ($distanceSource === 'manual') $routeSeconds=null;
        $existing = query($db,'SELECT * FROM errands WHERE id=?',[$postId])->fetch();
        if ($existing) {
            if ($existing['owner_id'] !== $user) fail('This draft reference is unavailable.',409);
            foreach (['title','category','description','pickup','destination','area','transport','instructions'] as $field) {
                if ((string)($p[$field] ?? '') !== (string)$existing[$field]) fail('This draft was already published. Open the existing errand or start a new draft.',409);
            }
            foreach (['budget','fee'] as $field) if (amount($p,$field) !== (float)$existing[$field]) fail('This draft was already published with different amounts.',409);
            if (!is_numeric($p['distance'] ?? null) || (float)$p['distance'] !== (float)$existing['distance']) fail('This draft was already published with a different distance.',409);
            foreach (['pickup_lat'=>$pickupPoint['lat']??null,'pickup_lon'=>$pickupPoint['lon']??null,'destination_lat'=>$destinationPoint['lat']??null,'destination_lon'=>$destinationPoint['lon']??null,'route_seconds'=>$routeSeconds] as $column=>$v) {
                if (($v === null) !== ($existing[$column] === null) || ($v !== null && (float)$v !== (float)$existing[$column])) fail('This draft was already published with different map pins or route.',409);
            }
            if ($distanceSource !== $existing['distance_source']) fail('This draft was already published with a different trip source.',409);
            try { $retryDeadline = new DateTimeImmutable(textField($p,'deadline',50)); } catch (Exception $ex) { fail('Invalid draft deadline.'); }
            if ($retryDeadline->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s.u') !== $existing['deadline'] || !empty($p['urgent']) !== (bool)$existing['urgent'] || ($data['method'] ?? '') !== $existing['payment_method'] || ($data['budgetMethod'] ?? 'GCash Simulation') !== $existing['budget_method']) fail('This draft was already published with different terms.',409);
            return; // Successful retry; never secure funds a second time.
        }
        $budget = amount($p,'budget'); $fee = amount($p,'fee',0.01);
        $distance = $p['distance'] ?? 0;
        if (!is_numeric($distance) || !is_finite((float)$distance) || $distance <= 0 || $distance > 50000000) fail('Invalid distance.');
        try { $deadline = new DateTimeImmutable(textField($p,'deadline',50)); } catch (Exception $ex) { fail('Choose a future deadline.'); }
        if ($deadline->getTimestamp() <= time()) fail('Choose a future deadline.');
        $method = textField($data,'method',60);
        if (!in_array($method,['Errandly Wallet','GCash Simulation','Debit / Card Simulation'],true)) fail('Invalid payment method.');
        if ($method !== 'Errandly Wallet') requireDemo();
        $budgetMethod = textField(['budgetMethod'=>$data['budgetMethod'] ?? 'GCash Simulation'],'budgetMethod',60);
        if (!in_array($budgetMethod,['GCash Simulation','Debit / Card Simulation'],true)) fail('Choose a peso purchase-budget payment method.');
        if ($budget > 0) requireDemo();
        $total = $fee + 5;
        walletLocks($db,[$user]);
        if ($method === 'Errandly Wallet') {
            $balance = query($db,'SELECT available FROM wallets WHERE user_id=?',[$user])->fetchColumn();
            if ((float)$balance < $total) fail('Not enough coins. Top up or choose a simulated payment.');
            query($db,'UPDATE wallets SET available=available-? WHERE user_id=?',[$total,$user]);
        }
        $id = textField($p,'id',64);
        query($db,'INSERT INTO errands(id,owner_id,title,category,description,pickup,destination,area,transport,instructions,budget,budget_currency,budget_method,fee,distance,deadline,urgent,payment_method) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
            [$id,$user,textField($p,'title',160),textField($p,'category',60),textField($p,'description',10000),textField($p,'pickup'),textField($p,'destination'),textField($p,'area',255),textField($p,'transport',60),textField($p,'instructions',10000,true),$budget,'PHP',$budgetMethod,$fee,$distance,$deadline->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s.u'),!empty($p['urgent']) ? 1 : 0,$method]);
        query($db,'UPDATE errands SET pickup_lat=?,pickup_lon=?,destination_lat=?,destination_lon=?,distance_source=?,route_seconds=? WHERE id=?',[$pickupPoint['lat']??null,$pickupPoint['lon']??null,$destinationPoint['lat']??null,$destinationPoint['lon']??null,$distanceSource,$routeSeconds,$id]);
        ledger($db,$user,'Errand Payment',-$total,textField($p,'title',160) . ' • ' . $method . ' • secured',$id);
        if ($budget > 0) ledger($db,$user,'Purchase Funding',-$budget,textField($p,'title',160) . ' • ' . $budgetMethod . ' • secured separately',$id,'PHP');
        notice($db,$user,'Errands','Payment secured. Your errand is now posted.',$id);
        if (!empty($data['preferredRunnerId'])) {
            $target = textField($data,'preferredRunnerId',64);
            if (query($db,'SELECT id FROM users WHERE id=?',[$target])->fetch()) notice($db,$target,'Errands',$profile['name'] . ' invited you to help.',$id);
        }
    } elseif ($action === 'accept') {
        if (!$e) fail('Choose an errand.');
        if (!$profile['verified']) fail('Verify your account before accepting.',403);
        if ($owner) fail('You cannot accept your own errand.');
        if ($e['status'] !== 'posted') fail('This errand is no longer available.',409);
        if (query($db,"SELECT 1 FROM user_links WHERE user_id=? AND target_id=? AND type='blocked'",[$e['owner_id'],$user])->fetchColumn()) fail('This errand is unavailable.',403);
        query($db,"UPDATE errands SET runner_id=?,status='accepted',progress=0 WHERE id=?",[$user,$id]);
        history($db,$id,0);
        notice($db,$e['owner_id'],'Errands',$profile['name'] . ' accepted your errand.',$id);
        notice($db,$user,'Errands','You accepted ' . $e['title'] . '.',$id);
    } elseif ($action === 'proof') {
        if (!$runner || (int)$e['progress'] !== 2 || $terminal) fail('Record purchase proof at the pickup location.',403);
        $cost = amount($data,'cost');
        if ($cost > (float)$e['budget']) fail('Actual cost must be within the purchase budget.');
        if (array_diff(array_keys($files),['receipt','item'])) fail('Choose a receipt and item photo.');
        $savedKinds = query($db,'SELECT kind FROM proof_files WHERE errand_id=?',[$id])->fetchAll(PDO::FETCH_COLUMN);
        foreach (['receipt','item'] as $kind) if (!isset($files[$kind]) && !in_array($kind,$savedKinds,true)) fail('Attach a receipt and item photo.');
        $changed = saveProofFiles($db,$id,$user,$files);
        query($db,'UPDATE errands SET actual_cost=?,receipt=1,item_photo=1 WHERE id=?',[$cost,$id]);
        if ($changed || $e['actual_cost'] === null || (float)$e['actual_cost'] !== $cost) notice($db,$e['owner_id'],'Errands','Purchase proof is ready to review.',$id);
    } elseif ($action === 'deliveryProof') {
        if (!$runner || (int)$e['progress'] !== 5 || $terminal || $e['handoff_verified']) fail('Add a delivery photo when you arrive, before verifying handoff.',403);
        if (array_keys($files) !== ['delivery']) fail('Choose a delivery photo.');
        if (saveProofFiles($db,$id,$user,$files)) notice($db,$e['owner_id'],'Errands','Your runner added a delivery photo.',$id);
    } elseif ($action === 'advance') {
        if (!$runner || $terminal || (int)$e['progress'] < 0 || (int)$e['progress'] >= 5) fail('This task cannot advance.',403);
        if ((int)$e['progress'] === 2 && (float)$e['budget'] > 0 && (!$e['receipt'] || !$e['item_photo'] || $e['actual_cost'] === null)) fail('Add your receipt and item photo first.');
        $step = (int)$e['progress'] + 1;
        $pin = $step === 5 ? (string)random_int(100000,999999) : null;
        query($db,"UPDATE errands SET progress=?,status='ongoing',completion_pin=COALESCE(?,completion_pin) WHERE id=?",[$step,$pin,$id]);
        history($db,$id,$step);
        notice($db,$e['owner_id'],'Errands',$profile['name'] . ' updated the errand progress.',$id);
    } elseif ($action === 'pin') {
        if (!$runner || (int)$e['progress'] !== 5 || $terminal) fail('Only the assigned runner can verify handoff.',403);
        if ((int)$e['pin_attempts'] >= 5) fail('PIN locked after five incorrect attempts. Ask the requester to replace the handoff PIN.',429);
        if (!hash_equals((string)$e['completion_pin'],textField($data,'pin',6))) {
            query($db,'UPDATE errands SET pin_attempts=pin_attempts+1 WHERE id=?',[$id]);
            throw new ApiError('Incorrect completion PIN. Ask the requester after handoff.',422,true);
        }
        query($db,"UPDATE errands SET progress=6,status='waiting',handoff_verified=1 WHERE id=?",[$id]);
        history($db,$id,6);
        notice($db,$e['owner_id'],'Errands','Handoff verified. Please confirm receipt.',$id);
    } elseif ($action === 'resetPin') {
        if (!$owner || $terminal || (int)$e['progress'] !== 5 || $e['handoff_verified']) fail('Only the requester can replace a PIN before verified handoff.',403);
        if ($e['pin_reset_at'] !== null && strtotime($e['pin_reset_at']) > time()-60) fail('Wait one minute before replacing the PIN again.',429);
        do { $pin = (string)random_int(100000,999999); } while ($pin === $e['completion_pin']);
        query($db,'UPDATE errands SET completion_pin=?,pin_attempts=0,pin_reset_at=UTC_TIMESTAMP(6) WHERE id=?',[$pin,$id]);
        notice($db,$user,'Errands','Your new handoff PIN is ready. Share it only after receiving the errand.',$id);
        notice($db,$e['runner_id'],'Errands','The requester replaced the handoff PIN. Ask them for the new PIN after handoff.',$id);
    } elseif ($action === 'cancelResponse' || $action === 'supportCancel') {
        if (!$e || !$e['cancel_requested_by'] || $terminal) fail('There is no pending cancellation to resolve.',409);
        $decision = textField($data,'decision',20);
        if ($action === 'supportCancel') {
            if (!isSupportUser($user)) {
                requireDemo();
                if (!$owner && !$runner) fail('Only task participants can simulate a support review.',403);
            }
            if (!in_array($decision,['approve','reject'],true)) fail('Choose approve or reject.');
            if ($decision === 'approve') {
                $compensation = amount($data,'runnerPayment');
                if ($compensation > (float)$e['fee']) fail('Compensation must stay within the secured runner payment.');
                settleCancellation($db,$e,$compensation,$user);
                return;
            }
        } else {
            if (!$owner && !$runner) fail('Only task participants can answer cancellation requests.',403);
            if ($decision === 'withdraw') {
                if ($e['cancel_requested_by'] !== $user) fail('Only the requesting participant can withdraw.',403);
            } else {
                if ($e['cancel_requested_by'] === $user) fail('The other participant must answer the request.',403);
                if (!in_array($decision,['approve','reject'],true)) fail('Choose approve or reject.');
                if ($decision === 'approve') {
                    if ((int)$e['progress'] >= 3 || $e['receipt'] || $e['item_photo'] || (float)($e['actual_cost'] ?? 0) > 0) fail('Recorded purchases or delivery work require support review.',409);
                    settleCancellation($db,$e,0,$user);
                    return;
                }
                // Disagreement stays under review; neither participant can release funds.
                query($db,"UPDATE reports SET status='Under Review' WHERE errand_id=? AND reason LIKE 'Cancellation request:%' AND status='Submitted'",[$id]);
                foreach ([$e['owner_id'],$e['runner_id']] as $participant) notice($db,$participant,'Errands','Cancellation disputed. Support review is required; funds remain secured.',$id);
                return;
            }
        }
        query($db,'UPDATE errands SET cancel_requested_by=NULL,cancel_requested_at=NULL WHERE id=?',[$id]);
        closeCancellationReports($db,$id,$decision === 'withdraw' ? 'Withdrawn' : 'Rejected');
        foreach ([$e['owner_id'],$e['runner_id']] as $participant) notice($db,$participant,'Errands','Cancellation ' . ($decision === 'withdraw' ? 'withdrawn' : 'rejected by support') . '. The errand can continue.',$id);
    } elseif ($action === 'complete') {
        if (!$owner || $e['status'] !== 'waiting' || !$e['handoff_verified']) fail('Only the requester can confirm a verified handoff.',409);
        walletLocks($db,[$user,$e['runner_id']]);
        $fee = (float)$e['fee']; $cost = (float)($e['actual_cost'] ?? $e['budget']); $refund = (float)$e['budget'] - $cost;
        query($db,"UPDATE errands SET progress=7,status='completed' WHERE id=?",[$id]);
        history($db,$id,7);
        query($db,'UPDATE wallets SET available=available+?,total_earnings=total_earnings+? WHERE user_id=?',[$fee,$fee,$e['runner_id']]);
        ledger($db,$e['runner_id'],'Runner Earnings',$fee,$e['title'],$id);
        $pesoPurchase = $e['budget_currency'] === 'PHP';
        ledger($db,$user,'Purchase Budget',-$cost,$e['title'] . ' • paid from secured funds',$id,$pesoPurchase ? 'PHP' : 'CY');
        if ($pesoPurchase && $cost > 0) ledger($db,$e['runner_id'],'Purchase Reimbursement',$cost,$e['title'] . ' • simulated peso transfer • no conversion fee',$id,'PHP');
        ledger($db,$user,'Service Fee',-(float)$e['service_fee'],$e['title'] . ' • paid from secured funds',$id);
        if ($refund > 0) {
            if (!$pesoPurchase) query($db,'UPDATE wallets SET available=available+?,refunds=refunds+? WHERE user_id=?',[$refund,$refund,$user]);
            ledger($db,$user,'Refund',$refund,$e['title'] . ($pesoPurchase ? ' • simulated peso refund' : ' • coin refund'),$id,$pesoPurchase ? 'PHP' : 'CY');
            notice($db,$user,'Wallet','Unused purchase budget was refunded.',$id);
        }
        query($db,'UPDATE users SET completed=completed+1 WHERE id IN (?,?)',[$user,$e['runner_id']]);
        notice($db,$e['runner_id'],'Wallet','Your runner payment was released.',$id);
        notice($db,$user,'Errands','Your errand has been completed.',$id);
    } elseif ($action === 'cancel' || $action === 'expire') {
        if ($terminal || (!$owner && !($action === 'cancel' && $runner))) fail('Only task participants can request cancellation.',403);
        if ($action === 'expire') {
            requireDemo();
            if ($e['status'] !== 'posted') fail('Only unaccepted posts can expire.');
            refund($db,$e,'expired');
        } else {
            $reason = textField($data,'reason',500);
            if ($e['runner_id']) {
                if ($e['cancel_requested_by']) fail('A cancellation request is already pending.',409);
                query($db,'UPDATE errands SET cancel_requested_by=?,cancel_requested_at=UTC_TIMESTAMP(6),cancellation_reason=? WHERE id=?',[$user,$reason,$id]);
                query($db,'INSERT INTO reports(user_id,errand_id,reason,description) VALUES(?,?,?,?)',[$user,$id,'Cancellation request: ' . $reason,'Please review cancellation of this accepted errand.']);
                foreach ([$e['owner_id'],$e['runner_id']] as $participant) notice($db,$participant,'Errands','Cancellation requested: ' . $reason . '. Respond in task details; funds remain secured.',$id);
            } else {
                query($db,'UPDATE errands SET cancellation_reason=? WHERE id=?',[$reason,$id]);
                refund($db,$e,'cancelled');
            }
        }
    } elseif ($action === 'topUp' || $action === 'cashOut') {
        requireDemo(); walletLocks($db,[$user]);
        if ($action === 'topUp') {
            $pesos = amount($data,'pesos',1);
            if (!in_array($pesos,[50.0,100.0,200.0,500.0],true)) fail('Choose a valid top-up amount.');
            $method = textField(['method'=>$data['method'] ?? 'GCash Simulation'],'method',60);
            if (!in_array($method,['GCash Simulation','Card Simulation'],true)) fail('Choose a valid top-up payment method.');
            $coins = top_up_coins($pesos);
            query($db,'UPDATE wallets SET available=available+? WHERE user_id=?',[$coins,$user]);
            ledger($db,$user,'Top Up',$coins,$method . ' • ₱' . $pesos,null,'CY',$pesos);
            notice($db,$user,'Wallet','Top up simulated. ' . $coins . ' CY added.');
        } else {
            $coins = amount($data,'coins',0.01);
            if (!preg_match('/^09\d{9}$/',textField($data,'phone',24))) fail('Enter an 11-digit GCash number starting with 09.');
            if ($coins > (float)query($db,'SELECT available FROM wallets WHERE user_id=?',[$user])->fetchColumn()) fail('Enter an amount within your available balance.');
            query($db,'UPDATE wallets SET available=available-? WHERE user_id=?',[$coins,$user]);
            $pesos = cash_out_pesos($coins);
            ledger($db,$user,'Cash Out',-$coins,'Simulated GCash • ₱' . $pesos,null,'CY',$pesos);
            notice($db,$user,'Wallet','Cash out simulated: ₱' . $pesos . '.');
        }
    } elseif ($action === 'send') {
        if (!$e) fail('Choose an errand.');
        $recipient = $owner ? ($data['recipientId'] ?? $e['runner_id']) : $e['owner_id'];
        if (!is_string($recipient) || $recipient === $user || !query($db,'SELECT id FROM users WHERE id=?',[$recipient])->fetchColumn()) fail('Choose an existing errand conversation.');
        if (isset($data['recipientId']) && $data['recipientId'] !== $recipient) fail('This conversation is private.',403);
        $thread = query($db,'SELECT 1 FROM messages WHERE errand_id=? AND ((sender_id=? AND recipient_id=?) OR (sender_id=? AND recipient_id=?)) LIMIT 1',[$id,$user,$recipient,$recipient,$user])->fetchColumn();
        if ($owner && $recipient !== $e['runner_id'] && !$thread) fail('Reply to an existing inquiry from your inbox.',403);
        if (!$owner && !$runner && !$thread && ($e['status'] !== 'posted' || strtotime($e['deadline']) <= time())) fail('Only task participants can use this conversation.',403);
        if (query($db,"SELECT 1 FROM user_links WHERE type='blocked' AND ((user_id=? AND target_id=?) OR (user_id=? AND target_id=?))",[$user,$recipient,$recipient,$user])->fetchColumn()) fail('This conversation is unavailable.',403);
        $text = textField($data,'text',5000);
        query($db,'INSERT INTO messages(errand_id,sender_id,recipient_id,text) VALUES(?,?,?,?)',[$id,$user,$recipient,$text]);
        notice($db,$recipient,'Messages',$profile['name'] . ': ' . $text,$id);
    } elseif ($action === 'rate') {
        if (!$e || $e['status'] !== 'completed' || (!$owner && !$runner)) fail('Complete a transaction before reviewing.',403);
        $stars = $data['stars'] ?? 0;
        if (!is_int($stars) || $stars < 1 || $stars > 5) fail('Choose one to five stars.');
        $scores = $data['scores'] ?? [];
        if (!is_array($scores)) fail('Invalid review scores.');
        foreach ($scores as $score) if (!is_int($score) || $score < 1 || $score > 5) fail('Choose one to five stars for each score.');
        if (query($db,'SELECT id FROM reviews WHERE errand_id=? AND from_id=?',[$id,$user])->fetch()) fail('You already reviewed this errand.',409);
        $other = $owner ? $e['runner_id'] : $e['owner_id'];
        query($db,'INSERT INTO reviews(errand_id,from_id,to_id,stars,text,scores) VALUES(?,?,?,?,?,?)',[$id,$user,$other,$stars,textField($data,'text',5000,true),json_encode((object)$scores)]);
        query($db,'UPDATE users SET rating=(SELECT AVG(stars) FROM reviews WHERE to_id=?) WHERE id=?',[$other,$other]);
    } elseif ($action === 'report') {
        query($db,'INSERT INTO reports(user_id,errand_id,reason,description,evidence) VALUES(?,?,?,?,?)',[$user,$id,textField($data,'reason',500),textField($data,'description',10000),!empty($data['evidence']) ? 1 : 0]);
        notice($db,$user,'Errands','Your report was submitted for review.',$id);
    } elseif ($action === 'save') {
        if (!$e) fail('Choose an errand.');
        $exists = query($db,'SELECT 1 FROM saved_errands WHERE user_id=? AND errand_id=?',[$user,$id])->fetchColumn();
        query($db,$exists ? 'DELETE FROM saved_errands WHERE user_id=? AND errand_id=?' : 'INSERT INTO saved_errands(user_id,errand_id) VALUES(?,?)',[$user,$id]);
    } elseif (in_array($action,['friend','favorite','block'],true)) {
        $target = textField($data,'targetId',64);
        if ($target === $user || !query($db,'SELECT id FROM users WHERE id=?',[$target])->fetch()) fail('Choose another user.');
        $type = $action === 'block' ? 'blocked' : $action;
        $exists = query($db,'SELECT 1 FROM user_links WHERE user_id=? AND target_id=? AND type=?',[$user,$target,$type])->fetchColumn();
        query($db,$exists ? 'DELETE FROM user_links WHERE user_id=? AND target_id=? AND type=?' : 'INSERT INTO user_links(user_id,target_id,type) VALUES(?,?,?)',[$user,$target,$type]);
        if ($action === 'friend') query($db,$exists ? 'DELETE FROM user_links WHERE user_id=? AND target_id=? AND type=?' : 'INSERT IGNORE INTO user_links(user_id,target_id,type) VALUES(?,?,?)',[$target,$user,$type]);
    } elseif ($action === 'profile') {
        $p = $data['profile'] ?? [];
        $email = strtolower(textField($p,'email',254)); $phone = textField($p,'phone',24);
        if (!filter_var($email,FILTER_VALIDATE_EMAIL) || !preg_match('/^\+?\d{7,15}$/',$phone)) fail('Check email and phone.');
        if (query($db,'SELECT id FROM users WHERE email=? AND id<>?',[$email,$user])->fetch()) fail('That email belongs to another account.',409);
        $phonePrivacy = textField($p,'phonePrivacy',20); $emailPrivacy = textField($p,'emailPrivacy',20);
        if (!in_array($phonePrivacy,['Public','Friends Only','Private'],true) || !in_array($emailPrivacy,['Public','Friends Only','Private'],true)) fail('Invalid privacy setting.');
        query($db,'UPDATE users SET name=?,email=?,phone=?,location=?,bio=?,photo=?,location_allowed=?,phone_privacy=?,email_privacy=? WHERE id=?',
            [textField($p,'name',120),$email,$phone,textField($p,'location',255),textField($p,'bio',5000,true),!empty($p['photo']) ? 1 : 0,!empty($p['locationAllowed']) ? 1 : 0,$phonePrivacy,$emailPrivacy,$user]);
    } elseif ($action === 'verify') {
        requireDemo();
        $p = $data['profile'] ?? [];
        if (empty($p['emailVerified']) || empty($p['phoneVerified']) || empty($p['idVerified'])) fail('Complete all three verification steps first.');
        query($db,'UPDATE users SET verified=1,email_verified=1,phone_verified=1,id_verified=1 WHERE id=?',[$user]);
        notice($db,$user,'Errands','Your account verification was simulated. Welcome to Errandly!');
    } elseif ($action === 'read') {
        $ids = $data['ids'] ?? [];
        if (!is_array($ids)) fail('Invalid notifications.');
        foreach ($ids as $noticeId) query($db,'UPDATE notifications SET is_read=1 WHERE id=? AND user_id=?',[(string)$noticeId,$user]);
    } elseif ($action === 'reportStatus') {
        requireDemo();
        $report = query($db,'SELECT * FROM reports WHERE id=? AND user_id=?',[textField($data,'reportId',64),$user])->fetch();
        if ($report && str_starts_with($report['reason'],'Cancellation request:')) fail('Resolve cancellations from task details so secured funds are accounted for.',409);
        $status = textField($data,'status',30);
        if (!in_array($status,['Under Review','Resolved'],true)) fail('Invalid status.');
        query($db,'UPDATE reports SET status=? WHERE id=? AND user_id=?',[$status,textField($data,'reportId',64),$user]);
    } else fail('Unknown action.',404);
}
