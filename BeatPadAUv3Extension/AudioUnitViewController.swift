import CoreAudioKit
import AudioKit
import SwiftUI
import Tonic

#if os(iOS)
typealias HostingController = UIHostingController
#elseif os(macOS)
typealias HostingController = NSHostingController

extension NSView {
    func bringSubviewToFront(_ view: NSView) {
        // This function is a no-op for macOS
    }
}
#endif

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    var hostingController: HostingController<BeatPadAUv3View>?
    var parameterObserverToken: AUParameterObserverToken?
    var observer: NSKeyValueObservation?
    var needsConnection = true
    
    var AUParam1: AUParameter?
    var AUParam2: AUParameter?
    var AUParam3: AUParameter?
    var AUParam4: AUParameter?
    var AUParam5: AUParameter?
    var AUParam6: AUParameter?

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let audioUnit = audioUnit else { return }
        setupParameterObservation()
        configureSwiftUIView(audioUnit: audioUnit)
    }

    private func setupParameterObservation() {
        guard needsConnection, let paramTree = audioUnit?.parameterTree else { return }
        AUParam1 = paramTree.value(forKey: "AUParam1") as? AUParameter
        AUParam2 = paramTree.value(forKey: "AUParam2") as? AUParameter
        AUParam3 = paramTree.value(forKey: "AUParam3") as? AUParameter
        AUParam4 = paramTree.value(forKey: "AUParam4") as? AUParameter
        AUParam5 = paramTree.value(forKey: "AUParam5") as? AUParameter
        AUParam6 = paramTree.value(forKey: "AUParam6") as? AUParameter
        
        observer = audioUnit?.observe(\.allParameterValues) { object, change in
                    DispatchQueue.main.async {
                        //Update Presets
                    }
                }
        
        parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] address, value in
            guard let self = self else { return }
            
            if ([self.AUParam1?.address].contains(address)){
                DispatchQueue.main.async {
                    self.hostingController?.rootView.updateSoundValue(value)
                }
            }
            
            if ([self.AUParam2?.address].contains(address)){
                DispatchQueue.main.async {
                    self.hostingController?.rootView.updateAttackValue(value)
                }
            }
            
            if ([self.AUParam3?.address].contains(address)){
                DispatchQueue.main.async {
                    self.hostingController?.rootView.updateReleaseValue(value)
                }
            }
            
            if ([self.AUParam4?.address].contains(address)){
                DispatchQueue.main.async {
                    self.hostingController?.rootView.updateReverbValue(value)
                }
            }
            
            if ([self.AUParam5?.address].contains(address)){
                DispatchQueue.main.async {
                    self.hostingController?.rootView.updateMasterValue(value)
                }
            }
            
            if ([self.AUParam6?.address].contains(address)){
                DispatchQueue.main.async {
                    self.hostingController?.rootView.updatePresetValue(value)
                }
            }
        })
        
        // Indicate the view and the audio unit have a connection.
        needsConnection = false
    }

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try BeatPadAUv3AudioUnit(componentDescription: componentDescription, options: [])
        DispatchQueue.main.async {
            self.setupParameterObservation()
            self.configureSwiftUIView(audioUnit: self.audioUnit!)
        }
        return audioUnit!
    }
    
    func noteOn(pitch: Pitch, point: CGPoint) {
        guard let audioUnit = audioUnit as? BeatPadAUv3AudioUnit else { return }
        audioUnit.receivedMIDINoteOn(noteNumber: MIDINoteNumber(pitch.midiNoteNumber + 36), velocity: 127, channel: 0, offset: 0)
    }

    func noteOff(pitch: Pitch) {
        guard let audioUnit = audioUnit as? BeatPadAUv3AudioUnit else { return }
        audioUnit.receivedMIDINoteOff(noteNumber: MIDINoteNumber(pitch.midiNoteNumber + 36), channel: 0, offset: 0)
    }
    
    private func configureSwiftUIView(audioUnit: AUAudioUnit) {
        let audioParameter = AudioParameter(auParameters: [AUParam1!, AUParam2!, AUParam3!, AUParam4!, AUParam5!, AUParam6!], initialValue: 0.0, noteOn: noteOn(pitch: point:), noteOff: noteOff)
        let contentView = BeatPadAUv3View(audioParameter: audioParameter)
        let hostingController = HostingController(rootView: contentView)

        if let existingHost = self.hostingController {
            existingHost.removeFromParent()
            existingHost.view.removeFromSuperview()
        }
        
        self.addChild(hostingController)
        hostingController.view.frame = self.view.bounds
        self.view.addSubview(hostingController.view)
        self.hostingController = hostingController
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        DispatchQueue.main.async {
            self.AUParam1?.value = self.AUParam1?.value ?? 0.0
            self.AUParam2?.value = self.AUParam2?.value ?? 0.0
            self.AUParam3?.value = self.AUParam3?.value ?? 0.0
            self.AUParam4?.value = self.AUParam4?.value ?? 0.0
            self.AUParam5?.value = self.AUParam5?.value ?? 0.0
            self.AUParam6?.value = self.AUParam6?.value ?? 0.0
        }
    }
}
