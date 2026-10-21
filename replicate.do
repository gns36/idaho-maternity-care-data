*==============================================================================
* replicate.do
* Author: Gabrielle Sorresso, Cornell University (gns36@cornell.edu)
*
* Purpose: Reproduces, from public data, the numbers behind a short piece on
*          Idaho's maternity care after the state's 2022 abortion ban:
*            (1) OB-GYNs per woman of reproductive age in Idaho, Washington
*                and the United States, 2013 to 2024, and how fast that
*                number fell before and after the ban;
*            (2) newborn volume at West Valley Medical Center (Caldwell),
*                which closed its labor and delivery unit in April 2024, and
*                at St. Luke's Nampa, the unit eight miles away that opened
*                in December 2017.
*
* HOW TO RUN
*   Open Stata 16 or later, change the working directory to this folder
*   (the one holding replicate.do), and type:   do replicate.do
*   Everything it needs is in Data/. It writes tables to Output/ and the
*   figure to figures/. It takes under a minute.
*
* WHY MEDICARE BILLING RECORDS FOR OB-GYNS
*   No public file counts every practicing OB-GYN by state and year. The
*   Centers for Medicare and Medicaid Services (CMS) file "Medicare Physician
*   and Other Practitioners, by Provider" lists every clinician who billed
*   Medicare Part B for at least 11 patients in a year, back to 2013. That
*   gives one consistent series that starts well before 2022. Two limits
*   follow from it. First, it misses OB-GYNs who see very few Medicare
*   patients, often those focused on obstetrics, so it is not a headcount.
*   Second, the national total falls every year, partly because Medicare
*   billing patterns change, so the series is for comparing places and
*   periods, not for saying how many OB-GYNs a state has.
*
* WHY PER WOMAN
*   Idaho's count of OB-GYNs barely moved before the ban while its number of
*   women aged 15 to 44 grew quickly, so a raw count hides how thin coverage
*   was becoming. Every rate here is OB-GYNs per 100,000 women aged 15 to 44
*   (Census Bureau population estimates).
*
* WHY YEARLY RATES
*   The two periods compared, 2016 to 2021 (before the ban) and 2021 to 2024
*   (after), are different lengths. A five-year total next to a three-year
*   total would mislead, so both are expressed as the compound change per
*   year. Expressed that way, Idaho's decline was faster after 2021 than
*   before; so was Washington's, where abortion is protected, and so was the
*   national rate. The comparison with Washington is the point.
*
* WHY NEWBORN NURSERY DAYS FOR HOSPITALS
*   Hospitals do not publish births. Their Medicare cost reports (HCRIS) do
*   report newborn nursery days, which track births closely within a hospital
*   over time (a typical newborn stays one to two days). The levels are
*   approximate; the trends within each hospital are what matter here.
*
* CHECKS
*   The file stops with an error if any number it computes no longer matches
*   what the piece states, so a change in the inputs cannot pass silently.
*==============================================================================

version 16
clear all
set more off

* Paths are relative to this folder, so the code runs on any computer.
global root "`c(pwd)'"
global data "$root/Data"
global out  "$root/Output"
global figs "$root/figures"
capture mkdir "$out"
capture mkdir "$figs"

* Stop at once if run from the wrong folder, rather than failing midway.
foreach f in cms_mupphy_obgyn_rows.csv census_women15_44_by_state_year.csv ///
    hcris_idaho_newborn_days.csv {
    capture confirm file "$data/`f'"
    if _rc {
        di as error "Cannot find Data/`f'. Run this file from its own folder."
        exit 601
    }
}

*==============================================================================
* PART 1. OB-GYNs PER WOMAN, BY STATE AND YEAR
*==============================================================================

*------------------------------------------------------------------------------
* 1.1 Count OB-GYNs by state and year. The CMS extract has one row per
*     clinician (national provider identifier, NPI) per year.
*------------------------------------------------------------------------------
import delimited "$data/cms_mupphy_obgyn_rows.csv", clear varnames(1) ///
    stringcols(_all)
destring year, replace
count
di as txt "Rows in the CMS extract (all years): " r(N)

