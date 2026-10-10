<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../api/bootstrap.php';
$db = db(); $db->beginTransaction();
try {
    if (($argv[1] ?? '') === '--create') {
        $id = 'qa_upload_' . bin2hex(random_bytes(8));
        query($db,"INSERT INTO errands(id,owner_id,runner_id,title,category,description,pickup,destination,area,transport,instructions,budget,budget_currency,budget_method,fee,distance,deadline,status,progress) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,DATE_ADD(UTC_TIMESTAMP(),INTERVAL 1 DAY),'ongoing',2)",
            [$id,'anna','ben','Upload check — sample purchase','Purchase','Temporary browser upload check. No payment or real purchase.','Test Store','Test delivery point','Test location','On foot','Sample images for upload verification only.',50,'PHP','Browser test (no payment)',40,1000]);
        foreach ([0,1,2] as $step) history($db,$id,$step);
        $db->commit(); echo json_encode(['id'=>$id]);
    } elseif (($argv[1] ?? '') === '--cleanup') {
        $id = $argv[2] ?? '';
        if (!preg_match('/^qa_upload_[a-f0-9]{16}$/',$id)) throw new RuntimeException('Invalid fixture id.');
        $row = query($db,'SELECT description FROM errands WHERE id=? FOR UPDATE',[$id])->fetch();
        if (!$row || $row['description'] !== 'Temporary browser upload check. No payment or real purchase.') throw new RuntimeException('Not a disposable browser fixture.');
        if (query($db,'SELECT 1 FROM wallet_entries WHERE errand_id=?',[$id])->fetchColumn()) throw new RuntimeException('Fixture has wallet entries; stop instead of removing them.');
        foreach (['notifications','messages','reviews','reports','saved_errands'] as $table) query($db,"DELETE FROM `$table` WHERE errand_id=?",[$id]);
        query($db,'DELETE FROM errands WHERE id=?',[$id]);
        $db->commit(); echo "Temporary browser fixture removed; existing errands and balances preserved.\n";
    } else { throw new RuntimeException('Use --create or --cleanup <id>.'); }
} catch(Throwable $e) { if ($db->inTransaction()) $db->rollBack(); fwrite(STDERR,$e->getMessage()."\n"); exit(1); }
