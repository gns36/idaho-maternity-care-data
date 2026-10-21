# Idaho maternity care before and after the 2022 abortion ban

Gabrielle Sorresso, Cornell University, October 2026

This repository holds the data and code behind a short piece on maternity care in Idaho after the state banned abortion in August 2022. All data come from publicly available federal sources and are cleaned using Python files. All analysis is contained in a Stata do-file, `replicate.do`. The full repository can be downloaded as a [ZIP file](https://github.com/gns36/idaho-maternity-care-data/archive/refs/heads/main.zip).

## OB-GYNs per woman of reproductive age

I measure the number of OB-GYNs billing Medicare per 100,000 women aged 15 to 44 in Idaho, in neighboring Washington, where abortion is protected, and in the United States as a whole. Idaho’s abortion ban took effect in August 2022.

![OB-GYNs per 100,000 women aged 15 to 44 in Idaho, Washington and the United States, 2013 to 2024](figures/obgyn_per_woman.png)

Because the period before the ban (2016 to 2021) and the period after it (2022 to 2024) differ in length, I express the change in each as a yearly rate.

| | Change per year, 2016 to 2021 | Change per year, 2022 to 2024 |
|---|---|---|
| Idaho | −3.2% | −4.9% |
| Washington | −3.9% | −4.9% |
| United States | −2.3% | −3.7% |

The number of OB-GYNs per woman in Idaho was falling before the ban and continued to fall after it. Washington followed a similar path over the same years, and the decline was faster after 2022 in both states and in the country as a whole.

## Newborn volume at two Canyon County hospitals

West Valley Medical Center in Caldwell closed its labor and delivery unit on April 1, 2024. St. Luke’s Nampa, about eight road miles away, began delivering babies in December 2017. Hospitals do not publish the number of births, so I use newborn nursery days from their Medicare cost reports, which follow births closely within a hospital over time.

| Newborn nursery days | FY2016 | FY2018 | FY2023 |
|---|---|---|---|
| West Valley Medical Center, Caldwell | 1,058 | 724 | 448 |
| St. Luke’s Nampa | not yet open | 971 | 1,847 |

Newborn nursery days at West Valley fell by 58 percent between fiscal years 2016 and 2023, while those at St. Luke’s Nampa nearly doubled after it opened.

## Replicating the analysis

To reproduce these numbers, download the repository, open Stata (version 16 or later) in the repository folder, and run `do replicate.do`. The do-file reads the files in `Data/`, writes its tables to `Output/`, and saves the figure to `figures/`.

## Data

All files in `Data/` are extracts of public federal data, retrieved on October 20, 2026.

| File | Contents | Source |
|---|---|---|
| [`Data/cms_mupphy_obgyn_rows.csv`](Data/cms_mupphy_obgyn_rows.csv) | One row per OB-GYN (national provider identifier) per year, 2013 to 2024 | Centers for Medicare and Medicaid Services, [Medicare Physician and Other Practitioners, by Provider](https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-physician-other-practitioners-by-provider) |
| [`Data/census_women15_44_by_state_year.csv`](Data/census_women15_44_by_state_year.csv) | Women aged 15 to 44 by state, July 1 estimates, 2013 to 2025 | Census Bureau population estimates by age and sex, [Vintage 2020](https://www2.census.gov/programs-surveys/popest/datasets/2010-2020/state/asrh/SC-EST2020-ALLDATA6.csv) for 2013 to 2019 and [Vintage 2025](https://www2.census.gov/programs-surveys/popest/datasets/2020-2025/state/asrh/sc-est2025-alldata6.csv) for 2020 to 2025 |
| [`Data/hcris_idaho_newborn_days.csv`](Data/hcris_idaho_newborn_days.csv) | Newborn nursery and labor and delivery days from the cost reports of Idaho hospitals with obstetric units, fiscal years 2016 to 2024 | Centers for Medicare and Medicaid Services, [Hospital Cost Reports (HCRIS), form 2552-10](https://www.cms.gov/data-research/statistics-trends-and-reports/cost-reports/hospital-2552-2010-form) |

The scripts in `Build/` rebuild these files from the original sources using Python 3 with pandas and requests. First, `Build/01_download_cms_mupphy.py` downloads the OB-GYN records from the CMS file for each year. Second, `Build/02_build_census.py` downloads the Census files and computes the number of women aged 15 to 44 by state and year. Lastly, `Build/03_extract_hcris.py` reads the annual cost report files (`HOSP10FY2016.ZIP` through `HOSP10FY2024.ZIP`, for example https://downloads.cms.gov/FILES/HCRIS/HOSP10FY2016.ZIP).

## Contact

Gabrielle Sorresso, PhD Candidate, Brooks School of Public Policy, Cornell University ([gabriellesorresso.com](https://gabriellesorresso.com)). The code is released under the MIT License, and the data are public federal data.
