#!/usr/bin/env python3
"""Run the Step 4 Kamra and URY business flows against real Frappe sites.

The script intentionally calls upstream document controllers and upstream
integration tests. It does not create replacement tables or mock the business
services that TuyuBooking ships.
"""

from __future__ import annotations

import argparse
import json
import os
import unittest
from pathlib import Path
from typing import Any

import frappe


def _run_suite(suite: unittest.TestSuite, label: str) -> None:
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        raise AssertionError(f"{label} failed: failures={len(result.failures)} errors={len(result.errors)}")


def _delete_document(doctype: str, name: str | None) -> None:
    if not name or not frappe.db.exists(doctype, name):
        return
    document = frappe.get_doc(doctype, name)
    if getattr(document, "docstatus", 0) == 1:
        document.cancel()
    frappe.delete_doc(doctype, name, ignore_permissions=True, force=1)


def _cleanup_kamra_restaurant(property_name: str) -> None:
    for doctype in ("POS Order", "Menu Item", "POS Outlet"):
        for name in frappe.get_all(doctype, filters={"property": property_name}, pluck="name"):
            _delete_document(doctype, name)
    _delete_document("Property", property_name)


def _run_kamra_restaurant_flow() -> dict[str, Any]:
    property_name = "Tuyu Step4 Hotel Restaurant"
    _cleanup_kamra_restaurant(property_name)

    try:
        property_doc = frappe.get_doc(
            {
                "doctype": "Property",
                "property_name": property_name,
                "city": "Tuyu Test City",
                "state": "Tuyu Test State",
            }
        ).insert(ignore_permissions=True)
        outlet = frappe.get_doc(
            {
                "doctype": "POS Outlet",
                "property": property_doc.name,
                "outlet_name": "Tuyu Dining Room",
                "outlet_type": "Restaurant",
                "gst_rate": 5,
            }
        ).insert(ignore_permissions=True)
        menu_item = frappe.get_doc(
            {
                "doctype": "Menu Item",
                "property": property_doc.name,
                "outlet": outlet.name,
                "item_name": "Tuyu Breakfast",
                "category": "Breakfast",
                "course": "Main",
                "price": 88,
                "available": 1,
            }
        ).insert(ignore_permissions=True)
        order = frappe.get_doc(
            {
                "doctype": "POS Order",
                "property": property_doc.name,
                "outlet": outlet.name,
                "status": "Placed",
                "order_type": "Dine In",
                "table_no": "T-01",
                "guests": 2,
                "items": [
                    {
                        "menu_item": menu_item.name,
                        "item_name": menu_item.item_name,
                        "qty": 2,
                        "rate": 88,
                    }
                ],
            }
        ).insert(ignore_permissions=True)

        assert float(order.subtotal) == 176.0
        assert float(order.order_total) == 176.0
        order.status = "Delivered"
        order.save(ignore_permissions=True)
        order.reload()
        assert order.status == "Delivered"
        assert len(order.items) == 1

        return {
            "property": property_doc.name,
            "outlet": outlet.name,
            "menu_item": menu_item.name,
            "order": order.name,
            "total": float(order.order_total),
        }
    finally:
        _cleanup_kamra_restaurant(property_name)
        frappe.db.commit()


def run_hotel() -> dict[str, Any]:
    from kamra.scripts.test_booking_flow import run_tests

    run_tests()
    restaurant = _run_kamra_restaurant_flow()
    return {"module": "hotel", "lodging": "passed", "restaurant": restaurant}


