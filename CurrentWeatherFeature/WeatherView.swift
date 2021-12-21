//
//  WeatherView.swift
//  ExploringDependencies
//
//  Created by Srinivasan Rajendran on 2021-12-06.
//

import SwiftUI
import Combine
import WeatherClient
import PathMonitorClient
import LocationClient

public class WeatherViewModel: ObservableObject {
    @Published var weatherResults: [WeatherResponse.ConsolidatedWeather] = []
    @Published var isConnected: Bool = true

    var weatherRequestCancellable: AnyCancellable?
    var pathMonitorCancellable: AnyCancellable?
    var searchLoactionsCancellable: AnyCancellable?
    var locationDelegateCancellable: AnyCancellable?

    @Published var currentLocation: Location?

    private let weatherClient: WeatherClient
    private var pathMonitorClient: PathMonitorClient
    private var locationClient: LocationClient

    public init(pathMonitorClient: PathMonitorClient,
                locationClient: LocationClient,
                weatherClient: WeatherClient) {
        self.weatherClient = weatherClient
        self.locationClient = locationClient
        self.pathMonitorClient = pathMonitorClient

        pathMonitorCancellable = pathMonitorClient.networkPathPublisher
            .map { $0.status == .satisfied }
            .removeDuplicates()
            .sink { [weak self] isConnected in
            guard let self = self else { return }
            self.isConnected = isConnected
            if isConnected {
                self.refreshWeather()
            } else {
                self.weatherResults = []
            }
        }

        locationDelegateCancellable = locationClient.delegate.sink { event in
            switch event {
            case let .didChangeAuthorization(status):
                switch status {
                case .notDetermined:
                    break
                case .restricted:
                    // TODO: show alert
                    break
                case .denied:
                    // TODO: Show alert
                    break
                case .authorizedAlways, .authorizedWhenInUse:
                    self.locationClient.requestLocation()
                @unknown default:
                    break
                }
            case let .didUpdateLocations(locations):
                guard let location = locations.first else { return }
                self.searchLoactionsCancellable = self.weatherClient.searchLocations(location.coordinate)
                    .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { [weak self] locations in
                            self?.currentLocation = locations.first
                            self?.refreshWeather()
                        }
                    )
            case .dudFailWithError(_):
                break
            }
        }

        if locationClient.authorizationStatus() == .authorizedWhenInUse {
            locationClient.requestLocation()
        }
    }

    func locationButtonTapped() {
        let status = locationClient.authorizationStatus()

        switch status {
        case .notDetermined:
            locationClient.requestWhenInUseAuthorizaton()
        case .restricted:
            // TODO: show alert
            break
        case .denied:
            // TODO: Show alert
            break
        case .authorizedAlways, .authorizedWhenInUse:
            locationClient.requestLocation()
        @unknown default:
            break
        }
    }

    private func refreshWeather() {
        guard let location = self.currentLocation else { return }
        weatherResults = []
        weatherRequestCancellable = weatherClient
            .weather(location.woeid)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] response in
                    self?.weatherResults = response.consolidatedWeather
                })
    }
}

public struct WeatherView: View {
    @ObservedObject var viewModel: WeatherViewModel

    public init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ZStack(alignment: .bottomTrailing) {
                    List {
                        ForEach(self.viewModel.weatherResults, id: \.id) { weather in
                            Text("Current temp: \(weather.theTemp, specifier: "%.1f")C")
                        }
                    }
                    .listStyle(.grouped)

                    Button(
                        action: { self.viewModel.locationButtonTapped() }
                    ) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                    }
                    .background(Color.black)
                    .clipShape(Circle())
                    .padding()
                }

                if !self.viewModel.isConnected {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Not Connected to internet")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .padding()
                }
            }
            .navigationTitle(self.viewModel.currentLocation?.title ?? "Weather")
        }
    }
}

public struct WeatherView_Previews: PreviewProvider {
    public static var previews: some View {
        WeatherView(viewModel: WeatherViewModel(pathMonitorClient: .satisified,
                                                locationClient: .authorizedWhenInUse,
                                                weatherClient: .happyPath))
            .previewDisplayName("iPhone 11")
    }
}
