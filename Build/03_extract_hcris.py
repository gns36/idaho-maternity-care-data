"""Approximate annual deliveries at Idaho hospitals from CMS hospital cost reports (HCRIS, form 2552-10).

Cost reports do not count births. They do report newborn nursery inpatient days (Worksheet S-3 Part I,
line 13) and, at some hospitals, labor and delivery days (line 32). Nursery days divided by a typical
newborn stay of about two days gives a rough birth count; we report the raw days and leave the
conversion to the reader, because the stay length varies with the cesarean share.

Inputs: HOSP10FY<year>.ZIP files from https://downloads.cms.gov/FILES/HCRIS/ in RAW_DIR.
Output: Data/hcris_idaho_newborn_days.csv (one row per cost report per hospital).
Run: python3 Build/03_extract_hcris.py <folder with HOSP10FY*.ZIP> <this repository folder>
"""
import sys
import zipfile
from pathlib import Path

import pandas as pd

RAW = Path(sys.argv[1])
ROOT = Path(sys.argv[2])

# CCNs from the CMS Maternal Health - Hospital file (Idaho rows), checked by name.
CCN = {
    "131317": "Benewah Community Hospital (St. Maries)",
    "131310": "St. Luke's Jerome",
    "131328": "Bonner General (Sandpoint)",
    "131318": "Valor Health (Emmett)",
    "130014": "West Valley Medical Center (Caldwell)",
    "130049": "Kootenai Health (Coeur d'Alene)",
    "130002": "St. Luke's Magic Valley (Twin Falls)",
    "130013": "Saint Alphonsus Nampa",
    "130071": "St. Luke's Nampa",
    "131327": "Gritman (Moscow)",
    "131301": "Boundary Community Hospital",
    "131314": "Shoshone Medical Center (Kellogg)",
    "131319": "Minidoka Memorial (Rupert)",
    "131302": "North Canyon (Gooding)",
    "131312": "St. Luke's McCall",
    "131307": "Weiser Memorial",
}
# S-3 Part I line 13 = nursery, line 32 = labor and delivery days; column 8 = total patient days,
# column 2 = beds, column 15 = total discharges.
LINES = {"01300": "nursery", "03200": "ld"}
COLS = {"00200": "beds", "00800": "days", "01500": "discharges"}

rows = []
for z in sorted(RAW.glob("HOSP10FY*.ZIP")):
    year = int(z.stem[-4:])
    with zipfile.ZipFile(z) as zf:
        names = {n.upper(): n for n in zf.namelist()}
        rpt_name = next(v for k, v in names.items() if k.endswith("_RPT.CSV"))
        nmrc_name = next(v for k, v in names.items() if k.endswith("_NMRC.CSV"))
        rpt = pd.read_csv(zf.open(rpt_name), header=None, dtype=str)
        rpt = rpt.iloc[:, [0, 2, 5, 6]]
        rpt.columns = ["rpt_rec_num", "ccn", "fy_bgn", "fy_end"]
        # Every Idaho short-term or critical access hospital (CCN 130001-130099, 131300-131399), so units
        # that closed without news coverage also show up.
        rpt = rpt[rpt["ccn"].str.match(r"^13(00|13)\d\d$", na=False)]
        keep = set(rpt["rpt_rec_num"])
        it = pd.read_csv(zf.open(nmrc_name), header=None, dtype=str, chunksize=2_000_000)
        parts = []
        for ch in it:
            ch.columns = ["rpt_rec_num", "wksht", "line", "col", "val"]
            ch = ch[ch["rpt_rec_num"].isin(keep) & ch["wksht"].eq("S300001")
                    & ch["line"].isin(LINES) & ch["col"].isin(COLS)]
            parts.append(ch)
        n = pd.concat(parts)
    n["var"] = n["line"].map(LINES) + "_" + n["col"].map(COLS)
    n["val"] = pd.to_numeric(n["val"])
    w = n.pivot_table(index="rpt_rec_num", columns="var", values="val", aggfunc="sum").reset_index()
    w = rpt.merge(w, on="rpt_rec_num", how="left")
    w["hcris_file_fy"] = year
    rows.append(w)
    print(year, len(rpt), "reports")

out = pd.concat(rows, ignore_index=True)
out["hospital"] = out["ccn"].map(CCN).fillna("")
out = out.sort_values(["ccn", "fy_end", "rpt_rec_num"])
# A report can appear in two annual files; keep the later file's copy.
out = out.drop_duplicates(["ccn", "fy_bgn", "fy_end"], keep="last")
cols = ["hospital", "ccn", "fy_bgn", "fy_end", "hcris_file_fy"] + [c for c in out.columns if c.startswith(("nursery", "ld"))]
out[cols].to_csv(ROOT / "Data" / "hcris_idaho_newborn_days.csv", index=False)
print(out[cols].to_string(index=False))
