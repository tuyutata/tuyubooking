<?php

declare(strict_types=1);

use HiEvents\DomainObjects\Enums\EventCategory;
use HiEvents\DomainObjects\Enums\ProductPriceType;
use HiEvents\DomainObjects\Enums\ProductType;
use HiEvents\DomainObjects\Status\EventStatus;
use HiEvents\DomainObjects\Status\OrderStatus;
use HiEvents\Helper\IdHelper;
use HiEvents\Models\Account;
use HiEvents\Models\Attendee;
use HiEvents\Models\Order;
use HiEvents\Models\ProductCategory;
use HiEvents\Models\ProductPrice;
use HiEvents\Models\User;
use HiEvents\Services\Application\Handlers\Event\CreateEventHandler;
use HiEvents\Services\Application\Handlers\Event\DTO\CreateEventDTO;
use HiEvents\Services\Application\Handlers\Organizer\CreateOrganizerHandler;
use HiEvents\Services\Application\Handlers\Organizer\DTO\CreateOrganizerDTO;
use HiEvents\Services\Application\Handlers\Product\CreateProductHandler;
use HiEvents\Services\Application\Handlers\Product\DTO\UpsertProductDTO;
use HiEvents\Services\Domain\Product\DTO\ProductPriceDTO;
use Illuminate\Contracts\Console\Kernel as ConsoleKernel;
use Illuminate\Contracts\Http\Kernel as HttpKernel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;

/**
 * Standalone Hi.Events business acceptance test.
 *
 * The vendored runtime intentionally excludes PHPUnit and other development
 * packages. This script boots the real Laravel application, calls upstream
 * handlers and public HTTP routes, and rolls all acceptance data back.
 */

function requireCondition(bool $condition, string $message): void
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

/** @return array{status: int, body: array<string, mixed>} */
function sendJsonRequest(HttpKernel $kernel, string $method, string $uri, array $payload): array
{
    $request = Request::create(
        $uri,
        $method,
        [],
        [],
        [],
        [
            'HTTPS' => 'on',
            'HTTP_ACCEPT' => 'application/json',
            'CONTENT_TYPE' => 'application/json',
        ],
        json_encode($payload, JSON_THROW_ON_ERROR),
    );
    $response = $kernel->handle($request);
    $content = (string) $response->getContent();
    $kernel->terminate($request, $response);

    try {
        $body = json_decode($content, true, 512, JSON_THROW_ON_ERROR);
    } catch (JsonException $exception) {
        throw new RuntimeException(
            sprintf('Hi.Events returned non-JSON HTTP %d: %s', $response->getStatusCode(), $content),
            previous: $exception,
        );
    }

    return ['status' => $response->getStatusCode(), 'body' => $body];
}

$backendRoot = realpath(__DIR__ . '/../../upstream/hi_events/backend');
requireCondition($backendRoot !== false, 'Hi.Events backend directory is missing');
require $backendRoot . '/vendor/autoload.php';
$application = require $backendRoot . '/bootstrap/app.php';
$application->make(ConsoleKernel::class)->bootstrap();
$httpKernel = $application->make(HttpKernel::class);

DB::beginTransaction();
$exitCode = 0;

