//
//  ContentView.swift
//  DECtalkVoice
//
//  A minimal test harness: lists whichever DECtalk voices AVFoundation can
//  currently see registered, and lets you actually speak through one via
//  the normal AVSpeechSynthesizer API — the same path VoiceOver and every
//  other app uses, so this is real end-to-end proof, not just registration.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var text = "Hello, this is a test of the DECtalk voice extension."
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoiceID: String?
    @State private var activating = true
    @State private var activationResult: ActivationResult?
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("DECtalk voices found: \(voices.count)")
                    .font(.headline)

                if activating {
                    Text("Activating the extension for the first time — this launches its process so the system can register its voices…")
                        .foregroundStyle(.secondary)
                } else if voices.isEmpty {
                    Text("No DECtalk voices registered yet. If you just installed this app, try relaunching it, or check Settings > Accessibility > Spoken Content > Voices.")
                        .foregroundStyle(.secondary)
                }

                if let r = activationResult {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activation diagnostics").font(.subheadline.bold())
                        Text("Components found: \(r.componentsFound)")
                        Text("Instantiate succeeded: \(r.succeeded ? "yes" : "no")")
                        Text("Attempts: \(r.attempts)")
                        if let e = r.lastError {
                            Text("Last error: \(e)")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.caption)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.secondary.opacity(0.1)))
                }

                Picker("Voice", selection: $selectedVoiceID) {
                    ForEach(voices, id: \.identifier) { voice in
                        Text(voice.name).tag(Optional(voice.identifier))
                    }
                }
                .pickerStyle(.menu)

                TextEditor(text: $text)
                    .frame(height: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))

                Button("Speak") {
                    speak()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedVoiceID == nil)

                Spacer()
            }
            .padding()
            .navigationTitle("DECtalk Voice")
            .task {
                let result = await ExtensionActivator.activate()
                activationResult = result
                activating = false
                refreshVoices()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh", action: refreshVoices)
                }
            }
        }
    }

    private func refreshVoices() {
        voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.identifier.hasPrefix("CamdenBopp.DECtalkVoice.") }
        if selectedVoiceID == nil {
            selectedVoiceID = voices.first?.identifier
        }
    }

    private func speak() {
        guard let selectedVoiceID, let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceID) else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        synthesizer.speak(utterance)
    }
}

#Preview {
    ContentView()
}
