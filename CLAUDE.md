# GigTax iOS — Native Swift App

GigTax 2.0, a native iOS app for gig economy workers to track income, mileage, expenses, and tax estimates. Built with SwiftUI for the App Store.

Use model claude-sonnet-4-20250514 for all responses.

## Companion Web App
The original GigTax PWA lives at:
- **Local:** `/Users/kewani/Library/Mobile Documents/com~apple~CloudDocs/Kewani/Personal Projects/Tax App Project/`
- **Live:** https://gigtax.netlify.app
- **GitHub:** https://github.com/kewanim/gigatax

Reference the web app for feature parity, tax logic, and Firebase config.

## Tech Stack
- **Language:** Swift 5.9+
- **UI:** SwiftUI
- **Local storage:** SwiftData
- **Cloud sync:** CloudKit (replaces Firebase)
- **Charts:** Swift Charts (replaces Chart.js)
- **Target:** iOS 17+ / iPadOS 17+
- **Distribution:** App Store (Apple Developer Program required)

## Key Features to Port from Web App
- Income + tips logging per shift per platform
- Mileage deduction ($0.70/mile IRS rate)
- Per-shift expenses (gas, maintenance, phone, other)
- Federal tax: progressive brackets, Single/MFJ/HOH filing status
- State income tax: all 50 states + DC + Maryland county tax
- Self-employment tax (15.3% on 92.35% of net)
- Pro-rated recurring deductions by days elapsed in year
- Quarterly estimated tax breakdown (Q1–Q4)
- Income goals (weekly/monthly) with progress
- Dark mode support
- Multi-year data (separate storage per tax year)

## New iOS-Only Features (GigTax 2.0)
- Home screen widget (today's earnings + YTD tax owed)
- Push notifications for quarterly tax due dates
- Siri shortcuts for quick shift logging
- Face ID / Touch ID app lock

## Tax Constants (2025/2026)
- Mileage rate: $0.70/mile
- SE tax rate: 15.3% on 92.35% of net
- Standard deduction: $15,000 (Single), $30,000 (MFJ), $22,500 (HOH)
- Default recurring deductions: $3,210/year
  - Phone line: $85/month
  - Car cleaning: $30/month
  - Maintenance: $40/month
  - Phone purchase: $1,350/year

## Project Location
- **iCloud:** iCloud Drive → Kewani → Personal Projects → iOS Apps → GigTax
- **GitHub:** https://github.com/kewanim/GigTax-iOS

## Developer Info
- Developer: Kewani Mulugeta
- Apple ID: kewanim40@gmail.com
- GitHub: kewanim
