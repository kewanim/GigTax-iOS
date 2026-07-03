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

enum VehicleOwnership: String, CaseIterable, Codable {
    case owned    = "Own Outright"
    case financing = "Financing"
    case leasing  = "Leasing"
}

enum MaintenanceType: String, CaseIterable, Codable {
    case oilChange         = "Oil Change"
    case tireRotation       = "Tire Rotation"
    case tireReplacement    = "Tire Replacement"
    case brakePads          = "Brake Pads"
    case transmissionFluid  = "Transmission Fluid"
    case airFilter          = "Air Filter"
    case other              = "Other"

    var icon: String {
        switch self {
        case .oilChange:        return "drop.fill"
        case .tireRotation:     return "circle.dashed"
        case .tireReplacement:  return "circle.fill"
        case .brakePads:        return "octagon.fill"
        case .transmissionFluid: return "gearshape.fill"
        case .airFilter:        return "wind"
        case .other:             return "wrench.and.screwdriver.fill"
        }
    }

    // Rough US ballpark defaults — the driver edits these to match their own
    // car's owner's manual and their own market; there's no free API for
    // real manufacturer schedules or live regional service pricing.
    var defaultIntervalMiles: Double {
        switch self {
        case .oilChange:         return 5_000
        case .tireRotation:      return 6_000
        case .tireReplacement:   return 50_000
        case .brakePads:         return 45_000
        case .transmissionFluid: return 40_000
        case .airFilter:         return 15_000
        case .other:             return 10_000
        }
    }

    var defaultEstimatedCost: Double {
        switch self {
        case .oilChange:         return 60
        case .tireRotation:      return 30
        case .tireReplacement:   return 700
        case .brakePads:         return 220
        case .transmissionFluid: return 150
        case .airFilter:         return 30
        case .other:             return 100
        }
    }
}
