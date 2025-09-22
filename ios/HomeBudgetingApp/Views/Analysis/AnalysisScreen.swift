import SwiftUI
import Charts

struct AnalysisScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel

    private var analysis: AnalysisUiState { viewModel.uiState.analysis }
    private var chartStylesForCurrentMode: [ChartStyle] {
        ChartStyle.availableStyles(for: analysis.options.mode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    optionsSection
                    chartSection
                }
                .padding()
            }
            .navigationTitle("Analysis")
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mode").font(.headline)
            Picker("Mode", selection: Binding(
                get: { analysis.options.mode },
                set: { viewModel.updateAnalysisMode($0) }
            )) {
                ForEach(AnalysisMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Chart Style").font(.headline)
            Picker("Chart Style", selection: Binding(
                get: { analysis.options.chartStyle },
                set: { viewModel.updateAnalysisChartStyle($0) }
            )) {
                ForEach(chartStylesForCurrentMode) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .disabled(chartStylesForCurrentMode.count <= 1)

            if analysis.options.mode == .budgetSpread {
                Picker("Month", selection: Binding(
                    get: { analysis.options.selectedMonth ?? "" },
                    set: { viewModel.updateAnalysisMonth($0) }
                )) {
                    ForEach(analysis.availableMonths, id: \.self) { month in
                        Text(month).tag(month)
                    }
                }
                .pickerStyle(.menu)
            }

            if analysis.options.mode == .moneyIn {
                Picker("Year", selection: Binding(
                    get: { analysis.options.selectedYear ?? "" },
                    set: { viewModel.updateAnalysisYear($0) }
                )) {
                    Text("All").tag("")
                    ForEach(analysis.availableYears, id: \.self) { year in
                        Text(year).tag(year)
                    }
                }
                .pickerStyle(.menu)
                Picker("Category", selection: Binding(
                    get: { analysis.options.selectedCategory ?? "" },
                    set: { viewModel.updateAnalysisCategory($0) }
                )) {
                    Text("All").tag("")
                    ForEach(analysis.availableCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }

            if analysis.options.mode == .monthlySpend {
                Picker("Year", selection: Binding(
                    get: { analysis.options.selectedYear ?? "" },
                    set: { viewModel.updateAnalysisYear($0) }
                )) {
                    Text("All").tag("")
                    ForEach(analysis.availableYears, id: \.self) { year in
                        Text(year).tag(year)
                    }
                }
                .pickerStyle(.menu)
                Picker("Group", selection: Binding(
                    get: { analysis.options.selectedGroup ?? "" },
                    set: { viewModel.updateAnalysisGroup($0) }
                )) {
                    Text("All").tag("")
                    ForEach(analysis.availableGroups, id: \.self) { group in
                        Text(group).tag(group)
                    }
                }
                .pickerStyle(.menu)
                Picker("Category", selection: Binding(
                    get: { analysis.options.selectedCategory ?? "" },
                    set: { viewModel.updateAnalysisCategory($0) }
                )) {
                    Text("All").tag("")
                    ForEach(analysis.availableCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        if let result = analysis.result {
            switch result {
            case .budgetSpread(let data):
                BudgetSpreadView(data: data, style: analysis.options.chartStyle)
            case .series(let data):
                SeriesChartView(data: data, style: analysis.options.chartStyle)
            }
        } else {
            Text("No data available for the selected options.")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
    }
}

private struct BudgetSpreadView: View {
    let data: BudgetSpreadData
    let style: ChartStyle

    @State private var selectedSeries: BudgetSpreadSeries = .planned
    @State private var highlightedCategory: String?

    private let sliceColors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow, .cyan]

    private var rows: [BudgetSpreadRow] {
        zip(data.labels.indices, data.labels).map { index, label in
            BudgetSpreadRow(
                label: label,
                planned: data.planned[index],
                actual: data.actual[index],
                plannedPercent: data.plannedPercent[index],
                actualPercent: data.actualPercent[index]
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget vs Actual").font(.title3).bold()
            Group {
                switch style {
                case .comparisonBars, .bar, .line:
                    comparisonBarChart
                case .donut:
                    donutChart
                }
            }
            summary
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .onChange(of: style) { _, newStyle in
            highlightedCategory = nil
            if newStyle != .donut {
                selectedSeries = .planned
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Totals").font(.headline)
            LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 8) {
                BudgetSummaryCard(series: .planned, amountText: currency(data.plannedTotal))
                BudgetSummaryCard(series: .actual, amountText: currency(data.actualTotal))
            }
        }
    }

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 8)]
    }

    private var comparisonBarChart: some View {
        let barRows = rows
        let maxValue = max(data.planned.max() ?? 0, data.actual.max() ?? 0)
        return Chart {
            ForEach(barRows) { row in
                ForEach(BudgetSpreadSeries.allCases) { series in
                    let amount = row.value(for: series)
                    BarMark(
                        x: .value("Amount", amount),
                        y: .value("Category", row.label)
                    )
                    .position(by: .value("Series", series.title))
                    .foregroundStyle(by: .value("Series", series.title))
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading) {
                        if amount > 0 {
                            Text(currency(amount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartForegroundStyleScale([
            BudgetSpreadSeries.planned.title: BudgetSpreadSeries.planned.color,
            BudgetSpreadSeries.actual.title: BudgetSpreadSeries.actual.color
        ])
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisGridLine()
                AxisTick()
                if let amount = value.as(Double.self) {
                    AxisValueLabel {
                        Text(currency(amount))
                            .font(.caption)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXScale(domain: 0...(maxValue == 0 ? 1 : maxValue * 1.1))
        .frame(minHeight: CGFloat(barRows.count) * 44 + 32)
    }

    private var donutChart: some View {
        let slices = donutSlices(for: selectedSeries)
        let totalAmount = slices.reduce(0) { $0 + $1.value }
        return VStack(alignment: .leading, spacing: 12) {
            Picker("Series", selection: $selectedSeries) {
                ForEach(BudgetSpreadSeries.allCases) { series in
                    Text(series.title).tag(series)
                }
            }
            .pickerStyle(.segmented)

            ZStack {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.value),
                        innerRadius: .ratio(highlightedCategory == slice.label ? 0.45 : 0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .opacity(highlightedCategory == nil || highlightedCategory == slice.label ? 1 : 0.35)
                }
                .chartLegend(.hidden)
                .frame(height: 240)

                VStack(spacing: 4) {
                    Text(selectedSeries.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currency(totalAmount))
                        .font(.headline)
                }
            }

            BudgetCategoryLegend(
                slices: slices,
                highlightedCategory: $highlightedCategory,
                currencyFormatter: currency
            )
        }
        .onChange(of: selectedSeries) {
            highlightedCategory = nil
        }
    }

    private func donutSlices(for series: BudgetSpreadSeries) -> [BudgetDonutSlice] {
        let sanitizedValues: [(index: Int, row: BudgetSpreadRow, value: Double)] =
            rows.enumerated().map { index, row in
                let rawValue = row.value(for: series)
                let safeValue = rawValue.isFinite ? max(rawValue, 0) : 0
                return (index: index, row: row, value: safeValue)
            }

        let total = sanitizedValues.reduce(0) { $0 + $1.value }

        return sanitizedValues.map { entry in
            let percentage = total > 0 ? (entry.value / total) * 100 : 0
            return BudgetDonutSlice(
                label: entry.row.label,
                value: entry.value,
                percentage: percentage,
                color: sliceColors[entry.index % sliceColors.count]
            )
        }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

private struct SeriesChartView: View {
    let data: SeriesData
    let style: ChartStyle

    private var points: [SeriesPoint] {
        zip(data.labels, data.values).map { SeriesPoint(label: $0.0, value: $0.1) }
    }

    private var chartHeight: CGFloat { 260 }

    private var yDomain: ClosedRange<Double> {
        let maxValue = points.map { $0.value }.max() ?? 0
        let upper = maxValue == 0 ? 1 : maxValue * 1.12
        return 0...upper
    }

    private var shouldRotateLabels: Bool { points.count > 5 }

    private var averageValue: Double {
        guard !points.isEmpty else { return 0 }
        let total = points.reduce(0) { $0 + $1.value }
        return total / Double(points.count)
    }

    private var highestPoint: SeriesPoint? {
        points.max { $0.value < $1.value }
    }

    private var lowestPoint: SeriesPoint? {
        points.min { $0.value < $1.value }
    }

    private var latestPoint: SeriesPoint? { points.last }

    private var trendChange: Double? {
        guard points.count > 1, let first = points.first, let last = points.last else { return nil }
        return last.value - first.value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.label)
                .font(.title3)
                .bold()

            if points.isEmpty {
                Text("No data available for the selected filters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: chartHeight)
            } else {
                chart
                    .frame(height: chartHeight)
            }

            summary
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private var chart: some View {
        switch style {
        case .line:
            lineChart
        case .bar, .comparisonBars, .donut:
            barChart
        }
    }

    private var barChart: some View {
        let lastId = latestPoint?.id
        return Chart(points) { point in
            BarMark(
                x: .value("Month", point.label),
                y: .value("Amount", point.value)
            )
            .cornerRadius(8)
            .foregroundStyle(Color.accentColor)
            .annotation(position: .top, alignment: .center) {
                if points.count <= 6 || point.id == lastId {
                    Text(currency(point.value))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                if let amount = value.as(Double.self) {
                    AxisValueLabel {
                        Text(shortCurrency(amount))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: points.map { $0.label }) { value in
                AxisGridLine()
                AxisTick()
                if let label = value.as(String.self) {
                    AxisValueLabel {
                        Text(label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(shouldRotateLabels ? -45 : 0), anchor: .topLeading)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.05))
                )
        }
    }

    private var lineChart: some View {
        let lastId = latestPoint?.id
        return Chart(points) { point in
            AreaMark(
                x: .value("Month", point.label),
                y: .value("Amount", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Month", point.label),
                y: .value("Amount", point.value)
            )
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)

            PointMark(
                x: .value("Month", point.label),
                y: .value("Amount", point.value)
            )
            .symbol(.circle)
            .symbolSize(60)
            .foregroundStyle(Color.accentColor)
            .annotation(position: .top, alignment: .center) {
                if point.id == lastId {
                    VStack(spacing: 2) {
                        Text(point.label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(currency(point.value))
                            .font(.caption)
                            .bold()
                    }
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                    )
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                if let amount = value.as(Double.self) {
                    AxisValueLabel {
                        Text(shortCurrency(amount))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: points.map { $0.label }) { value in
                AxisGridLine()
                AxisTick()
                if let label = value.as(String.self) {
                    AxisValueLabel {
                        Text(label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(shouldRotateLabels ? -45 : 0), anchor: .topLeading)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartPlotStyle { plot in
            plot
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.05))
                )
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(.headline)

            LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 8) {
                SeriesSummaryCard(title: "Total", value: currency(data.total))
                SeriesSummaryCard(title: "Monthly Average", value: currency(averageValue))
                if let latest = latestPoint {
                    SeriesSummaryCard(title: latest.label, value: currency(latest.value), subtitle: "Latest Month")
                }
            }

            if let change = trendChange, let first = points.first, let last = latestPoint {
                let valueText = (change >= 0 ? "+" : "-") + currency(abs(change))
                SeriesHighlightRow(
                    iconName: change >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    title: change >= 0 ? "Upward Trend" : "Downward Trend",
                    subtitle: "\(first.label) → \(last.label)",
                    value: valueText,
                    tint: change >= 0 ? .green : .orange
                )
            }

            if let highest = highestPoint {
                SeriesHighlightRow(
                    iconName: "arrow.up.right.circle.fill",
                    title: highest.label,
                    subtitle: "Highest Month",
                    value: currency(highest.value),
                    tint: .blue
                )
            }

            if let lowest = lowestPoint, lowest.id != highestPoint?.id {
                SeriesHighlightRow(
                    iconName: "arrow.down.right.circle.fill",
                    title: lowest.label,
                    subtitle: "Lowest Month",
                    value: currency(lowest.value),
                    tint: .purple
                )
            }
        }
    }

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 8)]
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        formatter.maximumFractionDigits = abs(value) < 1000 ? 2 : 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func shortCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}

private struct SeriesSummaryCard: View {
    let title: String
    let value: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .bold()
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08))
        )
    }
}

private struct SeriesHighlightRow: View {
    let iconName: String
    let title: String
    let subtitle: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                    .bold()
            }

            Spacer()

            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(tint)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(0.18))
        )
    }
}

private struct SeriesPoint: Identifiable {
    let label: String
    let value: Double

    var id: String { label }
}

private struct BudgetSummaryCard: View {
    let series: BudgetSpreadSeries
    let amountText: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(series.color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(series.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(amountText)
                    .font(.subheadline)
                    .bold()
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08))
        )
    }
}

private struct BudgetCategoryLegend: View {
    let slices: [BudgetDonutSlice]
    @Binding var highlightedCategory: String?
    let currencyFormatter: (Double) -> String

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 8)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories").font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(slices) { slice in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            highlightedCategory = highlightedCategory == slice.label ? nil : slice.label
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slice.label)
                                    .font(.caption)
                                    .fontWeight(highlightedCategory == slice.label ? .semibold : .regular)
                                    .multilineTextAlignment(.leading)
                                Text("\(slice.percentage, specifier: "%.0f")% • \(currencyFormatter(slice.value))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(highlightedCategory == slice.label ? slice.color.opacity(0.12) : Color(.secondarySystemBackground))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BudgetDonutSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let percentage: Double
    let color: Color
}

private enum BudgetSpreadSeries: String, CaseIterable, Identifiable {
    case planned
    case actual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned: return "Planned"
        case .actual: return "Actual"
        }
    }

    var color: Color {
        switch self {
        case .planned: return .blue
        case .actual: return .green
        }
    }
}

private struct BudgetSpreadRow: Identifiable {
    let id = UUID()
    let label: String
    let planned: Double
    let actual: Double
    let plannedPercent: Double
    let actualPercent: Double
}

private extension BudgetSpreadRow {
    func value(for series: BudgetSpreadSeries) -> Double {
        switch series {
        case .planned:
            return planned
        case .actual:
            return actual
        }
    }

    func percentage(for series: BudgetSpreadSeries) -> Double {
        switch series {
        case .planned:
            return plannedPercent
        case .actual:
            return actualPercent
        }
    }
}

#if DEBUG
private struct SeriesChartView_Previews: PreviewProvider {
    static var incomeData: SeriesData {
        let labels = ["Jan 2023", "Feb 2023", "Mar 2023", "Apr 2023", "May 2023", "Jun 2023"]
        let values: [Double] = [4200, 4800, 5150, 4700, 5300, 5600]
        return SeriesData(labels: labels, values: values, label: "Total Income", total: values.reduce(0, +))
    }

    static var previews: some View {
        Group {
            SeriesChartView(data: incomeData, style: .line)
                .previewDisplayName("Money In • Line")
            SeriesChartView(data: incomeData, style: .bar)
                .previewDisplayName("Money In • Bar")
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewDevice("iPhone 13 mini")
    }
}

private struct BudgetSpreadView_Previews: PreviewProvider {
    static var sampleData: BudgetSpreadData {
        let labels = ["Housing", "Food", "Utilities", "Leisure", "Savings"]
        let planned = [1200.0, 450.0, 160.0, 220.0, 300.0]
        let actual = [1250.0, 410.0, 150.0, 260.0, 280.0]
        let plannedTotal = planned.reduce(0, +)
        let actualTotal = actual.reduce(0, +)
        let plannedPercent = planned.map { plannedTotal == 0 ? 0 : ($0 / plannedTotal) * 100 }
        let actualPercent = actual.map { actualTotal == 0 ? 0 : ($0 / actualTotal) * 100 }
        return BudgetSpreadData(
            labels: labels,
            planned: planned,
            actual: actual,
            plannedPercent: plannedPercent,
            actualPercent: actualPercent,
            plannedTotal: plannedTotal,
            actualTotal: actualTotal
        )
    }

    static var previews: some View {
        Group {
            BudgetSpreadView(data: sampleData, style: .comparisonBars)
                .previewDisplayName("Comparison Bars")
            BudgetSpreadView(data: sampleData, style: .donut)
                .previewDisplayName("Donut")
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewDevice("iPhone 13 mini")
    }
}
#endif

struct AnalysisScreen_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AnalysisScreen()
                .environmentObject(BudgetViewModel())
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("Analysis • iPhone SE")
            AnalysisScreen()
                .environmentObject(BudgetViewModel())
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("Analysis • iPhone 14 Pro")
        }
    }
}
