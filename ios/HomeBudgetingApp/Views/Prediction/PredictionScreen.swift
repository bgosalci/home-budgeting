import SwiftUI

struct PredictionScreen: View {
    @EnvironmentObject private var viewModel: BudgetViewModel
    @State private var descriptionInput: String = ""
    @State private var amountInput: String = ""
    @State private var predictedCategory: String = ""
    @State private var selectedCategory: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Predict Category")) {
                    TextField("Description", text: $descriptionInput)
                        .onChange(of: descriptionInput) { newValue in
                            viewModel.updateDescriptionInput(newValue)
                            predictedCategory = ""
                        }
                    TextField("Amount", text: $amountInput)
                        .signedDecimalKeyboard(text: $amountInput)
                    if !predictedCategory.isEmpty {
                        Text("Prediction: \(predictedCategory)")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                    }
                    Button("Run Prediction") {
                        Task {
                            let amount = Double(amountInput)
                            let category = await viewModel.predictCategory(desc: descriptionInput, amount: amount)
                            await MainActor.run { predictedCategory = category }
                        }
                    }
                    .disabled(descriptionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !viewModel.uiState.descSuggestions.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Suggestions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(viewModel.uiState.descSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    descriptionInput = suggestion
                                    viewModel.clearSuggestions()
                                }) {
                                    Text(suggestion)
                                }
                            }
                        }
                    }
                    Picker("Pin to category", selection: $selectedCategory) {
                        Text("Select category").tag("")
                        ForEach(viewModel.uiState.categories.map { $0.name }, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Button("Pin Mapping") {
                        guard !selectedCategory.isEmpty else { return }
                        viewModel.pinPrediction(desc: descriptionInput, category: selectedCategory)
                    }
                    .disabled(descriptionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategory.isEmpty)
                }

                Section(header: Text("Pinned Descriptions")) {
                    if viewModel.uiState.mapping.exact.isEmpty {
                        Text("No pinned predictions yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.uiState.mapping.exact.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.key)
                                    .font(.headline)
                                Text(entry.value)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("Top Descriptions by Category")) {
                    if viewModel.uiState.descMap.tokens.isEmpty {
                        Text("No description training data yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.uiState.descMap.tokens.keys.sorted(), id: \.self) { category in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category).font(.headline)
                                let values = viewModel.uiState.descMap.tokens[category] ?? [:]
                                ForEach(values.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                                    Text("\(item.key) — \(item.value)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Prediction")
        }
    }
}

struct PredictionScreen_Previews: PreviewProvider {
    static var previews: some View {
        PredictionScreen()
            .environmentObject(BudgetViewModel())
    }
}
