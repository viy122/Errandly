<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
// A reviewer is configured only inside this test process, never in the app database.
putenv('ERRANDLY_SUPPORT_USERS=maria');
require_once __DIR__ . '/../api/commands.php';
function recoveryCheck(bool $ok, string $message): void {
    if (!$ok) throw new RuntimeException($message);
}
function recoveryReject(callable $action, string $message): void {
    try { $action(); } catch (ApiError $e) { return; }
    throw new RuntimeException($message);
}
$db = db(); $db->beginTransaction();
try {
    $balance = fn(string $u): float => (float)query($db,'SELECT available FROM wallets WHERE user_id=?',[$u])->fetchColumn();
    $post = fn(string $id, float $budget = 0): array => ['errand'=>['id'=>$id,'title'=>'Recovery test','category'=>'Delivery','description'=>'Rolled back test','pickup'=>'Store','destination'=>'Home','area'=>'Nasugbu','transport'=>'On foot','instructions'=>'','budget'=>$budget,'fee'=>40,'distance'=>500,'deadline'=>gmdate('c',time()+86400),'urgent'=>false],'method'=>'Errandly Wallet','budgetMethod'=>'GCash Simulation'];
    $id = 'recovery_' . bin2hex(random_bytes(8));
    $data = $post($id); $anna = $balance('anna');
    command($db,'anna','post',$data);
    command($db,'anna','post',$data);
    recoveryCheck($balance('anna')===$anna-45,'Retry charged the posting wallet twice.');
    $changed = $data; $changed['errand']['fee'] = 60;
    recoveryReject(fn()=>command($db,'anna','post',$changed),'Changed terms reused a published draft ID.');
    command($db,'ben','accept',['errandId'=>$id]);
    command($db,'anna','cancel',['errandId'=>$id,'reason'=>'Wrong address']);
    recoveryReject(fn()=>command($db,'anna','cancel',['errandId'=>$id,'reason'=>'Again']),'Duplicate cancellation report accepted.');
    recoveryReject(fn()=>command($db,'anna','cancelResponse',['errandId'=>$id,'decision'=>'approve']),'A participant approved their own request.');
    recoveryReject(fn()=>command($db,'ben','advance',['errandId'=>$id]),'Progress advanced during cancellation.');
    recoveryReject(fn()=>command($db,'joshua','cancelResponse',['errandId'=>$id,'decision'=>'approve']),'Outsider resolved cancellation.');
    recoveryReject(fn()=>command($db,'joshua','supportCancel',['errandId'=>$id,'decision'=>'approve','runnerPayment'=>0]),'Outsider accessed support simulation.');
    command($db,'ben','cancelResponse',['errandId'=>$id,'decision'=>'approve']);
    recoveryCheck($balance('anna')===$anna,'Mutual cancellation did not refund the held coins.');
    recoveryReject(fn()=>command($db,'ben','cancelResponse',['errandId'=>$id,'decision'=>'approve']),'Duplicate cancellation settlement accepted.');

    if (config()['demo']) {
        $id .= '_cost'; $anna = $balance('anna'); $ben = $balance('ben');
        command($db,'anna','post',$post($id,50));
        command($db,'ben','accept',['errandId'=>$id]);
        command($db,'ben','advance',['errandId'=>$id]); command($db,'ben','advance',['errandId'=>$id]);
        $png = file_get_contents(__DIR__ . '/../assets/brand/errandly-symbol.png');
        command($db,'ben','proof',['errandId'=>$id,'cost'=>45],['receipt'=>proofImage($png,'test-receipt.png'),'item'=>proofImage($png,'test-items.png')]);
        command($db,'ben','cancel',['errandId'=>$id,'reason'=>'Unable to deliver']);
        recoveryReject(fn()=>command($db,'anna','cancelResponse',['errandId'=>$id,'decision'=>'approve']),'Purchase cancellation bypassed support.');
        recoveryReject(fn()=>command($db,'maria','supportCancel',['errandId'=>$id,'decision'=>'approve','runnerPayment'=>41]),'Compensation exceeded secured payment.');
        command($db,'maria','supportCancel',['errandId'=>$id,'decision'=>'approve','runnerPayment'=>10]);
        recoveryCheck($balance('anna')===$anna-10 && $balance('ben')===$ben+10,'Cancellation coin allocations are incorrect.');
        recoveryCheck((float)query($db,"SELECT amount FROM wallet_entries WHERE errand_id=? AND user_id='ben' AND type='Purchase Reimbursement' AND currency='PHP'",[$id])->fetchColumn()===45.0,'Purchase was not reimbursed in pesos.');
        recoveryCheck((float)query($db,"SELECT amount FROM wallet_entries WHERE errand_id=? AND user_id='anna' AND type='Refund' AND currency='PHP'",[$id])->fetchColumn()===5.0,'Unused peso funds were not refunded.');
        recoveryReject(fn()=>command($db,'maria','supportCancel',['errandId'=>$id,'decision'=>'approve','runnerPayment'=>10]),'Support settled twice.');
    }

    $id = 'pin_' . bin2hex(random_bytes(8));
    command($db,'anna','post',$post($id)); command($db,'ben','accept',['errandId'=>$id]);
    for ($i=0;$i<5;$i++) command($db,'ben','advance',['errandId'=>$id]);
    $old = query($db,'SELECT completion_pin FROM errands WHERE id=?',[$id])->fetchColumn();
    for ($i=0;$i<5;$i++) recoveryReject(fn()=>command($db,'ben','pin',['errandId'=>$id,'pin'=>'000000']),'Wrong PIN succeeded.');
    recoveryReject(fn()=>command($db,'ben','pin',['errandId'=>$id,'pin'=>$old]),'Locked PIN succeeded.');
    recoveryReject(fn()=>command($db,'ben','resetPin',['errandId'=>$id]),'Runner replaced PIN.');
    recoveryReject(fn()=>command($db,'joshua','resetPin',['errandId'=>$id]),'Outsider replaced PIN.');
    command($db,'anna','resetPin',['errandId'=>$id]);
    $new = query($db,'SELECT completion_pin FROM errands WHERE id=?',[$id])->fetchColumn();
    recoveryCheck($new !== $old && (int)query($db,'SELECT pin_attempts FROM errands WHERE id=?',[$id])->fetchColumn()===0,'PIN replacement did not recover the lock.');
    $runnerState = snapshot($db,'ben');
    $task = array_values(array_filter($runnerState['errands'],fn($e)=>$e['id']===$id))[0];
    recoveryCheck($task['pin']===null,'Recovery leaked the PIN to the runner.');
    recoveryReject(fn()=>command($db,'anna','resetPin',['errandId'=>$id]),'PIN replacement ignored cooldown.');
    recoveryReject(fn()=>command($db,'ben','pin',['errandId'=>$id,'pin'=>$old]),'Old PIN remained valid.');
    command($db,'ben','pin',['errandId'=>$id,'pin'=>$new]);
    recoveryReject(fn()=>command($db,'anna','resetPin',['errandId'=>$id]),'Verified handoff was reset.');
    command($db,'anna','complete',['errandId'=>$id]);
    recoveryReject(fn()=>command($db,'anna','complete',['errandId'=>$id]),'Recovered task paid twice.');
    $db->rollBack();
    echo "PASS: idempotent posting, cancellation permissions/holds/refunds, support reimbursement, PIN recovery/privacy/cooldown and duplicate protection. Test data rolled back.\n";
} catch (Throwable $e) {
    if ($db->inTransaction()) $db->rollBack();
    fwrite(STDERR,$e->getMessage() . "\n"); exit(1);
}
