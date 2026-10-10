<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/commands.php';
function proofCheck(bool $condition,string $message): void { if (!$condition) throw new RuntimeException($message); }
function proofReject(callable $callback,string $message): void { try { $callback(); } catch(ApiError $e) { return; } throw new RuntimeException($message); }
$db = db();
$db->beginTransaction();
try {
    $id = 'proof_test_' . bin2hex(random_bytes(8));
    query($db,"INSERT INTO errands(id,owner_id,runner_id,title,category,description,pickup,destination,area,transport,instructions,budget,fee,distance,deadline,status,progress) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY),'ongoing',2)",
        [$id,'anna','ben','Proof upload test','Purchase','Rolled back test','A','B','Test','On foot','',50,40,1000]);
    $png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aR1kAAAAASUVORK5CYII=');
    $receipt = proofImage($png,'receipt.png'); $item = proofImage($png,'item.png');
    proofReject(fn()=>proofImage('<?php echo "bad"; ?>','receipt.jpg'),'Disguised non-image must fail.');
    proofReject(fn()=>proofImage(str_repeat('x',PROOF_MAX_BYTES+1),'large.png'),'Oversized files must fail.');
    proofReject(fn()=>command($db,'anna','proof',['errandId'=>$id,'cost'=>45],['receipt'=>$receipt,'item'=>$item]),'Requester cannot submit runner proof.');
    proofReject(fn()=>command($db,'ben','proof',['errandId'=>$id,'cost'=>45,'receipt'=>true,'photo'=>true]),'Boolean attachments must fail.');
    proofReject(fn()=>command($db,'ben','proof',['errandId'=>$id,'cost'=>45],['receipt'=>$receipt]),'Missing item photo must fail without saving partial proof.');
    proofCheck((int)query($db,'SELECT COUNT(*) FROM proof_files WHERE errand_id=?',[$id])->fetchColumn()===0,'No partial proof should be saved.');
    proofReject(fn()=>command($db,'ben','proof',['errandId'=>$id,'cost'=>51],['receipt'=>$receipt,'item'=>$item]),'Over-budget cost must fail.');
    command($db,'ben','proof',['errandId'=>$id,'cost'=>45],['receipt'=>$receipt,'item'=>$item]);
    $files = query($db,'SELECT id,kind FROM proof_files WHERE errand_id=? ORDER BY kind',[$id])->fetchAll();
    proofCheck(count($files)===2,'Both images must persist.');
    $noticeCount = (int)query($db,'SELECT COUNT(*) FROM notifications WHERE errand_id=?',[$id])->fetchColumn();
    command($db,'ben','proof',['errandId'=>$id,'cost'=>45],['receipt'=>$receipt,'item'=>$item]);
    proofCheck((int)query($db,'SELECT COUNT(*) FROM notifications WHERE errand_id=?',[$id])->fetchColumn()===$noticeCount,'Retrying identical uploads must not send duplicate notices.');
    proofCheck(query($db,'SELECT id FROM proof_files WHERE errand_id=? ORDER BY kind',[$id])->fetchAll(PDO::FETCH_COLUMN)===array_column($files,'id'),'Identical retries preserve file IDs.');
    $publicTask = array_values(array_filter(snapshot($db,'maria')['errands'],fn($e)=>$e['id']===$id))[0];
    proofCheck($publicTask['proofFiles']===[],'Public errand snapshots must hide attachments.');
    proofReject(fn()=>privateProofFile($db,'maria',$files[0]['id']),'Other users cannot retrieve images.');
    proofCheck(privateProofFile($db,'anna',$files[0]['id'])['payload']===$png,'Saved bytes must remain readable for requester.');
    $changed = proofImage($png . 'different test bytes','replacement.png');
    command($db,'ben','proof',['errandId'=>$id,'cost'=>40],['receipt'=>$changed]);
    proofReject(fn()=>privateProofFile($db,'anna',$files[0]['id']),'Replaced image IDs must become unavailable.');
    proofCheck((int)query($db,'SELECT COUNT(*) FROM proof_files WHERE errand_id=?',[$id])->fetchColumn()===2,'Replacement must retain the other image.');
    query($db,'UPDATE errands SET cancel_requested_by=? WHERE id=?',['anna',$id]);
    proofReject(fn()=>command($db,'ben','proof',['errandId'=>$id,'cost'=>40],['receipt'=>$receipt]),'Cancellation freezes proof updates.');
    query($db,'UPDATE errands SET cancel_requested_by=NULL,progress=5 WHERE id=?',[$id]);
    command($db,'ben','deliveryProof',['errandId'=>$id],['delivery'=>$item]);
    proofReject(fn()=>command($db,'anna','deliveryProof',['errandId'=>$id],['delivery'=>$item]),'Only the runner can upload delivery proof.');
    query($db,"UPDATE errands SET status='completed',progress=7 WHERE id=?",[$id]);
    proofReject(fn()=>command($db,'ben','deliveryProof',['errandId'=>$id],['delivery'=>$item]),'Completed proof cannot be altered.');
    $db->rollBack();
    echo "PASS: actual images, size/type validation, ownership, missing-file rejection, atomic save, private retrieval, retry, replacement, cancellation, delivery proof and completion lock. Test data rolled back.\n";
} catch(Throwable $e) { if ($db->inTransaction()) $db->rollBack(); fwrite(STDERR,$e->getMessage() . "\n"); exit(1); }
