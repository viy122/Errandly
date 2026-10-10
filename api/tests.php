<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/commands.php';
function check(bool $condition, string $message): void {
    if (!$condition) throw new RuntimeException($message);
}
function rejects(callable $callback, string $message): void {
    try { $callback(); } catch(ApiError $e) { return; }
    throw new RuntimeException($message);
}
$db = db();
$db->beginTransaction();
try {
    requireDemo();
    $anna = (float)query($db,'SELECT available FROM wallets WHERE user_id=?',['anna'])->fetchColumn();
    $ben = (float)query($db,'SELECT available FROM wallets WHERE user_id=?',['ben'])->fetchColumn();
    check($anna > 95,'Seed demo accounts before running these tests.');
    $id = 'test_' . bin2hex(random_bytes(8));
    $post = ['errand'=>['id'=>$id,'title'=>'Database integration test','category'=>'Delivery','description'=>'Transactional test; this record is rolled back.','pickup'=>'Quezon City','destination'=>'Cavite','area'=>'Metro Manila','transport'=>'Motorcycle','instructions'=>'Call on arrival.','budget'=>50,'fee'=>40,'distance'=>65000,'deadline'=>gmdate('c',time()+86400),'urgent'=>false],'method'=>'Errandly Wallet','budgetMethod'=>'GCash Simulation'];
    command($db,'anna','post',$post);
    check((float)query($db,'SELECT available FROM wallets WHERE user_id=?',['anna'])->fetchColumn() === $anna-45,'Post must secure coin fees independently of the peso budget.');
    rejects(fn()=>command($db,'anna','accept',['errandId'=>$id]),'Requester cannot accept own task.');
    command($db,'ben','accept',['errandId'=>$id]);
    rejects(fn()=>command($db,'maria','accept',['errandId'=>$id]),'A second runner must not claim the task.');
    rejects(fn()=>command($db,'maria','send',['errandId'=>$id,'text'=>'Intrusion']), 'Chat must be private.');
    command($db,'anna','send',['errandId'=>$id,'text'=>'Hello from the database.']);
    check(count(array_filter(snapshot($db,'ben')['messages'],fn($m)=>$m['errandId']===$id))===1,'Chat must persist.');
    command($db,'ben','advance',['errandId'=>$id]);
    command($db,'ben','advance',['errandId'=>$id]);
    rejects(fn()=>command($db,'ben','advance',['errandId'=>$id]),'Purchase proof must be required.');
    $png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aR1kAAAAASUVORK5CYII=');
    $proofs = ['receipt'=>proofImage($png,'receipt.png'),'item'=>proofImage($png,'items.png')];
    rejects(fn()=>command($db,'ben','proof',['errandId'=>$id,'cost'=>45,'receipt'=>true,'photo'=>true]),'Boolean sample proof must not substitute for files.');
    command($db,'ben','proof',['errandId'=>$id,'cost'=>45],$proofs);
    for($i=0;$i<3;$i++) command($db,'ben','advance',['errandId'=>$id]);
    command($db,'ben','deliveryProof',['errandId'=>$id],['delivery'=>proofImage($png,'delivery.png')]);
    $ownerTask = array_values(array_filter(snapshot($db,'anna')['errands'],fn($e)=>$e['id']===$id))[0];
    $runnerTask = array_values(array_filter(snapshot($db,'ben')['errands'],fn($e)=>$e['id']===$id))[0];
    check(strlen($ownerTask['pin'])===6 && $runnerTask['pin']===null,'PIN must only be returned to the owner.');
    check(count($ownerTask['proofFiles'])===3 && count($runnerTask['proofFiles'])===3,'Both participants must receive saved proof metadata.');
    check(privateProofFile($db,'anna',$ownerTask['proofFiles'][0]['id'])['payload']===$png,'Requester must be able to open actual saved image bytes.');
    rejects(fn()=>privateProofFile($db,'maria',$ownerTask['proofFiles'][0]['id']),'Another user must not open private proof.');
    check(snapshot($db,'ben')['users'][1]['email']==='', 'Private contact details must not leak.');
    rejects(fn()=>command($db,'anna','complete',['errandId'=>$id]),'Completion must require verified handoff.');
    command($db,'ben','pin',['errandId'=>$id,'pin'=>$ownerTask['pin']]);
    rejects(fn()=>command($db,'ben','complete',['errandId'=>$id]),'Runner cannot release own payment.');
    command($db,'anna','complete',['errandId'=>$id]);
    check((float)query($db,'SELECT available FROM wallets WHERE user_id=?',['ben'])->fetchColumn()===$ben+40,'Runner must receive exactly 40.');
    check((float)query($db,'SELECT available FROM wallets WHERE user_id=?',['anna'])->fetchColumn()===$anna-45,'Peso refunds must not increase the coin wallet.');
    check((float)query($db,"SELECT amount FROM wallet_entries WHERE user_id='anna' AND errand_id=? AND type='Refund' AND currency='PHP'",[$id])->fetchColumn()===5.0,'Owner must receive exactly 5 pesos in the refund history.');
    check((float)query($db,"SELECT amount FROM wallet_entries WHERE user_id='ben' AND errand_id=? AND type='Purchase Reimbursement' AND currency='PHP'",[$id])->fetchColumn()===45.0,'Runner purchase reimbursement must be recorded separately in pesos.');
    rejects(fn()=>command($db,'anna','complete',['errandId'=>$id]),'Duplicate settlement must fail.');
    command($db,'anna','rate',['errandId'=>$id,'stars'=>5,'text'=>'Thanks!','scores'=>['Communication'=>5]]);
    rejects(fn()=>command($db,'anna','rate',['errandId'=>$id,'stars'=>5,'text'=>'Again','scores'=>[]]),'Duplicate reviews must fail.');
    $post['errand']['id'] .= '_cancel';
    command($db,'anna','post',$post);
    command($db,'anna','cancel',['errandId'=>$post['errand']['id'],'reason'=>'Test cancellation']);
    rejects(fn()=>command($db,'anna','cancel',['errandId'=>$post['errand']['id'],'reason'=>'Again']),'Duplicate refund must fail.');
    command($db,'ben','topUp',['pesos'=>100]);
    command($db,'ben','cashOut',['coins'=>110,'phone'=>'09171234567']);
    check((float)query($db,'SELECT available FROM wallets WHERE user_id=?',['ben'])->fetchColumn()===$ben+40,'Top-up and cash-out amounts must balance.');
    rejects(fn()=>command($db,'ben','cashOut',['coins'=>1000000,'phone'=>'09171234567']),'Insufficient funds must fail.');
    command($db,'ben','report',['reason'=>'Test','description'=>'Test report','evidence'=>true]);
    check(count(snapshot($db,'ben')['reports']) > 0,'Reports must persist.');
    command($db,'ben','favorite',['targetId'=>'anna']);
    command($db,'ben','save',['errandId'=>$id]);
    check(in_array($id,snapshot($db,'ben')['saved'],true),'Saved errands must persist.');
    $hash = query($db,'SELECT password_hash FROM users WHERE id=?',['ben'])->fetchColumn();
    check($hash !== 'demo123' && password_verify('demo123',$hash),'Password must be hashed.');
    $db->rollBack();
    echo "PASS: post, claim, permissions, chat, proof, PIN privacy, settlement, refunds, reviews, wallet, reports, saves and password hashing.\nTest mutations rolled back; existing data preserved.\n";
} catch(Throwable $e) {
    if ($db->inTransaction()) $db->rollBack();
    fwrite(STDERR,$e->getMessage() . "\n"); exit(1);
}
