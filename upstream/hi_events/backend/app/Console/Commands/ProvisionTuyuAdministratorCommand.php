<?php

declare(strict_types=1);

namespace HiEvents\Console\Commands;

use HiEvents\DomainObjects\Enums\Role;
use HiEvents\Models\Account;
use HiEvents\Models\AccountUser;
use HiEvents\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

final class ProvisionTuyuAdministratorCommand extends Command
{
    protected $signature = 'tuyu:provision-administrator';
    protected $description = 'Provision the TuyuBooking technical administrator';

    public function handle(): int
    {
        $password = (string) env('TUYU_HI_EVENTS_ADMIN_PASSWORD');
        if (strlen($password) < 32) return self::FAILURE;
        $account = Account::query()->firstOrCreate(
            ['short_id' => 'tuyu-local'],
            ['name' => '途遇旅行', 'email' => 'tuyu-system-administrator@localhost',
             'currency_code' => 'CNY', 'timezone' => 'UTC'],
        );
        $user = User::query()->withTrashed()->firstOrNew(['email' => 'tuyu-system-administrator@localhost']);
        $user->fill(['password' => Hash::make($password), 'first_name' => '途遇系统管理员',
            'last_name' => null, 'timezone' => 'UTC', 'locale' => 'zh-cn',
            'email_verified_at' => now(), 'deleted_at' => null]);
        $user->save();
        AccountUser::query()->updateOrCreate(
            ['account_id' => $account->getKey(), 'user_id' => $user->getKey()],
            ['role' => Role::SUPERADMIN->value, 'status' => 'ACTIVE',
             'is_account_owner' => true, 'deleted_at' => null],
        );
        $this->info('TuyuBooking Hi.Events technical administrator is ready');
        return self::SUCCESS;
    }
}
