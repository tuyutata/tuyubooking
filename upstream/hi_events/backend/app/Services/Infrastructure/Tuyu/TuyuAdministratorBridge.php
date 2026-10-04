<?php

declare(strict_types=1);

namespace HiEvents\Services\Infrastructure\Tuyu;

use HiEvents\DomainObjects\Enums\Role;
use HiEvents\Models\AccountUser;
use HiEvents\Models\User;
use Illuminate\Support\Facades\DB;
use PHPOpenSourceSaver\JWTAuth\JWTAuth;
use RuntimeException;

final readonly class TuyuAdministratorBridge
{
    private const TECHNICAL_EMAIL = 'tuyu-system-administrator@localhost';

    public function __construct(private JWTAuth $jwtAuth)
    {
    }

    public function consume(string $assertionToken, string $requestPath): array
    {
        $assertionHex = hash('sha256', $assertionToken);
        $core = DB::connection('tuyu_core');

        return $core->transaction(function () use ($core, $assertionHex, $requestPath): array {
            $assertion = $core->selectOne(
                "UPDATE tuyu_core.administrator_assertion
                 SET consumed_at = CURRENT_TIMESTAMP
                 WHERE assertion_hash = decode(?, 'hex')
                   AND consumed_at IS NULL AND revoked_at IS NULL
                   AND expires_at > CURRENT_TIMESTAMP
                   AND local_session_expires_at > CURRENT_TIMESTAMP
                   AND EXISTS (
                     SELECT 1 FROM tuyu_core.local_system_administrator administrator
                     WHERE administrator.installation_id = administrator_assertion.installation_id
                       AND administrator.id = administrator_assertion.administrator_id
                       AND administrator.status = 'active'
                   )
                 RETURNING *",
                [$assertionHex],
            );
            if ($assertion === null) {
                $core->insert(
                    "INSERT INTO tuyu_core.administrator_bridge_audit
                     (assertion_hash, action, outcome, request_path)
                     VALUES (decode(?, 'hex'), 'hi_events_assertion_consume', 'DENIED', ?)",
                    [$assertionHex, $requestPath],
                );
                throw new RuntimeException('Administrator assertion is invalid or expired');
            }

            $user = User::query()->where('email', self::TECHNICAL_EMAIL)->firstOrFail();
            $association = AccountUser::query()
                ->where('user_id', $user->getKey())->where('status', 'ACTIVE')->firstOrFail();
            User::setCurrentAccountId((int) $association->account_id);
            $token = $this->jwtAuth->claims([
                'account_id' => (int) $association->account_id,
                'role' => Role::SUPERADMIN->value,
                'tuyubooking_administrator' => true,
                'exp' => strtotime((string) $assertion->local_session_expires_at),
            ])->fromUser($user);
            $upstreamSessionId = hash('sha256', $token);

            $core->insert(
                "INSERT INTO tuyu_core.upstream_administrator_session
                 (upstream_session_id, assertion_hash, installation_id, administrator_id,
                  administrator_public_key_fingerprint, upstream_user, expires_at)
                 VALUES (?, decode(?, 'hex'), ?, ?, ?, ?, ?)",
                [$upstreamSessionId, $assertionHex, $assertion->installation_id,
                 $assertion->administrator_id, $assertion->administrator_public_key_fingerprint,
                 self::TECHNICAL_EMAIL, $assertion->local_session_expires_at],
            );
            $core->insert(
                "INSERT INTO tuyu_core.administrator_bridge_audit
                 (assertion_hash, upstream_session_id, installation_id, administrator_id,
                  administrator_public_key_fingerprint, action, outcome, request_path)
                 VALUES (decode(?, 'hex'), ?, ?, ?, ?, 'hi_events_assertion_consume', 'SUCCESS', ?)",
                [$assertionHex, $upstreamSessionId, $assertion->installation_id,
                 $assertion->administrator_id, $assertion->administrator_public_key_fingerprint,
                 $requestPath],
            );
            return ['token' => $token, 'redirect' => '/manage/events'];
        });
    }
}
