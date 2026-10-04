<?php

use Illuminate\Support\Str;

return [
    'default' => 'database',
    'stores' => [
        'database' => [
            'driver' => 'database',
            'table' => 'cache',
            'connection' => 'pgsql',
            'lock_connection' => 'pgsql',
        ],
    ],
    'prefix' => env('CACHE_PREFIX', Str::slug('TuyuBooking Hi.Events', '_').'_cache_'),
];
