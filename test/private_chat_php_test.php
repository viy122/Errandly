<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../api/commands.php';
function chatCheck(bool $ok, string $message): void {
    if (!$ok) throw new RuntimeException($message);
}
function chatReject(callable $action): void {
    try { $action(); } catch (ApiError $e) { return; }
    throw new RuntimeException('Unauthorized chat action succeeded.');
}
$db = db();
$db->beginTransaction();
try {
    requireDemo();
    $id = 'chat_test_' . bin2hex(random_bytes(8));
    command($db,'anna','post',['errand'=>['id'=>$id,'title'=>'Private inquiry test','category'=>'Delivery','description'=>'Rolled back test','pickup'=>'Nasugbu','destination'=>'Nasugbu','area'=>'Nasugbu, Batangas','transport'=>'On foot','instructions'=>'Test','budget'=>0,'fee'=>40,'distance'=>350,'deadline'=>gmdate('c',time()+86400),'urgent'=>false],'method'=>'GCash Simulation']);
    command($db,'ben','send',['errandId'=>$id,'text'=>'Ben inquiry']);
    command($db,'maria','send',['errandId'=>$id,'text'=>'Maria inquiry']);
    command($db,'anna','send',['errandId'=>$id,'recipientId'=>'ben','text'=>'Reply to Ben']);
    command($db,'anna','send',['errandId'=>$id,'recipientId'=>'maria','text'=>'Reply to Maria']);
    $thread = fn(string $user) => array_values(array_filter(snapshot($db,$user)['messages'],fn($m)=>$m['errandId']===$id));
    chatCheck(array_column($thread('ben'),'text')===['Ben inquiry','Reply to Ben'],'Ben saw another inquiry.');
    chatCheck(array_column($thread('maria'),'text')===['Maria inquiry','Reply to Maria'],'Maria saw another inquiry.');
    chatCheck(count($thread('anna'))===4 && count($thread('joshua'))===0,'Owner/outsider chat scope is incorrect.');
    chatReject(fn()=>command($db,'ben','send',['errandId'=>$id,'recipientId'=>'maria','text'=>'Redirected']));
    chatReject(fn()=>command($db,'anna','send',['errandId'=>$id,'recipientId'=>'joshua','text'=>'Unsolicited']));
    command($db,'ben','accept',['errandId'=>$id]);
    chatCheck(count($thread('ben'))===2,'Assignment exposed another runner inquiry.');
    chatReject(fn()=>command($db,'joshua','send',['errandId'=>$id,'text'=>'Late inquiry']));
    command($db,'maria','send',['errandId'=>$id,'text'=>'Thanks anyway']);
    chatCheck(count($thread('maria'))===3,'An existing inquiry could not continue.');
    query($db,"INSERT IGNORE INTO user_links(user_id,target_id,type) VALUES('anna','ben','blocked')");
    chatReject(fn()=>command($db,'ben','send',['errandId'=>$id,'text'=>'Blocked']));
    $db->rollBack();
    echo "PASS: private pre-accept inquiries, owner replies, assignment isolation, recipient validation and blocking. Test data rolled back.\n";
} catch(Throwable $e) {
    if ($db->inTransaction()) $db->rollBack();
    fwrite(STDERR,$e->getMessage() . "\n"); exit(1);
}