try {
    Queue::fake();
    Mail::fake();
    Bus::fake();

    $currentSchema = DB::selectOne('SELECT current_schema() AS name')->name ?? null;
    requireCondition($currentSchema === 'module_hi_events', 'Hi.Events escaped module_hi_events');

    $configurationId = DB::table('account_configuration')->value('id');
    requireCondition($configurationId !== null, 'Hi.Events default account configuration is missing');
    $account = Account::query()->create([
        'name' => 'Tuyu Step4 Account',
        'email' => 'step4-account@tuyu.invalid',
        'timezone' => 'Asia/Shanghai',
        'currency_code' => 'CNY',
        'country' => 'CN',
        'short_id' => IdHelper::shortId(IdHelper::ACCOUNT_PREFIX),
        'account_configuration_id' => $configurationId,
        'account_verified_at' => now(),
    ]);
    $user = User::query()->create([
        'email' => 'step4-admin@tuyu.invalid',
        'password' => password_hash(Str::random(32), PASSWORD_BCRYPT),
        'first_name' => 'Tuyu',
        'last_name' => 'Step4',
        'timezone' => 'Asia/Shanghai',
        'locale' => 'zh-cn',
        'email_verified_at' => now(),
    ]);
    Auth::login($user);

    $organizer = app(CreateOrganizerHandler::class)->handle(new CreateOrganizerDTO(
        name: 'Tuyu Step4 Organizer',
        email: 'step4-organizer@tuyu.invalid',
        account_id: $account->id,
        timezone: 'Asia/Shanghai',
        currency: 'CNY',
    ));
    $event = app(CreateEventHandler::class)->handle(new CreateEventDTO(
        title: 'Tuyu Step4 Activity',
        organizer_id: $organizer->getId(),
        account_id: $account->id,
        user_id: $user->id,
        start_date: now()->addDays(10)->toDateTimeString(),
        end_date: now()->addDays(11)->toDateTimeString(),
        description: 'TuyuBooking real PostgreSQL acceptance event',
        timezone: 'Asia/Shanghai',
        currency: 'CNY',
        category: EventCategory::OTHER,
        status: EventStatus::LIVE->name,
    ));
    $category = ProductCategory::query()->where('event_id', $event->getId())->firstOrFail();
    $product = app(CreateProductHandler::class)->handle(new UpsertProductDTO(
        account_id: $account->id,
        event_id: $event->getId(),
        product_category_id: $category->id,
        title: 'Tuyu Step4 General Ticket',
        type: ProductPriceType::FREE,
        product_type: ProductType::TICKET,
        prices: collect([new ProductPriceDTO(
            price: 0.0,
            label: 'General Admission',
            initial_quantity_available: 20,
        )]),
        max_per_order: 4,
        min_per_order: 1,
        description: 'Step4 acceptance ticket',
    ));
    $price = ProductPrice::query()->where('product_id', $product->getId())->firstOrFail();

    $sessionIdentifier = sha1('tuyubooking-step4-' . Str::uuid());
    $createResponse = sendJsonRequest(
        $httpKernel,
        'POST',
        '/public/events/' . $event->getId() . '/order?session_identifier=' . $sessionIdentifier,
        ['products' => [[
            'product_id' => $product->getId(),
            'quantities' => [['quantity' => 1, 'price_id' => $price->id]],
        ]]],
    );
    requireCondition(
        $createResponse['status'] === 201,
        sprintf(
            'Hi.Events order creation returned HTTP %d: %s',
            $createResponse['status'],
            json_encode($createResponse['body'], JSON_THROW_ON_ERROR),
        ),
    );
    $orderShortId = $createResponse['body']['data']['short_id'] ?? null;
    requireCondition(is_string($orderShortId) && $orderShortId !== '', 'Hi.Events order short ID is missing');

    $completeResponse = sendJsonRequest(
        $httpKernel,
        'PUT',
        '/public/events/' . $event->getId() . '/order/' . $orderShortId
            . '?session_identifier=' . $sessionIdentifier,
        [
            'order' => [
                'first_name' => 'Tuyu',
                'last_name' => 'Traveler',
                'email' => 'step4-traveler@tuyu.invalid',
                'email_confirmation' => 'step4-traveler@tuyu.invalid',
                'questions' => [],
            ],
            'products' => [[
                'product_id' => $product->getId(),
                'product_price_id' => $price->id,
                'first_name' => 'Tuyu',
                'last_name' => 'Traveler',
                'email' => 'step4-traveler@tuyu.invalid',
                'email_confirmation' => 'step4-traveler@tuyu.invalid',
                'questions' => [],
            ]],
        ],
    );
    requireCondition(
        $completeResponse['status'] === 200,
        sprintf(
            'Hi.Events order completion returned HTTP %d: %s',
            $completeResponse['status'],
            json_encode($completeResponse['body'], JSON_THROW_ON_ERROR),
        ),
    );
    requireCondition(
        ($completeResponse['body']['data']['status'] ?? null) === OrderStatus::COMPLETED->name,
        'Hi.Events order response is not completed',
    );

    $order = Order::query()->where('short_id', $orderShortId)->firstOrFail();
    requireCondition($order->event_id === $event->getId(), 'Hi.Events order event link is incorrect');
    requireCondition($order->status === OrderStatus::COMPLETED->name, 'Hi.Events order was not persisted as completed');
    requireCondition($order->session_id === $sessionIdentifier, 'Hi.Events checkout session link is incorrect');
    requireCondition(
        Attendee::query()->where('order_id', $order->id)->count() === 1,
        'Hi.Events did not create exactly one attendee',
    );

    echo json_encode([
        'module' => 'ticketing',
        'schema' => $currentSchema,
        'event_id' => $event->getId(),
        'order_status' => $order->status,
        'attendees' => 1,
        'status' => 'passed',
    ], JSON_THROW_ON_ERROR) . PHP_EOL;
} catch (Throwable $exception) {
    fwrite(STDERR, $exception::class . ': ' . $exception->getMessage() . PHP_EOL);
    $exitCode = 1;
} finally {
    if (DB::transactionLevel() > 0) {
        DB::rollBack();
    }
}

exit($exitCode);
