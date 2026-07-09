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
    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("DECtalk voices found: \(voices.count)")
                    .font(.headline)

                if voices.isEmpty {
                    Text("No DECtalk voices registered yet. If you just installed this app, try relaunching it, or check Settings > Accessibility > Spoken Content > Voices.")
                        .foregroundStyle(.secondary)
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
            .onAppear(perform: refreshVoices)
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
