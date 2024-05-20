import CoreAudioKit
import Controls
import SwiftUI
import Keyboard
import Tonic

class AudioParameter: ObservableObject {
    @Published var attackPosition: AUValue
    @Published var releasePosition: AUValue
    @Published var reverbPosition: AUValue
    @Published var masterPosition: AUValue
    @Published var presetPosition: AUValue
    @Published var currentSound = 0
    @Published var currentPreset = 0
    var auParameters: [AUParameter]
    var noteOn: (Pitch, CGPoint) -> Void
    var noteOff: (Pitch) -> Void
    
    init(auParameters: [AUParameter], initialValue: AUValue, noteOn: @escaping (Pitch, CGPoint) -> Void = { _, _ in },
         noteOff: @escaping (Pitch) -> Void = { _ in }) {
        self.auParameters    = auParameters
        self.attackPosition  = initialValue
        self.releasePosition = initialValue
        self.reverbPosition  = initialValue
        self.masterPosition  = initialValue
        self.presetPosition  = initialValue
        self.noteOn          = noteOn
        self.noteOff         = noteOff
    }
    
    func updateSoundValue(_ newValue: AUValue) {
        DispatchQueue.main.async {
            self.currentSound = Int(newValue)
            self.auParameters[0].setValue(newValue, originator: nil)
        }
    }
    
    func updateAttackValue(_ newValue: AUValue) {
        DispatchQueue.main.async {
            self.attackPosition = newValue
            self.auParameters[1].setValue(newValue, originator: nil)
        }
    }
    
    func updateReleaseValue(_ newValue: AUValue) {
        DispatchQueue.main.async {
            self.releasePosition = newValue
            self.auParameters[2].setValue(newValue, originator: nil)
        }
    }
    
    func updateReverbValue(_ newValue: AUValue) {
        DispatchQueue.main.async {
            self.reverbPosition = newValue
            self.auParameters[3].setValue(newValue, originator: nil)
        }
    }
    
    func updateMasterValue(_ newValue: AUValue) {
        DispatchQueue.main.async {
            self.masterPosition = newValue
            self.auParameters[4].setValue(newValue, originator: nil)
        }
    }
    
    func updatePresetValue(_ newValue: AUValue) {
        DispatchQueue.main.async {
            self.presetPosition = newValue
            self.currentPreset = Int(newValue)
            self.auParameters[5].setValue(newValue, originator: nil)
        }
    }
}

