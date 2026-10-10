<?php
declare(strict_types=1);
require_once __DIR__ . '/../api/wallet_rates.php';

foreach ([[50,55],[100,110],[200,220],[500,550]] as [$pesos,$coins]) {
    if (abs(top_up_coins($pesos) - $coins) > 0.00001) {
        throw new RuntimeException('Unexpected top-up quote.');
    }
}
foreach ([[55,40],[110,80],[220,160],[40,29.09]] as [$coins,$pesos]) {
    if (abs(cash_out_pesos($coins) - $pesos) > 0.00001) {
        throw new RuntimeException('Unexpected cash-out quote.');
    }
}
echo "Server coin conversion checks passed.\n";

if (in_array('--database', $argv, true)) {
    require_once __DIR__ . '/../api/commands.php';
    $db = db();
    $db->beginTransaction();
    try {
        $before = (float)query($db, 'SELECT available FROM wallets WHERE user_id=?', ['ben'])->fetchColumn();
        command($db, 'ben', 'topUp', ['pesos'=>100, 'method'=>'Card Simulation']);
        $toppedUp = (float)query($db, 'SELECT available FROM wallets WHERE user_id=?', ['ben'])->fetchColumn();
        if (abs($toppedUp - $before - 110) > 0.00001) throw new RuntimeException('Top-up did not credit 110 coins.');
        $topUpNote = query($db, "SELECT note FROM wallet_entries WHERE user_id=? AND type='Top Up' ORDER BY id DESC LIMIT 1", ['ben'])->fetchColumn();
        if (!str_contains($topUpNote, 'Card Simulation')) throw new RuntimeException('Top-up ledger lost the chosen payment method.');
        try {
            command($db, 'ben', 'topUp', ['pesos'=>100, 'method'=>'Unsupported']);
            throw new RuntimeException('Unsupported top-up method was accepted.');
        } catch (ApiError $e) {
            if (!str_contains($e->getMessage(), 'payment method')) throw $e;
        }
        if ((float)query($db, 'SELECT available FROM wallets WHERE user_id=?', ['ben'])->fetchColumn() !== $toppedUp) throw new RuntimeException('Rejected payment changed the wallet.');
        command($db, 'ben', 'cashOut', ['coins'=>110, 'phone'=>'09171234567']);
        $after = (float)query($db, 'SELECT available FROM wallets WHERE user_id=?', ['ben'])->fetchColumn();
        if (abs($after - $before) > 0.00001) throw new RuntimeException('Cash-out did not deduct 110 coins.');
        $note = query($db, "SELECT note FROM wallet_entries WHERE user_id=? AND type='Cash Out' ORDER BY id DESC LIMIT 1", ['ben'])->fetchColumn();
        if (!str_contains($note, '₱80')) throw new RuntimeException('Cash-out ledger does not match the peso quote.');
    } finally {
        $db->rollBack();
    }
    echo "Database conversion checks passed; test changes rolled back.\n";
}
