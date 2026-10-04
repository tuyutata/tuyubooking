enum AuthStatus {
  unchecked,
  checking,
  requiresInitialization,
  idle,
  requestingChallenge,
  awaitingSignature,
  verifying,
  authenticated,
  failed,
}
