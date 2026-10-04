import frappe


def require_manager():
	"""Require a URY or system manager for every reporting endpoint."""
	allowed_roles = {"URY Manager", "System Manager"}
	user_roles = set(frappe.get_roles())
	if frappe.session.user == "Administrator":
		return
	if not allowed_roles & user_roles:
		frappe.throw("You do not have permission to access this report.", frappe.PermissionError)


def get_business_day_condition(date_expr="CURRENT_DATE", prefix="b"):
	return f"""(
		((rs.\"hours\" IS NULL OR rs.\"hours\" = 0) AND {prefix}.\"posting_date\" = {date_expr})
		OR (
			rs.\"hours\" > 0
			AND ({prefix}.\"posting_date\" + {prefix}.\"posting_time\")
				>= ({date_expr} + make_interval(hours => rs.\"hours\"::integer))
			AND ({prefix}.\"posting_date\" + {prefix}.\"posting_time\")
				< ({date_expr} + interval '1 day' + make_interval(hours => rs.\"hours\"::integer))
		)
		OR (rs.\"branch\" IS NULL AND {prefix}.\"posting_date\" = {date_expr})
	)"""


def get_prior_business_day_condition(date_expr="CURRENT_DATE", prefix="c"):
	return f"""(
		((rs.\"hours\" IS NULL OR rs.\"hours\" = 0) AND {prefix}.\"posting_date\" < {date_expr})
		OR (
			rs.\"hours\" > 0
			AND ({prefix}.\"posting_date\" + {prefix}.\"posting_time\")
				< ({date_expr} + make_interval(hours => rs.\"hours\"::integer))
		)
		OR (rs.\"branch\" IS NULL AND {prefix}.\"posting_date\" < {date_expr})
	)"""


def date_list_cte(start_param="start_date", end_param="end_date"):
	return (
		f"generate_series(%({start_param})s::date, %({end_param})s::date, "
		"interval '1 day') AS date_list(date)"
	)


def get_business_day_range_condition(start_param="start_date", end_param="end_date", prefix="b"):
	return f"""(
		((rs.\"hours\" IS NULL OR rs.\"hours\" = 0)
			AND {prefix}.\"posting_date\" BETWEEN %({start_param})s::date AND %({end_param})s::date)
		OR (
			rs.\"hours\" > 0
			AND ({prefix}.\"posting_date\" + {prefix}.\"posting_time\")
				>= (%({start_param})s::date + make_interval(hours => rs.\"hours\"::integer))
			AND ({prefix}.\"posting_date\" + {prefix}.\"posting_time\")
				< (%({end_param})s::date + interval '1 day' + make_interval(hours => rs.\"hours\"::integer))
		)
		OR (rs.\"branch\" IS NULL
			AND {prefix}.\"posting_date\" BETWEEN %({start_param})s::date AND %({end_param})s::date)
	)"""


def report_settings_join(prefix="b", branch_param="branch"):
	return f'LEFT JOIN "tabURY Report Settings" rs ON (rs."branch" = %({branch_param})s)'


def validate_date_range(start_date, end_date, max_days=366):
	if not start_date or not end_date:
		frappe.throw("Both start_date and end_date are required.")
	if frappe.utils.getdate(start_date) > frappe.utils.getdate(end_date):
		frappe.throw("start_date must not be after end_date.")
	if (frappe.utils.getdate(end_date) - frappe.utils.getdate(start_date)).days > max_days:
		frappe.throw(f"Date range cannot exceed {max_days} days.")
