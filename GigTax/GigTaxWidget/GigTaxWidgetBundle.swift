import WidgetKit
import SwiftUI

@main
struct GigTaxWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayEarningsWidget()
        TaxOwedWidget()
    }
}
