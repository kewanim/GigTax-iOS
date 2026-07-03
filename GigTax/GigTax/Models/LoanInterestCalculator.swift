import Foundation

/// Standard fully-amortizing fixed-rate loan math (same as any mortgage/auto-loan
/// calculator), used to compute the deductible interest portion of a vehicle loan
/// for a given tax year. IRS Pub 463 allows self-employed drivers to deduct the
/// business-% of this interest even under the standard mileage method — the
/// business-% multiplier is applied elsewhere, this returns the pure dollar figure.
enum LoanInterestCalculator {
    struct PaymentPeriod {
        let date: Date
        let interest: Double
        let principal: Double
    }

    static func amortizationSchedule(
        principal: Double,
        apr: Double,
        termMonths: Int,
        startDate: Date
    ) -> [PaymentPeriod] {
        guard principal > 0, termMonths > 0 else { return [] }

        guard apr > 0 else {
            // 0% APR (common with dealer financing): no interest at all, ever.
            // Must short-circuit before the amortization formula below, which
            // divides by zero at r=0.
            let flatPrincipal = principal / Double(termMonths)
            return (0..<termMonths).map { month in
                PaymentPeriod(
                    date: Calendar.current.date(byAdding: .month, value: month, to: startDate) ?? startDate,
                    interest: 0,
                    principal: flatPrincipal
                )
            }
        }

        let r = apr / 12 / 100
        let n = Double(termMonths)
        let payment = principal * r * pow(1 + r, n) / (pow(1 + r, n) - 1)

        var balance = principal
        var schedule: [PaymentPeriod] = []
        for month in 0..<termMonths {
            // Interest is computed on the balance BEFORE this month's principal
            // is subtracted — reordering this produces a wrong-by-one-month schedule.
            let interest = balance * r
            let principalPortion = payment - interest
            balance -= principalPortion
            schedule.append(PaymentPeriod(
                date: Calendar.current.date(byAdding: .month, value: month, to: startDate) ?? startDate,
                interest: interest,
                principal: principalPortion
            ))
        }
        return schedule
    }

    static func interestPaid(
        principal: Double,
        apr: Double,
        termMonths: Int,
        startDate: Date,
        forYear: Int
    ) -> Double {
        amortizationSchedule(principal: principal, apr: apr, termMonths: termMonths, startDate: startDate)
            .filter { Calendar.current.component(.year, from: $0.date) == forYear }
            .reduce(0) { $0 + $1.interest }
    }
}
