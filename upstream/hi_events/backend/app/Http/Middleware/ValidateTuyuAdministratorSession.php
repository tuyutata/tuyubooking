<?php

declare(strict_types=1);

namespace HiEvents\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use PHPOpenSourceSaver\JWTAuth\JWTAuth;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

final readonly class ValidateTuyuAdministratorSession
{
    public function __construct(private JWTAuth $jwtAuth)
    {
    }

    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();
        if ($token === null) return $next($request);
        try {
            $payload = $this->jwtAuth->setToken($token)->getPayload();
            if (!$payload->get('tuyubooking_administrator')) return $next($request);
            $sessionId = hash('sha256', $token);
            $core = DB::connection('tuyu_core');
            $session = $core->selectOne(
                "SELECT bridge.* FROM tuyu_core.upstream_administrator_session bridge
                 JOIN tuyu_core.local_system_administrator administrator
                   ON administrator.installation_id = bridge.installation_id
                  AND administrator.id = bridge.administrator_id
                  AND administrator.status = 'active'
                 WHERE bridge.upstream_session_id = ?
                   AND bridge.upstream_user = 'tuyu-system-administrator@localhost'
                   AND bridge.revoked_at IS NULL AND bridge.expires_at > CURRENT_TIMESTAMP",
                [$sessionId],
            );
            if ($session === null) throw new \RuntimeException('Tuyu administrator session is not active');
            $response = $next($request);
            if (!in_array($request->method(), ['GET', 'HEAD', 'OPTIONS'], true)) {
                $core->insert(
                    "INSERT INTO tuyu_core.administrator_bridge_audit
                     (upstream_session_id, installation_id, administrator_id,
                      administrator_public_key_fingerprint, action, outcome, request_path)
                     VALUES (?, ?, ?, ?, 'hi_events_administrator_write', 'SUCCESS', ?)",
                    [$sessionId, $session->installation_id, $session->administrator_id,
                     $session->administrator_public_key_fingerprint, $request->path()],
                );
            }
            return $response;
        } catch (Throwable) {
            return response()->json(['message' => __('Administrator session has expired')], 401);
        }
    }
}
