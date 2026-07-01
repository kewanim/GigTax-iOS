import Foundation

enum Platform: String, CaseIterable, Codable {
    case uber       = "Uber"
    case lyft       = "Lyft"
    case doorDash   = "DoorDash"
    case uberEats   = "Uber Eats"
    case instacart  = "Instacart"
    case grubhub    = "Grubhub"
    case amazonFlex = "Amazon Flex"
    case other      = "Other"

    var icon: String {
        switch self {
        case .uber:       return "car.fill"
        case .lyft:       return "car.fill"
        case .doorDash:   return "bag.fill"
        case .uberEats:   return "fork.knife"
        case .instacart:  return "cart.fill"
        case .grubhub:    return "takeoutbag.and.cup.and.straw.fill"
        case .amazonFlex: return "shippingbox.fill"
        case .other:      return "briefcase.fill"
        }
    }
}

enum FilingStatus: String, CaseIterable, Codable {
    case single               = "Single"
    case marriedFilingJointly = "Married Filing Jointly"
    case headOfHousehold      = "Head of Household"

    var standardDeduction: Double {
        switch self {
        case .single:               return 15_000
        case .marriedFilingJointly: return 30_000
        case .headOfHousehold:      return 22_500
        }
    }
}

enum DeductionMethod: String, CaseIterable, Codable {
    case standard = "Standard Mileage"
    case actual   = "Actual Expenses"
}

enum TripType: String, CaseIterable, Codable {
    case business = "Business"
    case personal = "Personal"
    case unknown  = "Unknown"
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case fuel        = "Fuel"
    case carWash     = "Car Wash"
    case maintenance = "Maintenance"
    case phone       = "Phone"
    case insurance   = "Insurance"
    case accessories = "Accessories"
    case other       = "Other"

    var icon: String {
        switch self {
        case .fuel:        return "fuelpump.fill"
        case .carWash:     return "sparkles"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .phone:       return "iphone"
        case .insurance:   return "shield.fill"
        case .accessories: return "bag.fill"
        case .other:       return "ellipsis.circle.fill"
        }
    }
}
