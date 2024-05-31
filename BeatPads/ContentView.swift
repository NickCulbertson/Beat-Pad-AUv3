import SwiftUI
import AudioKit
import AVFoundation
import Keyboard
import Controls
import MIDIKit

struct GlobalValues {
    static let presets = ["Kit I", "Kit II", "Kit III"]
    static let sounds = ["Kit1", "Kit1", "Kit1"]
    static let notes = Array(36...51)
    static let names = ["KICK", "SNARE", "CLOSED HI-HAT", "OPEN HI-HAT", "RIM SHOT", "CRASH", "SHAKER I", "SHAKER II", "TOM I", "TOM II", "TOM III", "TOM IV", "PAD I", "PAD II", "PAD III", "PAD IV"]
    static let presetValues: [[Float]] = [
        [0.0, 0.0, 0.0, 0.0, 0.0],
        [1.0, 0.0, 1.0, 0.4, 0.5],
        [2.0, 0.0, 0.8, 0.2, 0.5]
    ]
}

class Conductor: ObservableObject {
    let engine = AudioEngine()
    var instrument = MIDISampler(name: "Instrument 1")
    var reverb: Reverb?
    var loadingSound = false
    
    @Published var currentPreset = 0
    @Published var currentSound = 0
    @Published var playing = Array(repeating: false, count: 16)
    @Published var attackPosition: Float = 0.0 {
        didSet { instrument.samplerUnit.setAttack(value: attackPosition * 8.0) }
    }
    @Published var releasePosition: Float = 0.0 {
        didSet { instrument.samplerUnit.setRelease(value: releasePosition * 8.0) }
    }
    @Published var reverbPosition: Float = 0.0 {
        didSet { reverb?.dryWetMix = reverbPosition }
    }
    @Published var masterPosition: Float = 0.0 {
        didSet { instrument.volume = masterPosition * 20 + 1 }
    }
    
    init() {
        reverb = Reverb(instrument, dryWetMix: 0.0)
        reverb?.loadFactoryPreset(.largeHall)
        engine.output = reverb
    }
    
    func start() {
        selectSound(currentSound)
        do {
            try engine.start()
        } catch {
            Log("AudioKit did not start!")
        }
    }
    
    func stop() {
        engine.stop()
    }
    
    func allNoteOff() {
        for i in 0...127 {
            instrument.stop(noteNumber: MIDINoteNumber(i), channel: 0)
        }
    }
    
