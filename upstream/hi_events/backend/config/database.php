<?php

declare(strict_types=1);

$parseUrl = static fn (?string $value): array => $value ? (parse_url($value) ?: []) : [];
$applicationUrl = $parseUrl(env('DATABASE_URL'));
$coreUrl = $parseUrl(env('TUYU_CORE_DATABASE_URL'));
$database = isset($applicationUrl['path']) ? ltrim($applicationUrl['path'], '/') : env('DB_DATABASE', 'tuyubooking');
$schema = env('DB_SCHEMA', 'module_hi_events');
$applicationSearchPath = $schema . ',tuyu_core,pg_catalog';

if (env('TUYU_BOOKING_RUNTIME', false) && ($database !== 'tuyubooking' || $schema !== 'module_hi_events')) {
    throw new RuntimeException('TuyuBooking Hi.Events must use tuyubooking.module_hi_events');
}

$connection = static function (array $url, string $defaultUser, string $searchPath): array {
    return [
        'driver' => 'pgsql',
        'url' => null,
        'host' => $url['host'] ?? env('DB_HOST', '127.0.0.1'),
        'port' => $url['port'] ?? env('DB_PORT', '5432'),
        'database' => isset($url['path']) ? ltrim($url['path'], '/') : env('DB_DATABASE', 'tuyubooking'),
        'username' => $url['user'] ?? $defaultUser,
        'password' => $url['pass'] ?? env('DB_PASSWORD', ''),
        'charset' => 'utf8',
        'prefix' => '',
        'prefix_indexes' => true,
        'search_path' => $searchPath,
        'sslmode' => 'prefer',
    ];
};

return [
    'default' => 'pgsql',
    'connections' => [
        // Business tables stay in module_hi_events while shared PostgreSQL
        // extensions and TuyuBooking contracts remain visible from tuyu_core.
        'pgsql' => $connection($applicationUrl, env('DB_USERNAME', 'tuyu_hi_events_app'), $applicationSearchPath),
        'tuyu_core' => $connection($coreUrl, env('TUYU_CORE_DB_USERNAME', env('DB_USERNAME', '')), 'tuyu_core,pg_catalog'),
    ],
    'migrations' => 'migrations',
];
