<?php
declare(strict_types=1);

function migratePurchaseCurrency(PDO $db): void {
    // Existing errands keep their original secured coin amounts and refunds.
    $columns = [
        ['errands', 'budget_currency', "VARCHAR(3) NOT NULL DEFAULT 'CY'"],
        ['errands', 'budget_method', "VARCHAR(60) NOT NULL DEFAULT 'Legacy coins'"],
        ['wallet_entries', 'currency', "VARCHAR(3) NOT NULL DEFAULT 'CY'"],
        ['wallet_entries', 'peso_amount', 'DECIMAL(12,2) NULL'],
        ['messages', 'recipient_id', 'VARCHAR(64) NULL'],
        ['errands', 'cancel_requested_by', 'VARCHAR(64) NULL'],
        ['errands', 'cancel_requested_at', 'DATETIME(6) NULL'],
        ['errands', 'cancel_reviewed_by', 'VARCHAR(64) NULL'],
        ['errands', 'cancel_refund_coins', 'DECIMAL(12,2) NULL'],
        ['errands', 'cancel_refund_purchase', 'DECIMAL(12,2) NULL'],
        ['errands', 'cancel_runner_payment', 'DECIMAL(12,2) NULL'],
        ['errands', 'pin_reset_at', 'DATETIME(6) NULL'],
        ['errands', 'pickup_lat', 'DOUBLE NULL'],
        ['errands', 'pickup_lon', 'DOUBLE NULL'],
        ['errands', 'destination_lat', 'DOUBLE NULL'],
        ['errands', 'destination_lon', 'DOUBLE NULL'],
        ['errands', 'distance_source', "VARCHAR(20) NOT NULL DEFAULT 'manual'"],
        ['errands', 'route_seconds', 'DOUBLE NULL'],
    ];
    foreach ($columns as [$table, $column, $definition]) {
        $exists = query($db, 'SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=? AND COLUMN_NAME=?', [$table, $column])->fetchColumn();
        if (!$exists) $db->exec("ALTER TABLE `$table` ADD COLUMN `$column` $definition");
    }
    // Make older unresolved cancellation reports actionable without changing balances.
    $pending = query($db,"SELECT e.id,r.user_id,r.reason FROM errands e JOIN reports r ON r.errand_id=e.id WHERE e.status IN ('accepted','ongoing','waiting') AND e.cancel_requested_by IS NULL AND r.reason LIKE 'Cancellation request:%' AND r.status IN ('Submitted','Under Review') ORDER BY r.id DESC")->fetchAll();
    foreach ($pending as $r) query($db,'UPDATE errands SET cancel_requested_by=?,cancel_requested_at=UTC_TIMESTAMP(6),cancellation_reason=? WHERE id=? AND cancel_requested_by IS NULL',[$r['user_id'],trim(substr($r['reason'],strlen('Cancellation request:'))),$r['id']]);
    $db->exec('CREATE TABLE IF NOT EXISTS map_cache (cache_key VARCHAR(64) PRIMARY KEY,payload MEDIUMTEXT NOT NULL,expires_at DATETIME(6) NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');
}
