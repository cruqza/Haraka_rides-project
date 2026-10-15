"""Regenerate the two staging CSVs the Haraka pipeline loads.

The original booking-app and fleet-system exports were lost; these CSVs are
schema-faithful sample data rebuilt from the column sets the SQL pipeline
reads (booking_system_staging.trips_staging and fleet_system_staging.fleet_staging).
They deliberately contain the same mess the cleaning SQL handles: mixed date
formats, 'null'/'n/a' strings, phone and plate formatting noise, duplicate
trip ids, and case-inconsistent categories.

Deterministic: random.seed(42). Output rows match the README:
trips_staging.csv 406 rows x 18 columns, fleet_staging.csv 106 rows x 17 columns.
"""

import csv
import random
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

random.seed(42)

AREAS = ["Westlands", "Kilimani", "Karen", "Lavington", "CBD", "Kileleshwa",
         "South B", "Roysambu", "Ngara", "Parklands", "Runda", "Syokimau"]
PAYMENTS = ["M-Pesa", "M-pesa", "Cash", "cash", "Card"]
STATUSES = ["Completed", "completed", "COMPLETED", "Cancelled", "cancelled", "Scheduled"]
DATE_FORMATS = ["iso", "dmy", "dmy2", "mdy"]
Nairobi = "Nairobi"


def make_names(prefix, count):
    firsts = ["Amina", "Brian", "Cynthia", "David", "Esther", "Faith", "Gideon", "Halima",
              "Ian", "Joy", "Kevin", "Lucy", "Mercy", "Njoroge", "Otieno", "Peter",
              "Rehema", "Samuel", "Terry", "Wanjiku"]
    lasts = ["Kamau", "Otieno", "Wafula", "Njeri", "Mutiso", "Chebet", "Achieng", "Kiptoo",
             "Amina", "Barasa", "Chirchir", "Dube", "Ekiru", "Fondo", "Gitau", "Hassan"]
    return {i: f"{prefix} {random.choice(firsts)} {random.choice(lasts)}" for i in range(1, count + 1)}


def phone(entity_id):
    return f"+254 7{random.randint(10, 99)} {random.randint(100, 999)}-{random.randint(100, 999)}"


def messy_date(base):
    fmt = random.choice(DATE_FORMATS)
    d, m, y = base.day, base.month, base.year
    if fmt == "iso":
        return f"{y}-{m:02d}-{d:02d}"
    if fmt == "dmy":
        return f"{d:02d}/{m:02d}/{y}"
    if fmt == "dmy2":
        return f"{d:02d}/{m:02d}/{str(y)[2:]}"
    return f"{m:02d}-{d:02d}-{y}"


def messy_number(value, unit=""):
    if random.random() < 0.85:
        return f"{value:g}"
    return random.choice([f"KSh {value:g}", f"{value:g} {unit}".strip(), f" {value:g} "])


# ---------------------------------------------------------------- trips_staging

customers = make_names("Cust", 120)
drivers = make_names("Drv", 15)
driver_phones = {i: phone(i) for i in drivers}
customer_phones = {i: phone(i) for i in customers}

plates = ["KDA 123A", "KDB 456B", "KDC 789C", "KDE 234D", "KDF 567E", "KDG 890F",
          "KDH 111G", "KDJ 222J", "KDK 333K", "KDL 444L"]
models = [("Toyota", "Axio"), ("Toyota", "Fielder"), ("Nissan", "Note"), ("Subaru", "Impreza"),
          ("Mazda", "Demio"), ("Toyota", "Sienta"), ("Nissan", "Tiida"), ("Mazda", "Axela"),
          ("Toyota", "Vitz"), ("Subaru", "Legacy")]

import datetime as _dt

start = _dt.date(2025, 3, 1)

