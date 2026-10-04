<?php

return [
    'webhook_queue_name' => env('WEBHOOK_QUEUE_NAME', 'webhook-queue'),
    'default' => 'database',
    'connections' => [
        'database' => [
            'driver' => 'database',
            'connection' => 'pgsql',
            'table' => 'jobs',
            'queue' => 'default',
            'retry_after' => 90,
            'after_commit' => true,
        ],
    ],
    'batching' => ['database' => 'pgsql', 'table' => 'job_batches'],
    'failed' => [
        'driver' => env('QUEUE_FAILED_DRIVER', 'database-uuids'),
        'database' => 'pgsql',
        'table' => 'failed_jobs',
    ],
];
