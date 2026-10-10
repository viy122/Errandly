<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/bootstrap.php';
require_once __DIR__ . '/migrations.php';
migratePurchaseCurrency(db());
echo "Currency, receipt, private conversation and recovery fields are ready. Existing balances and records were preserved.\n";
