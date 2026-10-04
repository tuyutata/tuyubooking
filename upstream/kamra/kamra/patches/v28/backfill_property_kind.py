import frappe


def execute():
	"""Default existing properties to Hotel (ADR-005). Idempotent."""
	if not frappe.db.has_column("Property", "property_kind"):
		return
	frappe.db.sql(
		"""
		UPDATE `tabProperty`
		SET property_kind = 'Hotel'
		WHERE COALESCE(property_kind, '') = ''
		"""
	)
	frappe.clear_cache(doctype="Property")