* Organizations (entity code O) are group practices, not physicians; leaving
* them in would add a few non-people to small states.
count if rndrng_prvdr_ent_cd != "I"
di as txt "Organization rows excluded: " r(N)
keep if rndrng_prvdr_ent_cd == "I"

* The extract holds only the OB-GYN provider type. CMS renamed the label in
* 2016, so both spellings are expected and nothing else is allowed.
tab rndrng_prvdr_type
assert inlist(rndrng_prvdr_type, "Obstetrics/Gynecology", ///
    "Obstetrics & Gynecology")

* Keep the 50 states and DC; territories and military addresses have no
* matching Census denominator.
rename rndrng_prvdr_state_abrvtn state
local states AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD ///
    MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT  ///
    VT VA WA WV WI WY
gen byte in51 = 0
foreach s of local states {
    replace in51 = 1 if state == "`s'"
}
count if in51 == 0
di as txt "Rows outside the 50 states and DC, excluded: " r(N)
keep if in51 == 1

* A clinician should appear once a year; a duplicate would count twice.
duplicates report year rndrng_npi
isid year rndrng_npi

gen one = 1
collapse (sum) obgyn = one, by(state year)
label var obgyn "OB-GYNs billing Medicare (11 or more patients)"
tempfile counts
save `counts'

*------------------------------------------------------------------------------
* 1.2 Add women aged 15 to 44 and compute OB-GYNs per 100,000 women.
*------------------------------------------------------------------------------
import delimited "$data/census_women15_44_by_state_year.csv", clear varnames(1)
merge 1:1 state year using `counts'
* Census estimates run to 2025 and CMS to 2024, so only Census rows (the
* 2025 year) may go unmatched; an unmatched CMS row would mean a lost state.
assert _merge != 2
keep if _merge == 3
drop _merge
assert women15_44 > 0 & !missing(women15_44)

gen rate = 100000 * obgyn / women15_44
label var rate "OB-GYNs per 100,000 women aged 15 to 44"

* Rank 1 is the state with the most OB-GYNs per woman.
bysort year: egen rank = rank(rate), field
bysort year: gen nstates = _N
assert nstates == 51
drop nstates

save "$out/obgyn_state_year.dta", replace
export delimited using "$out/obgyn_state_year.csv", replace

*------------------------------------------------------------------------------
* 1.3 Add the United States, pooling counts and women across states (a
*     national rate, not an average of state rates).
*------------------------------------------------------------------------------
preserve
collapse (sum) obgyn women15_44, by(year)
gen rate = 100000 * obgyn / women15_44
gen state = "US"
tempfile us
save `us'
restore
append using `us'
save "$out/obgyn_with_us.dta", replace

*------------------------------------------------------------------------------
* 1.4 Figure: Idaho, Washington and the United States, 2013 to 2024.
*------------------------------------------------------------------------------
preserve
keep if inlist(state, "ID", "WA", "US")
twoway (connected rate year if state == "US", lcolor(gs9) mcolor(gs9) ///
            msymbol(circle) lpattern(dash))                               ///
       (connected rate year if state == "ID", lcolor(navy) mcolor(navy)  ///
            msymbol(circle) lwidth(medthick))                             ///
       (connected rate year if state == "WA", lcolor(maroon)             ///
            mcolor(maroon) msymbol(square)),                              ///
    xline(2022.6, lpattern(shortdash) lcolor(gs6))                        ///
    text(44 2022.5 "Idaho ban, Aug. 2022", place(w) size(small))          ///
    xlabel(2013(1)2024, labsize(small)) ylabel(15(5)45, angle(0))         ///
    xtitle("") ytitle("OB-GYNs per 100,000 women aged 15 to 44")          ///
    legend(order(2 "Idaho (abortion banned 2022)"                         ///
                 3 "Washington (abortion protected)"                      ///
                 1 "United States") rows(1) size(small) position(6))      ///
    note("Source: CMS Medicare Physician and Other Practitioners; Census"  ///
         "population estimates. Counts OB-GYNs billing Medicare for 11 or" ///
         "more patients a year, so the level is below the true headcount.", ///
         size(vsmall))                                                    ///
    graphregion(color(white)) plotregion(color(white))
