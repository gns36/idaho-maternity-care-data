"""Women aged 15 to 44 by state and year, the denominator for OB-GYNs per woman.

Census Population Estimates, state files by single year of age and sex (July 1):
2013 to 2019 from Vintage 2020 (the 2010s series), 2020 to 2025 from Vintage 2025
(the 2020s series), so each year comes from the series built around its own census.
Output: Data/census_women15_44_by_state_year.csv
"""
from pathlib import Path
import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "Build" / "raw"
RAW.mkdir(parents=True, exist_ok=True)
CENSUS = {
    "SC-EST2020-ALLDATA6.csv": "https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/state/asrh/SC-EST2020-ALLDATA6.csv",
    "sc-est2025-alldata6.csv": "https://www2.census.gov/programs-surveys/popest/datasets/2020-2025/state/asrh/sc-est2025-alldata6.csv",
}
FIPS = {"01": "AL", "02": "AK", "04": "AZ", "05": "AR", "06": "CA", "08": "CO", "09": "CT", "10": "DE", "11": "DC",
        "12": "FL", "13": "GA", "15": "HI", "16": "ID", "17": "IL", "18": "IN", "19": "IA", "20": "KS", "21": "KY",
        "22": "LA", "23": "ME", "24": "MD", "25": "MA", "26": "MI", "27": "MN", "28": "MS", "29": "MO", "30": "MT",
        "31": "NE", "32": "NV", "33": "NH", "34": "NJ", "35": "NM", "36": "NY", "37": "NC", "38": "ND", "39": "OH",
        "40": "OK", "41": "OR", "42": "PA", "44": "RI", "45": "SC", "46": "SD", "47": "TN", "48": "TX", "49": "UT",
        "50": "VT", "51": "VA", "53": "WA", "54": "WV", "55": "WI", "56": "WY"}

pops = []
for fname, url in CENSUS.items():
    p = RAW / fname
    if not p.exists():
        p.write_bytes(requests.get(url, timeout=300).content)
    c = pd.read_csv(p, dtype={"STATE": str, "SUMLEV": str}, encoding="latin-1")
    # SEX 2 is female and ORIGIN 0 is both Hispanic origins; any other ORIGIN would double-count.
    c = c[(c.SUMLEV == "040") & (c.SEX == 2) & (c.ORIGIN == 0) & c.AGE.between(15, 44)]
    cols = [x for x in c.columns if x.startswith("POPESTIMATE") and len(x) == 15]
    g = c.groupby("STATE")[cols].sum().reset_index().melt(id_vars="STATE", var_name="v", value_name="women15_44")
    g["year"] = g.v.str[-4:].astype(int)
    g["vintage"] = fname[6:10]
    pops.append(g.drop(columns="v"))
pop = pd.concat(pops)
pop = pop[((pop.vintage == "2020") & pop.year.between(2013, 2019)) | ((pop.vintage == "2025") & (pop.year >= 2020))]
pop["state"] = pop.STATE.map(FIPS)
pop = pop.dropna(subset=["state"])[["state", "year", "women15_44"]]
assert pop.groupby("year").size().eq(51).all(), "a state is missing in some year"
pop.sort_values(["year", "state"]).to_csv(ROOT / "Data" / "census_women15_44_by_state_year.csv", index=False)
print("wrote", len(pop), "state-years")
