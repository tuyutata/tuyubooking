import click
import frappe

from ury.setup_customizations import after_install as setup


def after_install():
    try:
        print("Setting up URY...")
        setup()
        frappe.db.set_single_value("System Settings", "language", "zh")
        frappe.db.set_default("lang", "zh")
        
        click.secho("Thank you for installing URY App!", fg="green")

        
    except Exception:
        frappe.log_error(title="TuyuBooking URY installation failed")
        raise
     
