//
//  ExploringDependenciesApp.swift
//  ExploringDependencies
//
//  Created by Srinivasan Rajendran on 2021-12-06.
//

import SwiftUI
import WeatherClientLive
import PathMonitorClientLive
import CurrentWeatherFeature
import LocationClientLive

@main
struct ExploringDependenciesApp: App {
    var body: some Scene {
        WindowGroup {
            WeatherView(viewModel: .init(pathMonitorClient: .live(queue: .main),
                                         locationClient: .live,
                                         weatherClient: .live))
        }
    }
}