trip_rows = []
for n in range(1, 407):
    trip_id = str(n) if n % 40 else str(random.randint(1, 366))  # a few duplicate ids
    day = start + _dt.timedelta(days=random.randint(0, 120))
    driver_id = random.randint(1, 15)
    customer_id = random.randint(1, 120)
    vehicle_idx = random.randint(0, len(plates) - 1)
    distance = round(random.uniform(2.0, 38.0), 1)
    fare = round(distance * random.uniform(55, 90) + 100, 0)
    rating = random.choices([f"{random.uniform(3.0, 5.0):.1f}", "n/a", "6.2", "null"],
                            weights=[0.85, 0.07, 0.04, 0.04])[0]
    trip_rows.append({
        "trip_id": trip_id,
        "trip_date": messy_date(day),
        "pickup_area": random.choice(AREAS) if random.random() > 0.03 else "  ",
        "pickup_time": f"{random.randint(5, 22):02d}:{random.choice(['05', '15', '30', '45'])}"
                       if random.random() > 0.05 else "null",
        "dropoff_area": random.choice(AREAS),
        "distance_km": messy_number(distance, "km"),
        "fare_amount": messy_number(fare),
        "payment_method": random.choice(PAYMENTS),
        "status": random.choice(STATUSES),
        "customer_rating": rating,
        "customer_name": customers[customer_id],
        "customer_phone": customer_phones[customer_id],
        "driver_name": drivers[driver_id],
        "driver_phone": driver_phones[driver_id],
        "driver_rating": f"{random.uniform(3.5, 5.0):.1f}",
        "vehicle_plate": random.choice([plates[vehicle_idx], plates[vehicle_idx].lower()]),
        "vehicle_model": models[vehicle_idx][1],
        "vehicle_year": random.choice([2015, 2016, 2017, 2018, 2019, 2020]),
    })

# --------------------------------------------------------------- fleet_staging

plate_details = {
    p: (models[i][0], models[i][1], random.choice([2015, 2016, 2017, 2018, 2019]),
        random.choice(["Saloon", "Hatchback"]), random.choice(["Active", "Active", "In service"]))
    for i, p in enumerate(plates)
}
mechanics = make_names("Mech", 8)

fleet_rows = []
for n in range(1, 107):
    plate = random.choice(plates)
    make, model, year, vtype, status = plate_details[plate]
    day = start + _dt.timedelta(days=random.randint(0, 120))
    row = {
        "vehicle_plate": random.choice([plate, plate.lower()]),
        "vehicle_make": random.choice([make, make.lower()]),
        "vehicle_model": model,
        "vehicle_year": year,
        "vehicle_type": vtype,
        "vehicle_status": status,
        "odometer_reading": random.randint(40000, 220000),
    }
    if n % 3:  # fuel event
        row.update({
            "event_type": random.choice(["Fuel", "fuel", "FUEL"]),
            "event_date": messy_date(day),
            "liters": f"{random.uniform(8, 45):.1f}",
            "fuel_cost": messy_number(round(random.uniform(1800, 6500), 2)),
            "fuel_brand": random.choice(["Shell FuelSave", "Total Excellium", "Rubis", "Goil"]),
            "station_name": random.choice(["Shell Westlands", "Total Kileleshwa", "Rubis Kilimani", "Goil Roysambu"]),
            "maintenance_cost": "",
            "mechanic_name": "",
            "next_service_due": "",
            "service_type": "",
        })
    else:  # maintenance event
        row.update({
            "event_type": random.choice(["Maintenance", "maintenance"]),
            "event_date": messy_date(day),
            "liters": "",
            "fuel_cost": "",
            "fuel_brand": "",
            "station_name": "",
            "maintenance_cost": messy_number(round(random.uniform(2500, 28000), 2)),
            "mechanic_name": mechanics[random.randint(1, 8)],
            "next_service_due": messy_date(day + _dt.timedelta(days=random.randint(30, 180))),
            "service_type": random.choice(["Oil change", "Brake pads", "Tyre rotation", "Engine service", "Suspension"]),
        })
    fleet_rows.append(row)

for name, rows in (("trips_staging.csv", trip_rows), ("fleet_staging.csv", fleet_rows)):
    with (REPO / name).open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

print(f"trips_staging.csv: {len(trip_rows)} rows x {len(trip_rows[0])} cols")
print(f"fleet_staging.csv: {len(fleet_rows)} rows x {len(fleet_rows[0])} cols")
