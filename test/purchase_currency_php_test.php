<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../api/commands.php';
function assertPurchase(bool $condition, string $message): void {
    if (!$condition) throw new RuntimeException($message);
}
function rejectPurchase(callable $action): void {
    try { $action(); } catch (ApiError $e) { return; }
    throw new RuntimeException('A duplicate payment was accepted.');
}
$db = db();
$db->beginTransaction();
try {
    requireDemo();
    $png = file_get_contents(__DIR__ . '/../assets/brand/errandly-symbol.png');
    $proofs = ['receipt'=>proofImage($png,'test-receipt.png'),'item'=>proofImage($png,'test-items.png')];
    foreach ([0.0,45.0,49.99,50.0] as $cost) {
        $anna = (float)query($db,"SELECT available FROM wallets WHERE user_id='anna'")->fetchColumn();
        $ben = (float)query($db,"SELECT available FROM wallets WHERE user_id='ben'")->fetchColumn();
        $id = 'currency_test_' . bin2hex(random_bytes(8));
        $data = ['errand'=>['id'=>$id,'title'=>'Currency settlement test','category'=>'Purchase','description'=>'Rolled back after validation.','pickup'=>'Store','destination'=>'Home','area'=>'Nasugbu','transport'=>'On foot','instructions'=>'','budget'=>50,'fee'=>110,'distance'=>500,'deadline'=>gmdate('c',time()+86400),'urgent'=>false],'method'=>'Errandly Wallet','budgetMethod'=>'GCash Simulation'];
        command($db,'anna','post',$data);
        assertPurchase((float)query($db,"SELECT available FROM wallets WHERE user_id='anna'")->fetchColumn()===$anna-115,'Purchase funding must not deduct coins.');
        assertPurchase((float)query($db,"SELECT amount FROM wallet_entries WHERE errand_id=? AND type='Purchase Funding' AND currency='PHP'",[$id])->fetchColumn()===-50.0,'50 pesos must be secured separately.');
        command($db,'ben','accept',['errandId'=>$id]);
        command($db,'ben','advance',['errandId'=>$id]);
        command($db,'ben','advance',['errandId'=>$id]);
        command($db,'ben','proof',['errandId'=>$id,'cost'=>$cost],$proofs);
        for ($i=0;$i<3;$i++) command($db,'ben','advance',['errandId'=>$id]);
        $pin = query($db,'SELECT completion_pin FROM errands WHERE id=?',[$id])->fetchColumn();
        command($db,'ben','pin',['errandId'=>$id,'pin'=>$pin]);
        command($db,'anna','complete',['errandId'=>$id]);
        assertPurchase((float)query($db,"SELECT available FROM wallets WHERE user_id='anna'")->fetchColumn()===$anna-115,'Peso refunds must not mint coins.');
        assertPurchase((float)query($db,"SELECT available FROM wallets WHERE user_id='ben'")->fetchColumn()===$ben+110,'Runner must receive exactly the agreed 110 coins.');
        $reimbursement = (float)query($db,"SELECT COALESCE(SUM(amount),0) FROM wallet_entries WHERE errand_id=? AND user_id='ben' AND type='Purchase Reimbursement' AND currency='PHP'",[$id])->fetchColumn();
        $refund = (float)query($db,"SELECT COALESCE(SUM(amount),0) FROM wallet_entries WHERE errand_id=? AND user_id='anna' AND type='Refund' AND currency='PHP'",[$id])->fetchColumn();
        assertPurchase(abs($reimbursement-$cost)<.00001,'The actual cost must be reimbursed without conversion.');
        assertPurchase(abs($reimbursement+$refund-50)<.00001,'Purchase pesos must be conserved between reimbursement and refund.');
        rejectPurchase(fn()=>command($db,'anna','complete',['errandId'=>$id]));
        command($db,'ben','cashOut',['coins'=>110,'phone'=>'09171234567']);
        assertPurchase((float)query($db,"SELECT available FROM wallets WHERE user_id='ben'")->fetchColumn()===$ben,'Reimbursements must not change cash-out coin balance.');
        assertPurchase(str_contains(query($db,"SELECT note FROM wallet_entries WHERE user_id='ben' AND type='Cash Out' ORDER BY id DESC LIMIT 1")->fetchColumn(),'₱80'),'110 coins must pay out 80 pesos.');
    }
    foreach (['cancel','expire','legacy'] as $action) {
        $anna = (float)query($db,"SELECT available FROM wallets WHERE user_id='anna'")->fetchColumn();
        $data['errand']['id'] = $id = 'refund_test_' . bin2hex(random_bytes(8));
        command($db,'anna','post',$data);
        if ($action === 'legacy') {
            // Preserve the old 165-CY secured amount rather than converting old balances.
            query($db,"UPDATE errands SET budget_currency='CY',budget_method='Legacy coins' WHERE id=?",[$id]);
            query($db,"UPDATE wallets SET available=available-50 WHERE user_id='anna'");
            query($db,"DELETE FROM wallet_entries WHERE errand_id=? AND type='Purchase Funding'",[$id]);
        }
        $command = $action === 'expire' ? 'expire' : 'cancel';
        command($db,'anna',$command,['errandId'=>$id,'reason'=>'Test']);
        assertPurchase((float)query($db,"SELECT available FROM wallets WHERE user_id='anna'")->fetchColumn()===$anna,'Refund must restore the original coin balance exactly.');
        $coins = (float)query($db,"SELECT amount FROM wallet_entries WHERE errand_id=? AND type='Refund' AND currency='CY'",[$id])->fetchColumn();
        $pesos = (float)query($db,"SELECT COALESCE(SUM(amount),0) FROM wallet_entries WHERE errand_id=? AND type='Refund' AND currency='PHP'",[$id])->fetchColumn();
        assertPurchase($coins===($action==='legacy' ? 165.0 : 115.0),'Coin refund must match original funding.');
        assertPurchase($pesos===($action==='legacy' ? 0.0 : 50.0),'Separate peso budget must be refunded in full.');
        rejectPurchase(fn()=>command($db,'anna',$command,['errandId'=>$id,'reason'=>'Again']));
    }
    $db->rollBack();
    echo "PASS: separate funding, full/partial/zero-cost reimbursement, coin cash-out, cancellation, expiry, legacy refunds and duplicate protection. Test changes rolled back.\n";
} catch (Throwable $e) {
    if ($db->inTransaction()) $db->rollBack();
    fwrite(STDERR,$e->getMessage()."\n"); exit(1);
}
