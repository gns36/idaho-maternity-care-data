"""Pull OB-GYN rows from CMS Medicare Physician & Other Practitioners - by Provider, every year.

Uses the data.cms.gov data-api with a server-side filter so only OB-GYN rows come down.
The provider-type label changed between releases ("Obstetrics/Gynecology" in older years,
"Obstetrics & Gynecology" in newer ones), so every year is queried with both spellings.
Dataset UUIDs come from the CMS catalog https://data.cms.gov/data.json.
Output: Data/cms_mupphy_obgyn_rows.csv (one row per NPI-year, selected columns only).
"""
import sys, time, json
from pathlib import Path
import requests
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Data" / "cms_mupphy_obgyn_rows.csv"

# Data year -> data-api dataset UUID (catalog titles "Medicare Physician & Other Practitioners - by Provider : YYYY-...")
# 2024 has two API distributions in the catalog; both return the same row counts (checked 2026-10-20); use the first.
DATASETS = {
    2013: "483a68df-26a9-42a5-a24c-7458e5374f61",
    2014: "100d9e00-03cd-4105-9f58-27f9bf9ab773",
    2015: "fb870c06-27f2-4e15-b556-1731d794bb5b",
    2016: "2691839a-99fb-45a1-9bd9-86905ba975cc",
    2017: "44ea2789-993f-4d55-ac44-ed7f160b58fa",
    2018: "900850df-c9a9-47ce-a9e0-d0ceae5a811f",
    2019: "6a53afe5-1cbc-4b33-9dc8-926ee532dc66",
    2020: "29d799aa-c660-44fe-a51a-72c4b3e661ac",
    2021: "44e0a489-666c-4ea4-a1a2-360b6cdc19db",
    2022: "21555c17-ec1b-4e74-b2c6-925c6cbb3147",
    2023: "8ba584c6-a43a-4b0b-a35a-eb9a59e3a571",
    2024: "8889d81e-2ee7-448f-8713-f071038289b5",
}
SPELLINGS = ["Obstetrics & Gynecology", "Obstetrics/Gynecology"]
KEEP = ["Rndrng_NPI", "Rndrng_Prvdr_Ent_Cd", "Rndrng_Prvdr_Crdntls", "Rndrng_Prvdr_State_Abrvtn",
        "Rndrng_Prvdr_Zip5", "Rndrng_Prvdr_RUCA", "Rndrng_Prvdr_Cntry", "Rndrng_Prvdr_Type",
        "Tot_Benes", "Tot_Srvcs", "Bene_Avg_Age"]
BASE = "https://data.cms.gov/data-api/v1/dataset/{}/data"
PAGE = 5000


def get(url, params):
    for attempt in range(5):
        try:
            r = requests.get(url, params=params, timeout=120)
            r.raise_for_status()
            return r.json()
        except Exception as e:  # transient API errors are common on large pulls
            print("  retry", attempt, e, file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(f"failed {url} {params}")


frames = []
for year, uid in DATASETS.items():
    for sp in SPELLINGS:
        stats = get(BASE.format(uid) + "/stats", {"filter[Rndrng_Prvdr_Type]": sp})
        n = stats["found_rows"]
        if n == 0:
            continue
        rows = []
        for off in range(0, n, PAGE):
            rows += get(BASE.format(uid), {"filter[Rndrng_Prvdr_Type]": sp, "size": PAGE, "offset": off})
        df = pd.DataFrame(rows)
        df = df[[c for c in KEEP if c in df.columns]]
        df.insert(0, "year", year)
        print(year, repr(sp), "api found_rows", n, "downloaded", len(df), "of", stats["total_rows"], "total rows")
        assert len(df) == n, "paging lost rows"
        frames.append(df)

out = pd.concat(frames, ignore_index=True)
out.to_csv(OUT, index=False)
print("wrote", OUT, out.shape)
