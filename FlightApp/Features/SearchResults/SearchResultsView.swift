import SwiftUI

struct SearchResultsView: View {
    @State private var viewModel: SearchResultsViewModel
    @Environment(FavoritesStore.self) private var favorites

    init(criteria: SearchCriteria, flightService: FlightService) {
        _viewModel = State(initialValue: SearchResultsViewModel(criteria: criteria, flightService: flightService))
    }

    var body: some View {
        content
            .navigationTitle(viewModel.criteria.route)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(viewModel.criteria.route).font(.headline)
                        Text(viewModel.criteria.dateRange).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            MascotLoader(message: "Looking for flights…")
                .background { SkyBackground() }
        case .failed(let message):
            MascotEmptyState(mood: .confused, title: "Search failed", message: message) {
                Button("Try Again") { Task { await viewModel.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
            .background { SkyBackground() }
        case .loaded where viewModel.flights.isEmpty:
            ScrollView {
                MascotEmptyState(
                    mood: .confused,
                    title: "No flights found",
                    message: "Hmm, nothing flies that way on those days. Try different dates or airports."
                )
                .containerRelativeFrame(.vertical)
            }
            .refreshable { await viewModel.refresh() }
            .skyBackground()
        case .loaded:
            resultsList
        }
    }

    private var resultsList: some View {
        List {
            ForEach(viewModel.flightsByDay, id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                    ForEach(group.flights) { flight in
                        NavigationLink(value: flight) {
                            FlightRow(flight: flight) {
                                FavoriteButton(isFavorite: favorites.isFavorite(flight)) {
                                    favorites.toggle(flight)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .skyBackground()
        .refreshable { await viewModel.refresh() }
        .transition(.opacity)
    }
}
