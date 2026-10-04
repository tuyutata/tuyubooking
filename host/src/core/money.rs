use crate::core::DomainError;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;

/// ISO 4217-style three-letter currency code.
#[derive(Clone, Debug, Eq, Hash, Ord, PartialEq, PartialOrd, Serialize, Deserialize)]
#[serde(transparent)]
pub struct CurrencyCode(String);

impl CurrencyCode {
    pub fn new(value: impl Into<String>) -> Result<Self, DomainError> {
        let value = value.into();
        let valid = value.len() == 3
            && value
                .as_bytes()
                .iter()
                .all(|character| character.is_ascii_uppercase());

        if valid {
            Ok(Self(value))
        } else {
            Err(DomainError::InvalidCurrencyCode)
        }
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for CurrencyCode {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// Fixed-point monetary amount. No floating-point constructor is exposed.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Money {
    amount: Decimal,
    currency: CurrencyCode,
}

impl Money {
    pub const fn from_decimal(amount: Decimal, currency: CurrencyCode) -> Self {
        Self { amount, currency }
    }

    pub fn parse(amount: &str, currency: CurrencyCode) -> Result<Self, rust_decimal::Error> {
        Ok(Self::from_decimal(Decimal::from_str(amount)?, currency))
    }

    pub const fn amount(&self) -> Decimal {
        self.amount
    }

    pub fn currency(&self) -> &CurrencyCode {
        &self.currency
    }

    pub fn checked_add(&self, other: &Self) -> Result<Self, DomainError> {
        if self.currency != other.currency {
            return Err(DomainError::CurrencyMismatch);
        }

        Ok(Self::from_decimal(
            self.amount + other.amount,
            self.currency.clone(),
        ))
    }

    pub fn checked_sub(&self, other: &Self) -> Result<Self, DomainError> {
        if self.currency != other.currency {
            return Err(DomainError::CurrencyMismatch);
        }

        Ok(Self::from_decimal(
            self.amount - other.amount,
            self.currency.clone(),
        ))
    }
}