graph export "$figs/obgyn_per_woman.png", replace width(2000)
restore

*------------------------------------------------------------------------------
* 1.5 Before and after the ban, as compound yearly rates.
*------------------------------------------------------------------------------
keep if inlist(state, "ID", "WA", "US") & inlist(year, 2016, 2021, 2024)
keep state year obgyn women15_44 rate rank
reshape wide obgyn women15_44 rate rank, i(state) j(year)

gen pct_total_2016_2021    = 100 * (rate2021 / rate2016 - 1)
gen pct_per_year_2016_2021 = 100 * ((rate2021 / rate2016)^(1/5) - 1)
gen pct_per_year_2021_2024 = 100 * ((rate2024 / rate2021)^(1/3) - 1)
* Positive speed-up = the decline was faster after 2021 than before.
gen speedup = pct_per_year_2016_2021 - pct_per_year_2021_2024

format rate* pct* speedup %6.1f
list state obgyn2016 obgyn2021 obgyn2024 rate2016 rate2021 rate2024 ///
    rank2021 pct_per_year_2016_2021 pct_per_year_2021_2024 speedup,  ///
    noobs abbreviate(24)
export delimited using "$out/obgyn_before_after.csv", replace

* Stop if the data no longer support the piece: Idaho fell about 3 then 5
* percent a year, Washington about 4 then 6, and Idaho ranked 45th in 2021.
qui su pct_per_year_2016_2021 if state == "ID"
assert round(r(mean)) == -3
qui su pct_per_year_2021_2024 if state == "ID"
assert round(r(mean)) == -5
qui su pct_per_year_2016_2021 if state == "WA"
assert round(r(mean)) == -4
qui su pct_per_year_2021_2024 if state == "WA"
assert round(r(mean)) == -6
qui su rank2021 if state == "ID"
assert r(mean) == 45

*==============================================================================
* PART 2. NEWBORN VOLUME AT TWO CANYON COUNTY HOSPITALS
*==============================================================================
* West Valley Medical Center (Caldwell, CMS certification number 130014)
* closed labor and delivery on April 1, 2024. St. Luke's Nampa (130071),
* about eight road miles away, began delivering in December 2017. If births
* moved from one to the other, West Valley's newborn days should fall as
* St. Luke's Nampa's rise, while the county's births grow.

import delimited "$data/hcris_idaho_newborn_days.csv", clear varnames(1) ///
    stringcols(2)
keep if inlist(ccn, "130014", "130071")
keep hospital ccn fy_bgn fy_end hcris_file_fy nursery_days
rename hcris_file_fy fy
label var fy "Federal fiscal year of the cost report"
label var nursery_days "Newborn nursery inpatient days"
sort ccn fy
list hospital fy fy_bgn fy_end nursery_days, sepby(ccn) noobs abbreviate(16)

* St. Luke's Nampa's first cost report starts December 7, 2017, the month
* the unit opened; it is a partial year.
qui su fy if ccn == "130071"
assert r(min) == 2018

* West Valley: fiscal 2016 to fiscal 2023, its last full year of deliveries.
qui su nursery_days if ccn == "130014" & fy == 2016
local wv16 = r(mean)
qui su nursery_days if ccn == "130014" & fy == 2023
local wv23 = r(mean)
local wv_change = 100 * (`wv23' / `wv16' - 1)
di as txt "West Valley newborn days, FY2016 to FY2023: " `wv16' " to " ///
    `wv23' " (" %3.0f `wv_change' " percent)"
assert `wv16' == 1058 & `wv23' == 448
assert round(`wv_change') == -58

* St. Luke's Nampa: first (partial) year to fiscal 2023.
qui su nursery_days if ccn == "130071" & fy == 2018
local sl18 = r(mean)
qui su nursery_days if ccn == "130071" & fy == 2023
local sl23 = r(mean)
di as txt "St. Luke's Nampa newborn days, FY2018 to FY2023: " `sl18' ///
    " to " `sl23'
assert `sl18' == 971 & `sl23' == 1847

export delimited using "$out/canyon_county_newborn_days.csv", replace

di as result "All numbers match the piece."
