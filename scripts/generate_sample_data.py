"""Regenerate safari_staging.csv, the raw export the Safari pipeline loads.

The original booking export was lost; this is schema-faithful sample data
rebuilt from the staging table's columns (safari_connect.booking_safari_staging)
and the mess the cleaning SQL handles: mixed date formats, phone formats
(+254 / dashes / bare), gender and seat-class variants, 'KSh' fare noise,
-1 seat rows, 0/6/7 rating outliers, and duplicate booking ids.

Deterministic: random.seed(42). Output: 330 rows x 21 columns; after the
pipeline's dedup and negative-seat deletes, ~300 rows reach the production
bookings table (which expects ~280+).
"""

import csv
import random
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
random.seed(42)

ROUTES = [
    ("RT01", "Nairobi", "Thika"), ("RT02", "Nairobi", "Mombasa"),
    ("RT03", "Nairobi", "Nakuru"), ("RT04", "Nairobi", "Kisumu"),
    ("RT05", "Nairobi", "Eldoret"), ("RT06", "Thika", "Nairobi"),
    ("RT07", "Nakuru", "Nairobi"), ("RT08", "Nairobi", "Nyeri"),
]
ROUTE_WEIGHTS = [30, 12, 14, 6, 8, 12, 8, 10]
FARE = {"RT01": 350, "RT02": 2200, "RT03": 700, "RT04": 1800,
        "RT05": 1600, "RT06": 350, "RT07": 700, "RT08": 500}

CITIES = ["Nairobi", "Thika", "Nakuru", "Mombasa", "Kisumu", "Eldoret", "Nyeri", "Machakos", ""]
FIRSTS = ["Amina", "Brian", "Cynthia", "David", "Esther", "Faith", "Gideon", "Halima", "Ian",
          "Joy", "Kevin", "Lucy", "Mercy", "Otieno", "Peter", "Rehema", "Samuel", "Wanjiku"]
LASTS = ["Kamau", "Otieno", "Wafula", "Njeri", "Mutiso", "Chebet", "Achieng", "Kiptoo",
         "Barasa", "Chirchir", "Gitau", "Hassan", "Mwangi", "Odhiambo"]
DRIVERS = ["Joseph Kimani", "Mary Achieng", "Paul Kiptoo", "Grace Wanjiru", "Simon Mutua",
           "Alice Nduta", "Peter Ochieng", "Esther Kagure"]
PLATES = ["KDA 701X", "KDB 252Y", "KDC 933Z", "KDD 414W", "KDE 825V", "KDF 636U"]
VTYPES = ["Matatu", "Bus", "Shuttle"]

import datetime as _dt

start = _dt.date(2025, 4, 1)


def date4(d):
    fmt = random.choice(["dmy", "iso", "dmy2", "mdy"])
    # MM-DD-YYYY is only emitted when day > 12 — the one case the pipeline's
    # disambiguation rule (middle number > 12) can resolve without guessing.
    if fmt == "mdy" and d.day <= 12:
        fmt = "dmy"
    if fmt == "dmy":
        return f"{d.day:02d}/{d.month:02d}/{d.year}"
    if fmt == "iso":
        return f"{d.isoformat()}"
    if fmt == "dmy2":
        return f"{d.day:02d}-{d.month:02d}-{str(d.year)[2:]}"
    return f"{d.month:02d}-{d.day:02d}-{d.year}"


def phone():
    pick = random.random()
    base = f"7{random.randint(10, 99)} {random.randint(100, 999)}-{random.randint(100, 999)}"
    if pick < 0.05:
        return ""
    if pick < 0.35:
        return f"+254 {base}"
    if pick < 0.55:
        return "254" + base.replace(" ", "").replace("-", "")[0:]
    return f"0{random.randint(10, 99)}{random.randint(100, 999)}{random.randint(100, 999)}"


def name_noise(n):
    if random.random() < 0.75:
        return n
    return random.choice([n.upper(), n.lower(), f"  {n.upper()} "])


def fare_noise(amount):
    if random.random() < 0.7:
        return str(amount)
    return random.choice([f"KSh {amount:,}", f"{amount:,}", f"KSh{amount}"])


rows = []
for n in range(1, 331):
    route = random.choices(ROUTES, weights=ROUTE_WEIGHTS)[0]
    code, frm, to = route
    per_seat = FARE[code]
    seats = random.choices([1, 2, 3, 4, 5, 6], weights=[25, 25, 20, 15, 10, 5])[0]
    if random.random() < 0.015:
        seats = -1  # the pipeline deletes these
    day = start + _dt.timedelta(days=random.randint(0, 150))
    status = random.choices(["Completed", "Cancelled", "No Show"], weights=[78, 12, 10])[0]
    rating = random.choices([str(random.randint(1, 5)), "0", "6", "7", ""],
                            weights=[0.86, 0.04, 0.04, 0.04, 0.02])[0]
    rows.append({
        "booking_id": f"SK-{n:04d}",
        "passenger_name": name_noise(f"{random.choice(FIRSTS)} {random.choice(LASTS)}"),
        "passenger_phone": phone(),
        "passenger_gender": random.choice(["M", "MALE", "male", "F", "FEMALE", "f", ""]),
        "passenger_city": random.choice(CITIES),
        "route_code": code,
        "route_from": frm,
        "route_to": to,
        "vehicle_plate": random.choice([PLATES[n % len(PLATES)], PLATES[n % len(PLATES)].lower()]),
        "vehicle_type": random.choice(VTYPES + [random.choice(VTYPES).lower(), random.choice(VTYPES).upper()]),
        "driver_name": name_noise(random.choice(DRIVERS)),
        "driver_rating": f"{random.uniform(3.2, 5.0):.1f}",
        "departure_date": date4(day),
        "departure_time": f"{random.randint(5, 21):02d}:{random.choice(['00', '15', '30', '45'])}",
        "seat_class": random.choice(["ECO", "Economy", "ECONOMY CLASS", "BUS", "Business", "BUSINESS CLASS"]),
        "seats_booked": str(seats),
        "fare_per_seat": fare_noise(per_seat),
        "total_fare": fare_noise(per_seat * max(seats, 1)),
        "payment_method": random.choice(["M-Pesa", "mpesa", "M-PESA", "Cash", "CASH", "Card", ""]),
        "booking_status": random.choice([status, status.upper(), status.lower()]),
        "trip_rating": rating,
    })

for d in random.sample(range(1, 331), 12):  # exact duplicates for ctid dedup
    rows.append(dict(rows[d]))

with (REPO / "safari_staging.csv").open("w", newline="", encoding="utf-8") as fh:
    writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
    writer.writeheader()
    writer.writerows(rows)

print(f"safari_staging.csv: {len(rows)} rows x {len(rows[0])} cols")