struct BeatPadAUv3View: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var audioParameter: AudioParameter
    
    func updateSoundValue(_ value: AUValue) {
        DispatchQueue.main.async {
            self.audioParameter.currentSound = Int(value)
        }
    }
    
    func updateAttackValue(_ value: AUValue) {
        DispatchQueue.main.async {
            self.audioParameter.attackPosition = value
        }
    }
    
    func updateReleaseValue(_ value: AUValue) {
        DispatchQueue.main.async {
            self.audioParameter.releasePosition = value
        }
    }
    
    func updateReverbValue(_ value: AUValue) {
        DispatchQueue.main.async {
            self.audioParameter.reverbPosition = value
        }
    }
    
    func updateMasterValue(_ value: AUValue) {
        DispatchQueue.main.async {
            self.audioParameter.masterPosition = value
        }
    }
    
    func updatePresetValue(_ value: AUValue) {
        DispatchQueue.main.async {
            self.audioParameter.presetPosition = value
            self.audioParameter.currentPreset = Int(value)
        }
    }
    
    func updatePreset(_ value: AUValue) {
        DispatchQueue.main.async {
            self.audioParameter.presetPosition = value
            self.audioParameter.currentPreset = Int(value)
            self.audioParameter.currentSound = Int(GlobalValues.presetValues[self.audioParameter.currentPreset][0])
            self.audioParameter.attackPosition = AUValue(GlobalValues.presetValues[self.audioParameter.currentPreset][1])
            self.audioParameter.releasePosition = AUValue(GlobalValues.presetValues[self.audioParameter.currentPreset][2])
            self.audioParameter.reverbPosition = AUValue(GlobalValues.presetValues[self.audioParameter.currentPreset][3])
            self.audioParameter.masterPosition = AUValue(GlobalValues.presetValues[self.audioParameter.currentPreset][4])
        }
    }
    
    @Environment(\.scenePhase) var scenePhase
    @State var MIDIKeyPressed = [Bool](repeating: false, count: 128)
    
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
                                        self.audioParameter.currentPreset = (self.audioParameter.currentPreset - 1 + GlobalValues.presets.count) % GlobalValues.presets.count
                                        self.audioParameter.presetPosition = AUValue(self.audioParameter.currentPreset)
                                        updatePreset(AUValue(self.audioParameter.currentPreset))
                                    }) {
                                        Image(systemName: "arrowtriangle.left.fill")
                                            .font(.system(size: 20)) // SF Symbol font size
                                            .foregroundColor(.blue)
                                    }

                                    Spacer()
                                    Text(GlobalValues.presets[audioParameter.currentPreset])
                                        .font(.headline) // Font for the preset label
                                        .frame(maxWidth: .infinity) // Ensures the text stays centered
                                        .onChange(of: audioParameter.presetPosition) { oldValue, newValue in
                                                                            audioParameter.updatePresetValue(newValue)
                                                                        }
                                    Spacer()
                                    Button(action: {
                                        self.audioParameter.currentPreset = (self.audioParameter.currentPreset + 1) % GlobalValues.presets.count
                                        self.audioParameter.presetPosition = AUValue(self.audioParameter.currentPreset)
                                        updatePreset(AUValue(self.audioParameter.currentPreset))
                                    }) {
                                        Image(systemName: "arrowtriangle.right.fill")
                                            .font(.system(size: 20)) // SF Symbol font size
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal) // Padding inside the rounded rectangle
                            ).padding(3)
                HStack {
                    ZStack {
                        Ribbon(position: $audioParameter.attackPosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                            .onChange(of: audioParameter.attackPosition) { oldValue, newValue in
                                                                audioParameter.updateAttackValue(newValue)
                                                            }
                        Text("Attack").allowsHitTesting(false)
                    }
                    ZStack {
                        Ribbon(position: $audioParameter.releasePosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                            .onChange(of: audioParameter.releasePosition) { oldValue, newValue in
                                                                audioParameter.updateReleaseValue(newValue)
                                                            }
                        Text("Release").allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                    }
                    ZStack {
                        Ribbon(position: $audioParameter.reverbPosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                            .onChange(of: audioParameter.reverbPosition) { oldValue, newValue in
                                                                audioParameter.updateReverbValue(newValue)
                                                            }
                        Text("Reverb").allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                    }
                    ZStack {
                        Ribbon(position: $audioParameter.masterPosition)
                            .backgroundColor(.blue.opacity(0.2))
                            .foregroundColor(.blue.opacity(0.4))
                            .cornerRadius(10)
                            .onChange(of: audioParameter.masterPosition) { oldValue, newValue in
                                                                audioParameter.updateMasterValue(newValue)
                                                            }
                        Text("Master").allowsHitTesting(/*@START_MENU_TOKEN@*/false/*@END_MENU_TOKEN@*/)
                    }
                }.frame(height: 40)
                    .padding(.leading, 4)
                    .padding(.trailing, 4)
                
                Keyboard(layout: .guitar(openPitches: [Pitch(12),Pitch(8),Pitch(4),Pitch(0)], fretcount: 3),
                         noteOn: audioParameter.noteOn, noteOff: audioParameter.noteOff) {
                    
                    pitch, isActivated in
                    DrumKey(pitch: pitch,
                            isActivated: isActivated,
                            text: GlobalValues.names[pitch.intValue],
                            whiteKeyColor: .blue.opacity(0.4),
                            blackKeyColor: .blue.opacity(0.4),
                            pressedColor: .blue,
                            alignment: .center//,
                            // isActivatedExternally: MIDIKeyPressed[conductor.notes[pitch.intValue]]
                    )
                }
                         .onReceive(NotificationCenter.default.publisher(for: .MIDIKey), perform: { obj in
                    if let userInfo = obj.userInfo, let info = userInfo["info"] as? UInt8, let val = userInfo["bool"] as? Bool {
                        self.MIDIKeyPressed[Int(info)] = val
                    }
                })
            }.padding(10)
        }
    }
}
