//
//  BeatPadsApp.swift
//  BeatPads
//
//  Created by Nick Culbertson on 5/14/24.
//

import SwiftUI
import AVFoundation
import AudioKit

@main
struct BeatPadsApp: App {
    init() {
#if os(iOS)
        do {
            Settings.bufferLength = .medium
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(Settings.bufferLength.duration)
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            options: [.mixWithOthers, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let err {
            print(err)
        }
#endif
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
