# GigTax iOS — Project Reference

> Open this file any time you need to remember where things are,
> what stage you're at, or what the app is trying to do.

---

## What Is This App?

A native iOS app for **rideshare and delivery drivers** (Uber, Lyft, DoorDash, UberEats, Instacart).

**The problem it solves:**
Drivers overpay taxes because Uber/Lyft underreport their miles (deadhead miles don't count),
and most drivers don't track actual expenses, so they just use the IRS flat rate ($0.70/mile)
and leave money on the table.

**How it solves it:**
- Auto-tracks ALL miles via GPS (including deadhead miles the platforms miss)
- Calculates real fuel cost using your car's MPG + live gas prices
- Tracks every deductible expense (fuel, cleaning, phone, maintenance)
- At year-end: compares IRS flat rate vs. actual expenses and tells you which saves more money
- Generates an IRS-compliant mileage log so drivers can deduct confidently without fear of audits

---

## The Two Deduction Methods (Core Concept)

| Method | How It Works | Best When |
|--------|-------------|-----------|
| **Standard Mileage Rate** | Business miles × $0.70 (IRS rate) | Lower actual costs, high mileage |
| **Actual Expense Method** | Real fuel + maintenance + phone + depreciation × business % | High actual costs, newer/less efficient car |

The app tracks both all year. Driver picks the better one at tax time.

---

## Tech Stack (What We're Building With)

| What | Technology | Why |
|------|-----------|-----|
| Language | Swift 5.9+ | Native iOS |
| UI | SwiftUI | Apple's modern UI framework |
| Database | SwiftData | Apple's new local database (replaces CoreData) |
| Cloud sync | CloudKit | Free iCloud sync, no backend needed |
| Charts | Swift Charts | Built-in Apple charting |
| Maps / GPS | CoreLocation + MapKit | Trip tracking and route display |
| Motion | CoreMotion | Detect city vs. highway driving |
| Widgets | WidgetKit | Home screen widgets |
| Siri | App Intents | "Log a shift" voice commands |
| Biometrics | LocalAuthentication | Face ID / Touch ID lock |

---

## External APIs (Data We Pull In)

| API | What It Does | Cost | Key Required? |
|-----|-------------|------|---------------|
| **NHTSA vPIC** | Vehicle make/model/year database | Free | No |
| **EPA FuelEconomy.gov** | Real MPG data for any vehicle | Free | No |
| **EIA (Energy Info Admin)** | Weekly gas prices by US region | Free | Yes (free signup) |
| **Uber Partner API** | Pull driver earnings (Phase 2) | Free | Requires Uber approval |
| **Lyft Driver API** | Pull driver earnings (Phase 2) | Free | Requires Lyft approval |

**Phase 1 workaround for Uber/Lyft:** Driver exports a CSV from their driver app and imports it into GigTax. This works reliably and is how most tax apps do it.

---

## App Structure (5 Tabs)

```
GigTax
├── Dashboard      ← Live tax summary, earnings overview, quarterly payments
├── Trips          ← GPS-tracked trips, mileage log, map view
├── Earnings       ← Imported shifts from Uber/Lyft, manual entry, tips
├── Expenses       ← Fuel, maintenance, phone, cleaning, receipts
└── Settings       ← Car profile, tax info, filing status, state, goals
```

---

## Key Features at a Glance

| Feature | What It Does | Sprint |
|---------|-------------|--------|
| **GPS Auto-Tracking** | Records every trip including deadhead miles | S2 |
| **Smart Fuel Calc** | Uses your car's real MPG + local gas price to estimate fuel cost per trip | S2 |
| **CSV Import** | Import earnings directly from Uber/Lyft/DoorDash exports | S3 |
| **Deduction Optimizer** | Compares standard vs. actual method, shows which saves more $ | S7 |
| **Audit Shield** | IRS-compliant mileage log export — protects drivers from audits | S7 |
| **Tax Engine** | Live federal + state + county + SE tax for all 50 states | S5 |
| **Net Hourly Rate** | Shows what you actually earn per hour after ALL expenses | S6 |
| **Platform Comparison** | Which platform is most profitable based on YOUR data | S6 |
| **Tax Savings Jar** | Suggests how much to set aside per paycheck | S6 |
| **Depreciation Tracker** | Vehicle depreciation deduction (actual expense method) | S7 |
| **SEP-IRA Guide** | Explains retirement contributions that reduce taxable income | S7 |
| **What-If Simulator** | "Drive 100 more miles → save $X more in taxes" | S7 |
| **Earnings Patterns** | Your best earning days/times from personal history | S6 |
| **Quarterly Tracker** | Log IRS payment confirmations, track what's been paid | S5 |
| **Widgets** | Today's earnings + YTD tax on home screen | S8 |
| **Live Activity** | Miles + fuel cost in Dynamic Island while driving | S8 |
| **Siri Shortcuts** | "Log a shift", "How much do I owe?" | S8 |
| **Face ID Lock** | Protects earnings data | S8 |

---

## Sprint Roadmap (10 Weeks)

```
Week 1  → S0: Project Setup         [NOT STARTED]
           Xcode, data models, navigation skeleton

Week 2  → S1: Driver Profile        [NOT STARTED]
           Onboarding, car picker, EPA MPG, EIA gas prices

Week 3  → S2: GPS Trip Tracking     [NOT STARTED]
           Auto start/stop, deadhead miles, fuel calc, battery optimization

Week 4  → S3: Earnings Import       [NOT STARTED]
           Uber/Lyft/DoorDash CSV parsers, manual entry, tips

Week 5  → S4: Expense Tracking      [NOT STARTED]
           Fuel auto-log, receipts, recurring expenses

Week 6  → S5: Tax Engine            [NOT STARTED]
           Both deduction methods, all 50 states, unit tests

Week 7  → S6: Dashboard             [NOT STARTED]
           Live tax view, net hourly rate, platform comparison, charts

Week 8  → S7: Optimizer & Audit     [NOT STARTED]
           Deduction Optimizer, Audit Shield, mileage log PDF, Schedule C

Week 9  → S8: iOS Features          [NOT STARTED]
           Widgets, Live Activity, Siri, Face ID

Week 10 → S9: Polish & App Store    [NOT STARTED]
           Accessibility, iPad, icons, screenshots, submission
```

**Update the status above as you complete each sprint.**
Change `[NOT STARTED]` → `[IN PROGRESS]` → `[DONE]`

---

## Current Status

**Stage:** Planning
**Last worked on:** Sprint plan and feature definition
**Next step:** Finalize feature list, then start S0 (Xcode project setup)

**Open questions / decisions still to make:**
- [ ] Free / paid / subscription pricing model
- [ ] Uber Partner API application (do we apply now or after launch?)
- [ ] App name — is "GigTax" final?
- [ ] Color scheme / visual identity
- [ ] Do we want a companion web dashboard (like the existing PWA)?

---

## Files in This Project

**Location:** iCloud Drive → Kewani → Personal Projects → iOS Apps → GigTax

```
GigTax/
├── CLAUDE.md      ← Instructions for Claude (AI assistant context)
├── PROJECT.md     ← This file. Your project reference.
├── board.html     ← Visual project board (open in browser)
```

Full Mac path:
`/Users/kewani/Library/Mobile Documents/com~apple~CloudDocs/Kewani/Personal Projects/iOS Apps/GigTax/`

GitHub: https://github.com/kewanim/GigTax-iOS

---

## Reminders for Yourself

- The board lives at `board.html` — open it in any browser to see sprints and stories
- Click any card on the board to move it to the next status
- Every feature idea goes in the board as a story before it gets built
- Tax logic should always be unit-tested before it touches the UI
- The mileage log must be IRS-compliant format — this is non-negotiable
- Deadhead miles (driving to pickup) are the core insight — never lose sight of that
