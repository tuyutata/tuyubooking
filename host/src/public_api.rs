//! Signed public contract consumed directly by TuyuLove.
//!
//! The merchant instance remains authoritative for live quotes and bookings.
//! TuyuServe only distributes the signed discovery endpoint and public key.

use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use schnorrkel::{signing_context, PublicKey, Signature};
use serde::{de::DeserializeOwned, Deserialize, Serialize};

pub const QUOTE_PATH: &str = "/tuyu/v1/quotes";
pub const BOOKING_PATH: &str = "/tuyu/v1/bookings";

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SignedEnvelope {
    pub signed_payload: String,
    pub signature: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TravelerEnvelope {
    pub signed_payload: String,
    pub signature: String,
    pub account_id: String,
    pub tuyu_id: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct QuoteRequest {
    pub action: String,
    pub request_id: String,
    pub listing_id: String,
    pub quantity: u16,
    pub requested_for: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BookingRequest {
    pub action: String,
    pub request_id: String,
    pub listing_id: String,
    pub quote_id: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct QuoteResponse {
    pub kind: String,
    pub quote_id: String,
    pub listing_id: String,
    pub quantity: u16,
    pub amount: u64,
    pub currency: String,
    pub expires_at: i64,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BookingResponse {
    pub kind: String,
    pub booking_id: String,
    pub quote_id: String,
    pub status: String,
    pub created_at: i64,
}

#[derive(Debug, thiserror::Error)]
pub enum PublicApiError {
    #[error("signed envelope is invalid")]
    InvalidEnvelope,
    #[error("signed payload is invalid")]
    InvalidPayload,
    #[error("sr25519 signature is invalid")]
    InvalidSignature,
    #[error("public contract constraints are invalid")]
    InvalidContract,
}

pub fn verify_traveler<T: DeserializeOwned>(
    envelope: &TravelerEnvelope,
) -> Result<T, PublicApiError> {
    let public_key =
        decode_hex::<32>(&envelope.account_id).ok_or(PublicApiError::InvalidEnvelope)?;
    verify_payload(&envelope.signed_payload, &envelope.signature, &public_key)
}

pub fn verify_instance<T: DeserializeOwned>(
    envelope: &SignedEnvelope,
    installation_public_key: &[u8; 32],
) -> Result<T, PublicApiError> {
    verify_payload(
        &envelope.signed_payload,
        &envelope.signature,
        installation_public_key,
    )
}

pub fn validate_quote_request(request: &QuoteRequest) -> Result<(), PublicApiError> {
    if request.action != "quote"
        || !is_id(&request.request_id, "tqr")
        || !is_id(&request.listing_id, "tli")
        || request.quantity == 0
        || request.quantity > 99
        || request.requested_for.trim().is_empty()
    {
        return Err(PublicApiError::InvalidContract);
    }
    Ok(())
}

pub fn validate_booking_request(request: &BookingRequest) -> Result<(), PublicApiError> {
    if request.action != "booking"
        || !is_id(&request.request_id, "tbk")
        || !is_id(&request.listing_id, "tli")
        || request.quote_id.trim().is_empty()
    {
        return Err(PublicApiError::InvalidContract);
    }
    Ok(())
}

fn verify_payload<T: DeserializeOwned>(
    encoded_payload: &str,
    encoded_signature: &str,
    public_key: &[u8; 32],
) -> Result<T, PublicApiError> {
    let payload = URL_SAFE_NO_PAD
        .decode(encoded_payload)
        .map_err(|_| PublicApiError::InvalidEnvelope)?;
    if payload.is_empty() || payload.len() > 32 * 1024 {
        return Err(PublicApiError::InvalidEnvelope);
    }
    let signature = decode_hex::<64>(encoded_signature).ok_or(PublicApiError::InvalidEnvelope)?;
    let public_key =
        PublicKey::from_bytes(public_key).map_err(|_| PublicApiError::InvalidEnvelope)?;
    let signature =
        Signature::from_bytes(&signature).map_err(|_| PublicApiError::InvalidEnvelope)?;
    public_key
        .verify(signing_context(b"substrate").bytes(&payload), &signature)
        .map_err(|_| PublicApiError::InvalidSignature)?;
    serde_json::from_slice(&payload).map_err(|_| PublicApiError::InvalidPayload)
}

fn decode_hex<const N: usize>(value: &str) -> Option<[u8; N]> {
    let raw = value.strip_prefix("0x")?;
    if raw.len() != N * 2 {
        return None;
    }
    let mut output = [0_u8; N];
    for (index, byte) in output.iter_mut().enumerate() {
        *byte = u8::from_str_radix(&raw[index * 2..index * 2 + 2], 16).ok()?;
    }
    Some(output)
}

fn is_id(value: &str, prefix: &str) -> bool {
    value
        .strip_prefix(&format!("{prefix}_"))
        .is_some_and(|suffix| {
            suffix.len() == 32 && suffix.bytes().all(|byte| byte.is_ascii_hexdigit())
        })
}
