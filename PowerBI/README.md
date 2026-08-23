# 📊 Power BI Dashboard

A 3-page executive report — **Operations · Financial · Patient Risk** — built on top of `hospital_db`, styled with a custom **Clinical Ops — Navy & Acuity** theme designed to feel like a real hospital ops tool rather than a default Power BI template.

<p align="center">
  <video src="working_demo.mp4" controls width="100%">
    Your browser can't play this video inline — <a href="working_demo.mp4">download the demo here</a>.
  </video>
</p>

<p align="center"><sub>▲ Click play for the full working demo — filters, drill-throughs, and cross-page interactions.</sub></p>

---

## 📁 What's in this folder

| File | Description |
|---|---|
| `HospitalIQ_Dashboard.pbix` | The full Power BI report — open in Power BI Desktop. |
| `hospital-ops-dashboard-theme.json` | Custom report theme ("Clinical Ops — Navy & Acuity") — import via *View → Themes → Browse for themes*. |
| `working_demo.mp4` | Screen recording of the dashboard in use. |
| `README.md` | This file. |

Static screenshots of each page also live in [`/pngs`](../pngs) and are embedded below.

---

## 🖥️ Page 1 — Operations Overview

<img src="../pngs/dashboard_01.png" width="100%">

The command-center view: total encounters, total claims cost, patient count, and 30-day readmission rate up top, with encounter volume trended by year and broken down by encounter class.

**What it shows:**
- Encounter volume **peaked in 2014–2015 (~3.89K)**, roughly 2× the 2011 baseline, dipped through 2016–2019, then rebounded sharply to 3.53K in 2021.
- **Ambulatory visits dominate the mix at 44.95%**, nearly double the next-largest category (outpatient, 22.59%) — most patient contact is low-acuity and routine rather than emergency-driven.
- **95.87%** of encounters resolve in under 24 hours; only **4.13%** run longer.

## 💰 Page 2 — Financial Overview

<img src="../pngs/dashboard_02.png" width="100%">

Cost concentration, payer behavior, and the coverage gap, in one view.

**What it shows:**
- **Electrical cardioversion** is the single highest cumulative-cost procedure at **$35.82M**.
- **Ambulatory (35.75% of cost) and outpatient (13.88% of cost) are cost-efficient** relative to their encounter volume (44.95% and 22.59% of encounters) — routine care is comparatively cheap per visit.
- **Urgent care is disproportionately expensive**: only 13.14% of encounters but 23% of total cost — the largest gap between volume share and cost share of any category.
- Two distinct, deliberately-not-conflated metrics: **48.71% zero payer coverage** vs. **31.58% uninsured** (see [`docs/data_quality_findings.md`](../docs/data_quality_findings.md) for why these differ).

## ⚕️ Page 3 — Patient Risk Overview

<img src="../pngs/dashboard_03.png" width="100%">

Clinical-lens view of readmission, mortality, and length of stay.

**What it shows:**
- **Inpatient stays average ~37 hours**, roughly 4× the next-longest category (ambulatory, ~10 hrs) — length of stay is heavily concentrated in inpatient care.
- **Senior patients account for the large majority of risk-related encounters**, far outpacing Adult and Young Adult combined.
- **Clinical readmission rate is 16.9%** among patients with at least one inpatient or emergency encounter (not the full patient population) — within a realistic acute-care benchmark range.
- **Mortality (15.8%)** is cumulative across the full 2011–2022 dataset, not an annual rate, and skews male (56.49% vs. 43.51% female).

---

## 🎨 Theme

`hospital-ops-dashboard-theme.json` defines the full visual language: a navy/steel-blue primary palette (`#1B3A5C`, `#2E75B6`), teal for "good" states, amber for "neutral," and red for "bad," Segoe UI Semibold for titles and callouts, 8px-radius bordered cards, and a white background — chosen to read as clinical and calm rather than a generic BI theme. Import it into any `.pbix` via *View → Themes → Browse for themes*.

## ▶️ Opening the report

1. Install [Power BI Desktop](https://www.microsoft.com/en-us/power-platform/products/power-bi/desktop) (Windows only).
2. Open `HospitalIQ_Dashboard.pbix`.
3. When prompted, point the data source at your local `hospital_db` (see [`../sql/README.md`](../sql/README.md) to build it first) — or just browse the report against its last-refreshed cached data.

---

<p align="center"><sub>Part of the <a href="../README.md">HospitalIQ</a> project.</sub></p>
