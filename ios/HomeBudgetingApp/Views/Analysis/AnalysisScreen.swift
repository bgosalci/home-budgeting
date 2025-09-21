import SwiftUI

struct AnalysisScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel

    private var analysis: AnalysisUiState { viewModel.uiState.analysis }

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
                ForEach(ChartStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

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

    private var rows: [BudgetSpreadRow] {
        zip(data.labels.indices, data.labels).map { index, label in
            BudgetSpreadRow(label: label, planned: data.planned[index], actual: data.actual[index], plannedPercent: data.plannedPercent[index], actualPercent: data.actualPercent[index])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget vs Actual").font(.title3).bold()
            switch style {
            case .bar:
                barChart
            case .pie:
                pieCharts
            case .line:
                barChart
            }
            totals
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var barChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { row in
                VStack(alignment: .leading) {
                    Text(row.label).font(.headline)
                    HStack(alignment: .bottom, spacing: 8) {
                        BarView(value: row.planned, maxValue: data.planned.max() ?? 1, label: "Planned", color: .blue)
                        BarView(value: row.actual, maxValue: data.actual.max() ?? 1, label: "Actual", color: .green)
                    }
                }
            }
        }
    }

    private var pieCharts: some View {
        HStack(alignment: .top, spacing: 32) {
            PieChart(title: "Planned", values: data.planned, labels: data.labels)
            PieChart(title: "Actual", values: data.actual, labels: data.labels)
        }
    }

    private var totals: some View {
        VStack(alignment: .leading) {
            Text("Totals").font(.headline)
            Text("Planned: \(currency(data.plannedTotal))")
            Text("Actual: \(currency(data.actualTotal))")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.label).font(.title3).bold()
            switch style {
            case .bar:
                barChart
            case .line:
                lineChart
            case .pie:
                barChart
            }
            Text("Total: \(currency(data.total))")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var barChart: some View {
        GeometryReader { geometry in
            let maxValue = data.values.max() ?? 1
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(data.values.enumerated()), id: \.offset) { index, value in
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(height: maxValue == 0 ? 0 : CGFloat(value / maxValue) * (geometry.size.height - 40))
                        Text(data.labels[index]).font(.caption2).rotationEffect(.degrees(-45))
                            .frame(maxHeight: 40)
                    }
                }
            }
        }
        .frame(height: 220)
    }

    private var lineChart: some View {
        GeometryReader { geometry in
            let maxValue = data.values.max() ?? 1
            let minValue = data.values.min() ?? 0
            let range = max(maxValue - minValue, 1)
            Path { path in
                for (index, value) in data.values.enumerated() {
                    let x = geometry.size.width * CGFloat(index) / CGFloat(max(data.values.count - 1, 1))
                    let yRatio = (value - minValue) / range
                    let y = geometry.size.height - CGFloat(yRatio) * geometry.size.height
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.accentColor, lineWidth: 2)
        }
        .frame(height: 220)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

private struct BarView: View {
    let value: Double
    let maxValue: Double
    let label: String
    let color: Color

    var body: some View {
        VStack {
            GeometryReader { geometry in
                let ratio = maxValue == 0 ? 0 : value / maxValue
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.8))
                    .frame(height: CGFloat(ratio) * geometry.size.height)
            }
            .frame(height: 120)
            Text("\(label) \(value, specifier: "%.2f")").font(.caption2)
        }
    }
}

private struct PieChart: View {
    let title: String
    let values: [Double]
    let labels: [String]

    private var total: Double { values.reduce(0, +) }

    var body: some View {
        VStack {
            Text(title).font(.headline)
            GeometryReader { geometry in
                let radius = min(geometry.size.width, geometry.size.height) / 2
                ZStack {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        PieSlice(startAngle: angle(at: index), endAngle: angle(at: index + 1))
                            .fill(color(for: index))
                    }
                }
                .frame(width: radius * 2, height: radius * 2)
            }
            .frame(height: 200)
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                HStack {
                    Circle().fill(color(for: index)).frame(width: 10, height: 10)
                    Text("\(labels[index]): \(percentage(of: value))")
                }
                .font(.caption)
            }
        }
    }

    private func angle(at index: Int) -> Angle {
        guard total > 0 else { return .zero }
        let cumulative = values.prefix(index).reduce(0, +)
        return Angle(degrees: (cumulative / total) * 360)
    }

    private func percentage(of value: Double) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.0f%%", (value / total) * 100)
    }

    private func color(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .yellow, .cyan]
        return colors[index % colors.count]
    }
}

private struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle - .degrees(90), endAngle: endAngle - .degrees(90), clockwise: false)
        path.closeSubpath()
        return path
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

struct AnalysisScreen_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisScreen()
            .environmentObject(BudgetViewModel())
    }
}
