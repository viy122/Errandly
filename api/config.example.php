<?php
// Copy to config.local.php. Never include database credentials in Flutter.
return [
    'host' => '127.0.0.1',
    'port' => 3306,
    'database' => 'errandly',
    'username' => 'root',
    'password' => '',
    // Development only: account switching, simulated payments and verification.
    'demo' => true,
    // Existing account IDs authorized to review cancellations. Never client supplied.
    'support_users' => [],
    // Public development services; replace with managed/self-hosted services for deployment.
    'geocoding_url' => 'https://nominatim.openstreetmap.org',
    'routing_url' => 'https://router.project-osrm.org',
    'maps_user_agent' => 'ErrandlyLocalDevelopment/1.0',
    'origins' => ['http://127.0.0.1:8089', 'http://localhost:8089', 'http://localhost', 'http://127.0.0.1'],
];
