"""Render the README's dashboard-summary image from safari_staging.csv.

Applies the same cleaning rules as the SQL pipeline (dedup by booking_id,
drop negative seats, normalize seat class / status / ratings, strip fare
noise), then draws the CEO questions from Safari-calculations.sql: route
revenue, booking status mix, seat-class revenue share, and the monthly
revenue trend.

Deterministic input (scripts/generate_sample_data.py, seed 42). The output
image is a matplotlib recreation for the README, not a Power BI render —
the real dashboard file is safari_dashboard.pbix.
"""

import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

REPO = Path(__file__).resolve().parents[1]
ACCENT = "#E67E22"
MUTED = "#34495E"

df = pd.read_csv(REPO / "safari_staging.csv", dtype=str)

# --- cleaning, mirroring safari_cleaning.sql ---
df = df.drop_duplicates(subset="booking_id", keep="first")
df["seats_booked"] = pd.to_numeric(df["seats_booked"].str.replace(r"[^0-9-]", "", regex=True), errors="coerce")
df = df[df["seats_booked"] > 0]
df["trip_rating"] = pd.to_numeric(df["trip_rating"], errors="coerce")
df.loc[df["trip_rating"].isin([0, 6, 7]), "trip_rating"] = pd.NA
strip = lambda s: s.str.replace(r"[^0-9.]", "", regex=True).replace("", pd.NA)
df["fare_per_seat"] = pd.to_numeric(strip(df["fare_per_seat"]), errors="coerce")
df["total_fare"] = pd.to_numeric(strip(df["total_fare"]), errors="coerce")
df["route"] = df["route_from"] + "–" + df["route_to"]
df["seat_class"] = df["seat_class"].str.upper().str.strip().map(
    lambda s: "Business" if s in ("BUS", "BUSINESS", "BUSINESS CLASS")
    else ("Economy" if s in ("ECO", "ECONOMY", "ECONOMY CLASS") else pd.NA))
df["booking_status"] = df["booking_status"].str.strip().str.title().replace({"Mpesa": None})
def parse_date(s):
    """Mirror the SQL's date disambiguation: '/' is DD/MM/YYYY; for '-' the
    middle number > 12 means MM-DD-YYYY, otherwise DD-MM-YYYY; 8 chars is DD-MM-YY."""
    s = s.strip()
    m = re.match(r"^(\d{1,2})/(\d{1,2})/(\d{4})$", s)
    if m:
        d, mo, y = m.groups()
        return pd.Timestamp(int(y), int(mo), int(d))
    m = re.match(r"^(\d{1,2})-(\d{1,2})-(\d{4})$", s)
    if m:
        a, b, y = (int(g) for g in m.groups())
        if b > 12:
            return pd.Timestamp(y, a, b)   # MM-DD-YYYY
        return pd.Timestamp(y, b, a)       # DD-MM-YYYY
    m = re.match(r"^(\d{1,2})-(\d{1,2})-(\d{2})$", s)
    if m:
        d, mo, y = (int(g) for g in m.groups())
        return pd.Timestamp(2000 + y, mo, d)
    return pd.Timestamp(s) if s else pd.NaT


df["departure_date"] = df["departure_date"].map(parse_date)

fig, axes = plt.subplots(2, 2, figsize=(14, 8.5))
fig.suptitle("Safari Connect — dashboard summary (recreated from sample staging data)",
             fontsize=14, fontweight="bold", color=MUTED)

route_rev = df.groupby("route")["total_fare"].sum().sort_values().tail(7)
axes[0, 0].barh(route_rev.index, route_rev.values, color=ACCENT)
axes[0, 0].set_title("Revenue by route (KSh)", fontsize=11, color=MUTED)
axes[0, 0].ticklabel_format(style="plain", axis="x")

status_counts = df["booking_status"].value_counts()
axes[0, 1].bar(status_counts.index, status_counts.values, color=[MUTED, "#BDC3C7", "#95A5A6"])
axes[0, 1].set_title("Bookings by status", fontsize=11, color=MUTED)
for i, v in enumerate(status_counts.values):
    axes[0, 1].text(i, v, str(v), ha="center", va="bottom", color=MUTED)

class_rev = df.groupby("seat_class")["total_fare"].sum()
axes[1, 0].pie(class_rev.values, labels=class_rev.index, colors=[ACCENT, MUTED],
               autopct="%1.0f%%", startangle=90, wedgeprops={"width": 0.45})
axes[1, 0].set_title("Revenue share by seat class", fontsize=11, color=MUTED)

monthly = df.set_index("departure_date").resample("ME")["total_fare"].sum()
axes[1, 1].plot(monthly.index, monthly.values, color=ACCENT, marker="o")
axes[1, 1].set_title("Monthly revenue trend (KSh)", fontsize=11, color=MUTED)
axes[1, 1].ticklabel_format(style="plain", axis="y")
axes[1, 1].xaxis.set_major_formatter(matplotlib.dates.DateFormatter("%b %Y"))
axes[1, 1].tick_params(axis="x", rotation=30)

for ax in axes.flat:
    ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout(rect=[0, 0, 1, 0.96])
fig.savefig(REPO / "safari_dashboard_summary.png", dpi=140)
print("saved safari_dashboard_summary.png")

completed = df[df["booking_status"] == "Completed"]
top_route = route_rev.index[-1]
popular = completed["route"].value_counts().idxmax()
per_seat = (completed.groupby("route")["total_fare"].sum()
            / completed.groupby("route")["seats_booked"].sum()).idxmax()
print("cleaned rows:", len(df))
print("top revenue route:", top_route)
print("most popular route (completed bookings):", popular)
print("best revenue-per-seat route:", per_seat)
