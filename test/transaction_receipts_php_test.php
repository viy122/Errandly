<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../api/commands.php';
$db = db();
$db->beginTransaction();
try {
    requireDemo();
    $balance = (float)query($db,'SELECT available FROM wallets WHERE user_id=?',['ben'])->fetchColumn();
    command($db,'ben','topUp',['pesos'=>100,'method'=>'GCash Simulation']);
    $topUp = snapshot($db,'ben')['transactions'][0];
    if ($topUp['amount'] !== 110.0 || $topUp['pesoAmount'] !== 100.0 || $topUp['currency'] !== 'CY' || !ctype_digit($topUp['id'])) throw new RuntimeException('Top-up receipt metadata is incorrect.');
    command($db,'ben','cashOut',['coins'=>110,'phone'=>'09171234567']);
    $cashOut = snapshot($db,'ben')['transactions'][0];
    if ($cashOut['amount'] !== -110.0 || $cashOut['pesoAmount'] !== 80.0 || $cashOut['id'] === $topUp['id']) throw new RuntimeException('Cash-out receipt metadata is incorrect.');
    $again = snapshot($db,'ben')['transactions'][0];
    if ($again['id'] !== $cashOut['id'] || $again['date'] !== $cashOut['date']) throw new RuntimeException('Receipt reference changed on reload.');
    if ((float)query($db,'SELECT available FROM wallets WHERE user_id=?',['ben'])->fetchColumn() !== $balance) throw new RuntimeException('Receipt flow changed wallet settlement.');
    $db->rollBack();
    echo "PASS: persisted receipt references, original peso amounts, correct coin units and stable reloads. Test data rolled back.\n";
} catch(Throwable $e) {
    if ($db->inTransaction()) $db->rollBack();
    fwrite(STDERR,$e->getMessage() . "\n"); exit(1);
}
