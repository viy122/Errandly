<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/bootstrap.php';
$name = config()['database'];
if (!preg_match('/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/',$name)) throw new RuntimeException('Invalid database name.');
$db = db(false);
$db->exec('CREATE DATABASE IF NOT EXISTS `' . $name . '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
$db->exec('USE `' . $name . '`');
foreach (explode(';',file_get_contents(__DIR__ . '/schema.sql')) as $sql) if (trim($sql) !== '') $db->exec($sql);
require_once __DIR__ . '/migrations.php';
migratePurchaseCurrency($db);
echo "Database {$name} and tables are ready. Existing records were preserved.\n";
if (in_array('--seed-demo',$argv,true)) {
    requireDemo();
    require __DIR__ . '/seed.php';
    seedDemo($db);
}
