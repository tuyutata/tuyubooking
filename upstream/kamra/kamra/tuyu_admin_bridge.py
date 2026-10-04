"""One-time local administrator hand-off into the Frappe runtimes.

Native stores only a SHA-256 digest in local PostgreSQL. This adapter consumes
it atomically and never receives or stores an administrator private key.
"""

import hashlib
import re

import frappe
from frappe.auth import LoginManager

ADMIN_USER = "tuyu-system-administrator@localhost"
TOKEN_PATTERN = re.compile(r"^[0-9a-f]{64}$")
ADMIN_TARGETS = {"kamra": "/kamra", "ury": "/pos"}


@frappe.whitelist(allow_guest=True)
def consume(assertion: str, target: str = "kamra"):
	if getattr(frappe.request, "method", "GET") != "POST":
		frappe.throw("POST required", frappe.PermissionError)
	if not TOKEN_PATTERN.fullmatch(assertion or ""):
		_record_denial(None, "INVALID_FORMAT")
		frappe.throw("Invalid or expired administrator assertion", frappe.AuthenticationError)
	redirect_to = ADMIN_TARGETS.get(target)
	if redirect_to is None:
		_record_denial(None, "INVALID_TARGET")
		frappe.throw("Invalid administrator target", frappe.PermissionError)

	digest = hashlib.sha256(assertion.encode("ascii")).hexdigest()
	rows = frappe.db.sql(
		"""
		UPDATE tuyu_core.administrator_assertion
		SET consumed_at = CURRENT_TIMESTAMP
		WHERE assertion_hash = decode(%s, 'hex')
		  AND consumed_at IS NULL
		  AND revoked_at IS NULL
		  AND expires_at > CURRENT_TIMESTAMP
		  AND local_session_expires_at > CURRENT_TIMESTAMP
		  AND EXISTS (
			SELECT 1 FROM tuyu_core.local_system_administrator administrator
			WHERE administrator.installation_id = administrator_assertion.installation_id
			  AND administrator.id = administrator_assertion.administrator_id
			  AND administrator.status = 'active'
		  )
		RETURNING installation_id, administrator_id,
		          administrator_public_key_fingerprint, local_session_expires_at
		""",
		(digest,),
		as_dict=True,
	)
	if not rows:
		_record_denial(digest, "REPLAY_EXPIRED_REVOKED_OR_FOREIGN")
		frappe.throw("Invalid or expired administrator assertion", frappe.AuthenticationError)

	identity = rows[0]
	_ensure_system_administrator()
	login_manager = getattr(frappe.local, "login_manager", None) or LoginManager()
	frappe.local.login_manager = login_manager
	login_manager.login_as(ADMIN_USER)
	upstream_session_id = frappe.session.sid
	frappe.db.sql(
		"""
		INSERT INTO tuyu_core.upstream_administrator_session (
			upstream_session_id, assertion_hash, installation_id, administrator_id,
			administrator_public_key_fingerprint, upstream_user, expires_at
		) VALUES (%s, decode(%s, 'hex'), %s, %s, %s, %s, %s)
		""",
		(
			upstream_session_id,
			digest,
			identity.installation_id,
			identity.administrator_id,
			identity.administrator_public_key_fingerprint,
			ADMIN_USER,
			identity.local_session_expires_at,
		),
	)
	_record_audit(identity, digest, upstream_session_id, "ASSERTION_CONSUMED", "SUCCESS")
	return {"redirect_to": redirect_to}


def validate_active_bridge_session():
	"""Reject an expired, revoked, deleted, or disabled administrator session."""
	if getattr(frappe.session, "user", None) != ADMIN_USER:
		return
	rows = frappe.db.sql(
		"""
		SELECT bridge.installation_id, bridge.administrator_id,
		       bridge.administrator_public_key_fingerprint, bridge.upstream_session_id
		FROM tuyu_core.upstream_administrator_session bridge
		JOIN tuyu_core.local_system_administrator administrator
		  ON administrator.installation_id = bridge.installation_id
		 AND administrator.id = bridge.administrator_id
		 AND administrator.status = 'active'
		WHERE bridge.upstream_session_id = %s
		  AND bridge.revoked_at IS NULL
		  AND bridge.expires_at > CURRENT_TIMESTAMP
		""",
		(frappe.session.sid,),
		as_dict=True,
	)
	if not rows:
		frappe.throw("Tuyu administrator session expired or revoked", frappe.AuthenticationError)
	frappe.flags.tuyubooking_administrator = rows[0]


def audit_administrator_request():
	identity = getattr(frappe.flags, "tuyubooking_administrator", None)
	request = getattr(frappe, "request", None)
	if not identity or not request or request.method not in {"POST", "PUT", "PATCH", "DELETE"}:
		return
	_record_audit(
		identity,
		None,
		identity.upstream_session_id,
		"ADMINISTRATOR_REQUEST",
		"SUCCESS",
		getattr(request, "path", None),
	)


def _ensure_system_administrator():
	if frappe.db.exists("User", ADMIN_USER):
		roles = set(frappe.get_roles(ADMIN_USER))
		if "System Manager" not in roles:
			frappe.get_doc("User", ADMIN_USER).add_roles("System Manager")
		return
	user = frappe.get_doc(
		{
			"doctype": "User",
			"email": ADMIN_USER,
			"first_name": "Tuyu System Administrator",
			"enabled": 1,
			"user_type": "System User",
			"send_welcome_email": 0,
			"roles": [{"role": "System Manager"}],
		}
	)
	user.flags.ignore_password_policy = True
	user.insert(ignore_permissions=True)


def _record_denial(digest, reason):
	if digest is None:
		frappe.db.sql(
			"""
			INSERT INTO tuyu_core.administrator_bridge_audit
				(action, outcome, request_path)
			VALUES (%s, 'DENIED', %s)
			""",
			(reason, getattr(getattr(frappe, "request", None), "path", None)),
		)
		return
	frappe.db.sql(
		"""
		INSERT INTO tuyu_core.administrator_bridge_audit
			(assertion_hash, action, outcome, request_path)
		VALUES (decode(%s, 'hex'), %s, 'DENIED', %s)
		""",
		(digest, reason, getattr(getattr(frappe, "request", None), "path", None)),
	)


def _record_audit(identity, digest, upstream_session_id, action, outcome, request_path=None):
	if digest is None:
		frappe.db.sql(
			"""
			INSERT INTO tuyu_core.administrator_bridge_audit (
				upstream_session_id, installation_id, administrator_id,
				administrator_public_key_fingerprint, action, outcome, request_path
			) VALUES (%s, %s, %s, %s, %s, %s, %s)
			""",
			(
				upstream_session_id,
				identity.installation_id,
				identity.administrator_id,
				identity.administrator_public_key_fingerprint,
				action,
				outcome,
				request_path,
			),
		)
		return
	frappe.db.sql(
		"""
		INSERT INTO tuyu_core.administrator_bridge_audit (
			assertion_hash, upstream_session_id, installation_id, administrator_id,
			administrator_public_key_fingerprint, action, outcome, request_path
		) VALUES (decode(%s, 'hex'), %s, %s, %s, %s, %s, %s, %s)
		""",
		(
			digest,
			upstream_session_id,
			identity.installation_id,
			identity.administrator_id,
			identity.administrator_public_key_fingerprint,
			action,
			outcome,
			request_path,
		),
	)
