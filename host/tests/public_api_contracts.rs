use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use schnorrkel::{signing_context, ExpansionMode, MiniSecretKey};
use tuyubooking_native::public_api::{
    validate_booking_request, validate_quote_request, verify_traveler, BookingRequest,
    QuoteRequest, TravelerEnvelope, BOOKING_PATH, QUOTE_PATH,
};

fn envelope<T: serde::Serialize>(value: &T) -> TravelerEnvelope {
    let payload = serde_json::to_vec(value).expect("serialize request");
    let pair = MiniSecretKey::from_bytes(&[7_u8; 32])
        .expect("mini secret")
        .expand_to_keypair(ExpansionMode::Ed25519);
    let signature = pair.sign(signing_context(b"substrate").bytes(&payload));
    TravelerEnvelope {
        signed_payload: URL_SAFE_NO_PAD.encode(payload),
        signature: format!("0x{}", hex(signature.to_bytes())),
        account_id: format!("0x{}", hex(pair.public.to_bytes())),
        tuyu_id: "TUYU-TRAVELER".to_owned(),
    }
}

fn hex(bytes: impl AsRef<[u8]>) -> String {
    bytes
        .as_ref()
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

#[test]
fn traveler_quote_and_booking_contracts_are_signed_and_strict() {
    assert_eq!(QUOTE_PATH, "/tuyu/v1/quotes");
    assert_eq!(BOOKING_PATH, "/tuyu/v1/bookings");
    let quote = QuoteRequest {
        action: "quote".to_owned(),
        request_id: format!("tqr_{}", "1".repeat(32)),
        listing_id: format!("tli_{}", "2".repeat(32)),
        quantity: 1,
        requested_for: "2026-09-01T00:00:00.000Z".to_owned(),
    };
    let verified: QuoteRequest = verify_traveler(&envelope(&quote)).expect("verify quote");
    validate_quote_request(&verified).expect("valid quote contract");

    let booking = BookingRequest {
        action: "booking".to_owned(),
        request_id: format!("tbk_{}", "3".repeat(32)),
        listing_id: quote.listing_id,
        quote_id: "quote-1".to_owned(),
    };
    let verified: BookingRequest = verify_traveler(&envelope(&booking)).expect("verify booking");
    validate_booking_request(&verified).expect("valid booking contract");
}

#[test]
fn modified_traveler_payload_is_rejected() {
    let quote = QuoteRequest {
        action: "quote".to_owned(),
        request_id: format!("tqr_{}", "4".repeat(32)),
        listing_id: format!("tli_{}", "5".repeat(32)),
        quantity: 1,
        requested_for: "2026-09-01T00:00:00.000Z".to_owned(),
    };
    let mut signed = envelope(&quote);
    signed.signed_payload = URL_SAFE_NO_PAD.encode(b"{}");
    assert!(verify_traveler::<QuoteRequest>(&signed).is_err());
}
