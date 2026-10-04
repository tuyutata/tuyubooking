<?php

declare(strict_types=1);

namespace HiEvents\Http\Actions\Tuyu;

use HiEvents\Services\Infrastructure\Tuyu\TuyuAdministratorBridge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

final readonly class ConsumeAdministratorAssertionAction
{
    public function __construct(private TuyuAdministratorBridge $bridge)
    {
    }

    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'assertion_token' => ['required', 'string', 'min:40', 'max:2048'],
        ]);
        try {
            return response()->json($this->bridge->consume($validated['assertion_token'], $request->path()));
        } catch (Throwable) {
            return response()->json(['message' => __('Administrator assertion was rejected')], 401);
        }
    }
}
