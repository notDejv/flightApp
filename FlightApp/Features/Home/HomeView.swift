import SwiftUI

struct HomeView: View {
    let dependencies: AppDependencies
    let user: User

    @State private var viewModel: HomeViewModel
    @State private var path = NavigationPath()
    @State private var swapTurns = 0.0
    @FocusState private var focusedField: AirportField?

    init(dependencies: AppDependencies, user: User) {
        self.dependencies = dependencies
        self.user = user
        _viewModel = State(initialValue: HomeViewModel(
            airports: dependencies.airports,
            repository: dependencies.recentSearchRepository(for: user)
        ))
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                greetingHeader
                searchSection
                recentSection
            }
            .listStyle(.insetGrouped)
            .skyBackground(drifting: true)
            .scrollDismissesKeyboard(.interactively)
            .animation(.default, value: viewModel.recentSearches)
            .animation(.snappy, value: focusedField)
            .navigationTitle("Search Flights")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SearchCriteria.self) { criteria in
                SearchResultsView(criteria: criteria, flightService: dependencies.flightService)
            }
            .navigationDestination(for: Flight.self) { flight in
                FlightDetailsView(flight: flight)
            }
        }
    }

    // MARK: Header

    private var greetingHeader: some View {
        Section {
            HStack(alignment: .bottom, spacing: 12) {
                // Re-evaluated every minute so the greeting follows the time of day.
                TimelineView(.everyMinute) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Greeting(date: context.date).message(for: user))
                            .font(.title2.bold())
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text("Where are we flying today?")
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                LivelyMascot(flapSpeed: 3, bobAmount: 4)
                    .frame(width: 96)
                    .offset(y: 14)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
        }
    }

    // MARK: Search form

    private var searchSection: some View {
        Section {
            airportRow(.origin, title: "From", placeholder: "Origin (e.g. TIA)", icon: "airplane.departure")
            suggestionRows(for: .origin)

            airportRow(.destination, title: "To", placeholder: "Destination (e.g. FCO)", icon: "airplane.arrival")
            suggestionRows(for: .destination)

            DatePicker("Departure", selection: $viewModel.departureDate, displayedComponents: .date)
            DatePicker(
                "Arrival",
                selection: $viewModel.arrivalDate,
                in: viewModel.departureDate...,
                displayedComponents: .date
            )

            if let message = viewModel.validationMessage {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(action: search) {
                // A hidden twin of the icon on the right keeps the word itself centered.
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                    Image(systemName: "magnifyingglass").hidden()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSearch)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            HStack {
                Text("Where to?")
                Spacer()
                Button {
                    withAnimation(.snappy) { viewModel.swapAirports() }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { swapTurns += 180 }
                } label: {
                    Label("Swap", systemImage: "arrow.up.arrow.down")
                        .labelStyle(.iconOnly)
                        .rotationEffect(.degrees(swapTurns))
                }
                .accessibilityLabel("Swap origin and destination")
            }
        }
    }

    private func airportRow(_ field: AirportField, title: String, placeholder: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: Binding(
                    get: { viewModel.query(for: field) },
                    set: { viewModel.updateQuery($0, for: field) }
                ))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($focusedField, equals: field)
            }
            if viewModel.selection(for: field) != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.snappy, value: viewModel.selection(for: field))
    }

    @ViewBuilder
    private func suggestionRows(for field: AirportField) -> some View {
        if focusedField == field {
            ForEach(viewModel.suggestions(for: field)) { airport in
                Button {
                    viewModel.select(airport, for: field)
                    focusedField = field == .origin && viewModel.destination == nil ? .destination : nil
                } label: {
                    AirportSuggestionRow(airport: airport)
                }
                .tint(.primary)
            }
        }
    }

    // MARK: Recent searches

    private var recentSection: some View {
        Section("Recent searches") {
            if viewModel.recentSearches.isEmpty {
                HStack(spacing: 14) {
                    CloudMascot(mood: .sleepy)
                        .frame(width: 56)
                    Text("No trips yet. Your searches will land here.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(viewModel.recentSearches, id: \.key) { criteria in
                    Button {
                        focusedField = nil
                        withAnimation(.snappy) { viewModel.prefill(with: criteria) }
                    } label: {
                        RecentSearchRow(criteria: criteria)
                    }
                    .tint(.primary)
                }
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func search() {
        focusedField = nil
        if let criteria = viewModel.search() {
            path.append(criteria)
        }
    }
}

private struct AirportSuggestionRow: View {
    let airport: Airport

    var body: some View {
        HStack(spacing: 12) {
            Text(airport.code)
                .font(.subheadline.monospaced().bold())
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(airport.city), \(airport.country)")
                Text(airport.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 36)
    }
}

private struct RecentSearchRow: View {
    let criteria: SearchCriteria

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(criteria.summary)
                    .font(.subheadline.weight(.medium))
                Text("\(criteria.origin.city) to \(criteria.destination.city)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.left")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Fills in the search form")
    }
}

#Preview {
    let dependencies = AppDependencies.preview()
    HomeView(dependencies: dependencies, user: dependencies.session.user!)
        .environment(dependencies.favorites)
        .environment(dependencies.liveActivities)
}