def _run_ury_order_flow() -> dict[str, Any]:
    from ury.ury.doctype.ury_order.ury_order import sync_order
    from ury.ury_pos.test_e2e_p0_p1_flow import TestP0P1EndToEndFlow

    table_name = "_Tuyu Step4 Table"
    menu_name = "_Tuyu Step4 Menu"
    item_code = "_TUYU-STEP4-MEAL"
    customer_name = "_Tuyu Step4 Customer"
    result_holder: dict[str, Any] = {}

    class TuyuRestaurantOrderFlow(TestP0P1EndToEndFlow):
        def test_tuyu_menu_table_and_order_flow(self) -> None:
            invoice_name: str | None = None
            price_list_name: str | None = None
            original_invoice_type = frappe.db.get_single_value("POS Settings", "invoice_type")
            frappe.set_user("Administrator")
            for doctype, name in (
                ("URY Table", table_name),
                ("URY Menu", menu_name),
                ("Item", item_code),
                ("Customer", customer_name),
            ):
                _delete_document(doctype, name)

            try:
                # URY sync_order creates POS Invoice documents; preserve the site's setting.
                frappe.db.set_single_value("POS Settings", "invoice_type", "POS Invoice")
                customer_group = frappe.db.get_value("Customer Group", {"is_group": 0}, "name")
                territory = frappe.db.get_value("Territory", {"is_group": 0}, "name")
                item_group = frappe.db.get_value("Item Group", {"is_group": 0}, "name")
                stock_uom = frappe.db.get_value("UOM", {}, "name") or "Nos"
                self.assertTrue(customer_group and territory and item_group)

                customer = frappe.get_doc(
                    {
                        "doctype": "Customer",
                        "name": customer_name,
                        "customer_name": customer_name,
                        "customer_type": "Individual",
                        "customer_group": customer_group,
                        "territory": territory,
                    }
                ).insert(ignore_permissions=True)
                item = frappe.get_doc(
                    {
                        "doctype": "Item",
                        "item_code": item_code,
                        "item_name": "Tuyu Step4 Meal",
                        "item_group": item_group,
                        "stock_uom": stock_uom,
                        "is_stock_item": 0,
                        "standard_rate": 68,
                    }
                ).insert(ignore_permissions=True)
                menu = frappe.get_doc(
                    {
                        "doctype": "URY Menu",
                        "name": menu_name,
                        "branch": self.branch.name,
                        "enabled": 1,
                        "items": [
                            {
                                "item": item.name,
                                "item_name": item.item_name,
                                "rate": 68,
                            }
                        ],
                    }
                ).insert(ignore_permissions=True)
                price_list_name = menu.price_list
                self.restaurant.active_menu = menu.name
                self.restaurant.save(ignore_permissions=True)
                table = frappe.get_doc(
                    {
                        "doctype": "URY Table",
                        "name": table_name,
                        "restaurant": self.restaurant.name,
                        "restaurant_room": self.restaurant.default_room,
                        "branch": self.branch.name,
                        "no_of_seats": 4,
                    }
                ).insert(ignore_permissions=True)

                frappe.set_user(self.cashier.name)
                result = sync_order(
                    items=[
                        {
                            "item": item.name,
                            "item_name": item.item_name,
                            "qty": 2,
                            "comment": "Step4 acceptance",
                        }
                    ],
                    cashier="untrusted-client-cashier",
                    owner="untrusted-client-owner",
                    mode_of_payment="Cash",
                    customer=customer.name,
                    no_of_pax=2,
                    last_invoice=None,
                    waiter="untrusted-client-waiter",
                    pos_profile=self.pos_profile.name,
                    table=table.name,
                    order_type="Dine In",
                    room=self.restaurant.default_room,
                )
                invoice_name = result["name"]
                invoice = frappe.get_doc("POS Invoice", invoice_name)
                self.assertEqual(invoice.restaurant_table, table.name)
                self.assertEqual(invoice.branch, self.branch.name)
                self.assertEqual(invoice.waiter, self.cashier.name)
                self.assertEqual(invoice.cashier, self.cashier.name)
                self.assertEqual(len(invoice.items), 1)
                self.assertEqual(invoice.items[0].item_code, item.name)
                self.assertEqual(float(invoice.items[0].qty), 2.0)
                self.assertGreater(float(invoice.grand_total), 0.0)
                result_holder.update(
                    {
                        "restaurant": self.restaurant.name,
                        "table": table.name,
                        "menu": menu.name,
                        "invoice": invoice.name,
                        "total": float(invoice.grand_total),
                    }
                )
            finally:
                frappe.set_user("Administrator")
                frappe.db.set_single_value("POS Settings", "invoice_type", original_invoice_type)
                _delete_document("POS Invoice", invoice_name)
                _delete_document("URY Table", table_name)
                if frappe.db.exists("URY Restaurant", self.restaurant.name):
                    frappe.db.set_value("URY Restaurant", self.restaurant.name, "active_menu", None)
                _delete_document("URY Menu", menu_name)
                _delete_document("Price List", price_list_name)
                _delete_document("Item", item_code)
                _delete_document("Customer", customer_name)

    suite = unittest.TestSuite([TuyuRestaurantOrderFlow("test_tuyu_menu_table_and_order_flow")])
    _run_suite(suite, "URY menu/table/order flow")
    return result_holder


def run_restaurant() -> dict[str, Any]:
    from ury.ury_pos.test_e2e_p0_p1_flow import TestP0P1EndToEndFlow

    # Setup Wizard data belongs to the installed site, not to one test case.
    # Commit it before FrappeTestCase opens its rollback-only transaction.
    bootstrap = TestP0P1EndToEndFlow("test_opening_checklist_to_kot_visibility_flow")
    bootstrap._ensure_company()
    frappe.db.commit()

    upstream = unittest.TestLoader().loadTestsFromTestCase(TestP0P1EndToEndFlow)
    _run_suite(upstream, "URY upstream P0/P1 flow")
    order = _run_ury_order_flow()
    return {"module": "restaurant", "upstream_pos": "passed", "order": order}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bench", required=True, type=Path)
    parser.add_argument("--site", required=True)
    parser.add_argument("--module", required=True, choices=("hotel", "restaurant"))
    args = parser.parse_args()

    bench = args.bench.resolve()
    # Direct Frappe processes resolve the bench root from the sites directory.
    os.chdir(bench / "sites")
    frappe.init(site=args.site, sites_path=str(bench / "sites"))
    frappe.connect()
    frappe.flags.in_test = True
    frappe.set_user("Administrator")
    try:
        result = run_hotel() if args.module == "hotel" else run_restaurant()
        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception:
        frappe.db.rollback()
        raise
    finally:
        frappe.destroy()


if __name__ == "__main__":
    raise SystemExit(main())
