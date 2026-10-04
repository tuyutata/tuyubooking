<?php

use HiEvents\Http\Actions\Tuyu\ConsumeAdministratorAssertionAction;
use Illuminate\Support\Facades\Route;

Route::post('/tuyu-admin/consume', ConsumeAdministratorAssertionAction::class)
    ->name('tuyu.admin.consume');