    func selectSound(_ sound: Int) {
        guard !loadingSound else { return }
        loadingSound = true
        allNoteOff()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !self.engine.avEngine.isRunning {
                self.start()
            }
            self.currentSound = sound
            do {
                if let fileURL = Bundle.main.url(forResource: "Sounds/\(GlobalValues.sounds[self.currentSound])", withExtension: "aupreset") {
                    try self.instrument.loadInstrument(url: fileURL)
                } else {
                    Log("Could not find file")
                }
            } catch {
                Log("Could not load instrument")
            }
            self.loadingSound = false
        }
    }
    
    func selectPreset(_ preset: Int) {
        guard !loadingSound else { return }
        loadingSound = true
        allNoteOff()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !self.engine.avEngine.isRunning {
                self.start()
            }
            let presetValues = GlobalValues.presetValues[preset]
            self.currentSound = Int(presetValues[0])
            do {
                if let fileURL = Bundle.main.url(forResource: "Sounds/\(GlobalValues.sounds[self.currentSound])", withExtension: "aupreset") {
                    try self.instrument.loadInstrument(url: fileURL)
                } else {
                    Log("Could not find file")
                }
            } catch {
                Log("Could not load instrument")
            }
            self.attackPosition = presetValues[1]
            self.releasePosition = presetValues[2]
            self.reverbPosition = presetValues[3]
            self.masterPosition = presetValues[4]
            self.loadingSound = false
        }
    }
    
    func noteOn(pitch: Pitch, point: CGPoint) {
        guard !loadingSound else { return }
        instrument.play(noteNumber: MIDINoteNumber(pitch.midiNoteNumber + 36), velocity: 127, channel: 0)
    }
    
    func noteOff(pitch: Pitch) {
        instrument.stop(noteNumber: MIDINoteNumber(pitch.midiNoteNumber + 36), channel: 0)
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @StateObject var conductor = Conductor()
    @State var MIDIKeyPressed = [Bool](repeating: false, count: 128)
    
    func reloadAudio() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !conductor.engine.avEngine.isRunning {
                conductor.selectSound(conductor.currentSound)
                try? conductor.engine.start()
            }
        }
    }
    
    func MIDIConnect() {
        do {
            try midiManager.start()
            try midiManager.addInputConnection(
                to: .allOutputs,
                tag: "Listener",
                filter: .owned(),
                receiver: .events { [self] events, _, _ in
                    DispatchQueue.main.async {
                        events.forEach { self.received(midiEvent: $0) }
                    }
                }
            )
        } catch {
            print("Error starting MIDI services or setting up managed MIDI connection:", error.localizedDescription)
        }
    }
    
    private func received(midiEvent: MIDIKit.MIDIEvent) {
        switch midiEvent {
        case .noteOn(let payload):
            guard !conductor.loadingSound else { return }
            conductor.instrument.play(noteNumber: MIDINoteNumber(payload.note.number.uInt8Value), velocity: payload.velocity.midi1Value.uInt8Value, channel: 0)
            NotificationCenter.default.post(name: .MIDIKey, object: nil, userInfo: ["info": payload.note.number.uInt8Value, "bool": true])
        case .noteOff(let payload):
            conductor.instrument.stop(noteNumber: MIDINoteNumber(payload.note.number.uInt8Value), channel: 0)
            NotificationCenter.default.post(name: .MIDIKey, object: nil, userInfo: ["info": payload.note.number.uInt8Value, "bool": false])
        case .cc(let payload):
            print("CC:", payload.controller, payload.value, payload.channel)
        case .programChange(let payload):
            print("Program Change:", payload.program, payload.channel)
        default:
            break
        }
    }
    
    let midiManager = MIDIManager(clientName: "TestAppMIDIManager", model: "TestApp", manufacturer: "MyCompany")
    
    var body: some View {
        ZStack {
            RadialGradient(gradient: Gradient(colors: [.blue.opacity(0.5), .black]), center: .center, startRadius: 2, endRadius: 650).edgesIgnoringSafeArea(.all)
            VStack{
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.2)) // Background color of the rounded rectangle
                    .frame(height: 50)
                    .overlay(
                        HStack {
                            Button(action: {
                                self.conductor.currentPreset = (self.conductor.currentPreset - 1 + GlobalValues.presets.count) % GlobalValues.presets.count
                                conductor.selectPreset(self.conductor.currentPreset)
                            }) {
                                Image(systemName: "arrowtriangle.left.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            Text(GlobalValues.presets[conductor.currentPreset])
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                            Spacer()
                            Button(action: {
                                self.conductor.currentPreset = (self.conductor.currentPreset + 1) % GlobalValues.presets.count
                                conductor.selectPreset(self.conductor.currentPreset)
                            }) {
                                Image(systemName: "arrowtriangle.right.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                        }
                            .padding(.horizontal)
                    ).padding(3)
                HStack {
                    ZStack {
                        Ribbon(position: $conductor.attackPosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                        Text("Attack").allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                    }
                    ZStack {
                        Ribbon(position: $conductor.releasePosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                        Text("Release").allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                    }
                    ZStack {
                        Ribbon(position: $conductor.reverbPosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                        Text("Reverb").allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                    }
                    ZStack {
                        Ribbon(position: $conductor.masterPosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                        Text("Master").allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                    }
                }.frame(height: 40)
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                Keyboard(layout: .guitar(openPitches: [Pitch(12),Pitch(8),Pitch(4),Pitch(0)], fretcount: 3),
                         noteOn: conductor.noteOn, noteOff: conductor.noteOff) {
                    pitch, isActivated in
                    DrumKey(pitch: pitch,
                            isActivated: isActivated,
                            text: GlobalValues.names[pitch.intValue],
                            whiteKeyColor: .blue.opacity(0.4),
                            blackKeyColor: .blue.opacity(0.4),
                            pressedColor: .blue,
                            alignment: .center,
                            isActivatedExternally: MIDIKeyPressed[GlobalValues.notes[pitch.intValue]])
                }.onReceive(NotificationCenter.default.publisher(for: .MIDIKey), perform: { obj in
                    if let userInfo = obj.userInfo, let info = userInfo["info"] as? UInt8, let val = userInfo["bool"] as? Bool {
                        self.MIDIKeyPressed[Int(info)] = val
                    }
                })
            }.padding(10)
        }.onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if !conductor.engine.avEngine.isRunning {
                    conductor.selectSound(conductor.currentSound)
                    try? conductor.engine.start()
                }
            } else if newPhase == .background {
                conductor.engine.stop()
            }
        }
        .onAppear {
            conductor.start()
            MIDIConnect()
        }
        .onDisappear {
            conductor.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { event in
            handleAudioRouteChange(event: event)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { event in
            handleAudioInterruption(event: event)
        }
    }
    
    private func handleAudioRouteChange(event: Notification) {
        if let reason = event.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt {
            if reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue ||
                reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                reloadAudio()
            }
        }
    }
    
    private func handleAudioInterruption(event: Notification) {
        guard let info = event.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .began {
            conductor.engine.stop()
        } else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                reloadAudio()
            }
        }
    }
}

extension AVAudioUnit {
    // https://infinum.com/blog/ausampler-missing-documentation/
    func setAttack(value: Float) {
        let instrument = auAudioUnit.fullState?["Instrument"] as? NSDictionary
        guard let layers = instrument?["Layers"] as? NSArray else { return }
        for layerIndex in 0..<UInt32(layers.count) {
            var value = max(0.001, value)
            AudioUnitSetProperty(
                self.audioUnit,
                4172,
                kAudioUnitScope_LayerItem,
                0x20000000 + (0x100 * layerIndex),
                &value,
                UInt32(MemoryLayout<Float>.size)
            )
        }
    }
    
    func setRelease(value: Float) {
        let instrument = auAudioUnit.fullState?["Instrument"] as? NSDictionary
        guard let layers = instrument?["Layers"] as? NSArray else { return }
        for layerIndex in 0..<UInt32(layers.count) {
            var value = max(0.001, value)
            AudioUnitSetProperty(
                self.audioUnit,
                4175,
                kAudioUnitScope_LayerItem,
                0x20000000 + (0x100 * layerIndex),
                &value,
                UInt32(MemoryLayout<Float>.size)
            )
        }
    }
}

extension NSNotification.Name {
    static let keyNoteOn  = Notification.Name("keyNoteOn")
    static let keyNoteOff = Notification.Name("keyNoteOff")
    static let MIDIKey    = Notification.Name("MIDIKey")
}
