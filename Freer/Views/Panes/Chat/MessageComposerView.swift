import SwiftUI
import FCDomain
import FCUI

/// The composer, and the gate in front of it.
///
/// **What you may do here is decided by ``ChatGate``, not by this view.**
/// The pane used to check one thing — whether we had left the group —
/// and let everything else fail at send time, which meant it was
/// possible to write a message into a team this identity does not belong
/// to and learn about it from a sealing error. Now the verdict arrives
/// already made, and this view only renders it:
///
/// - `.open` — the composer.
/// - `.blocked` — the composer, disabled, with the reason under it. The
///   conversation is real and might work later.
/// - `.notMember` — no composer at all. There is nothing to write and no
///   state in which writing it would help; the transcript stays, because
///   the history is ours.
/// - `.ownerNeedsKey` — the composer disabled, plus the two ways out
///   only an owner has.
///
/// The sealing note is always drawn, whatever the verdict, and in the
/// flavour's own colour — the square's is the one that had to be
/// written, since a padlock the user assumed was there is worse than
/// none at all.
struct MessageComposerView: View {

    let style: ChatModeStyle
    let verdict: ChatGate.Verdict
    @Binding var draft: String

    let recorder: VoiceRecorder
    let attaching: Bool
    let sendingVoice: Bool
    let attachProgress: (sent: Int64, total: Int64)?
    let errorText: String?

    let onSend: () -> Void
    let onAttach: () -> Void
    let onStartRecording: () -> Void
    let onSendVoice: () -> Void
    let onCancelRecording: () -> Void
    let onGenerateKey: () -> Void
    /// A voice call (1:1) or the meeting choices (Room, Team), just left of
    /// the microphone; nil where neither applies.
    var call: ComposerCall? = nil
    /// Changed by the pane to give the text field the keyboard back —
    /// after the mention list, which took it, has closed.
    var focusRequest: Int = 0

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showEmoji = false
    @FocusState private var typing: Bool

    private var enabled: Bool { verdict.canSend }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let err = errorText ?? recorder.failure {
                CopyableComposerError(text: err)
            }

            if let reason = verdict.reason {
                reasonBar(reason)
            }

            if case .ownerNeedsKey = verdict {
                ownerKeyActions
            }

            if verdict.showsComposer {
                if let progress = attachProgress {
                    ProgressView(
                        value: Double(progress.sent),
                        total: Double(max(progress.total, 1))
                    ) {
                        Text("Uploading… the file goes to DISK before the message goes out")
                            .font(.caption2)
                    }
                    .progressViewStyle(.linear)
                }

                if recorder.isActive {
                    recordingBar
                } else {
                    // Send, emoji and attach are pressed mid-typing: a
                    // tap on them leaves the keyboard where it is.
                    textComposer.keepsKeyboard()
                }
            }

            sealingNote
        }
    }

    // MARK: - the gate's own chrome

    private func reasonBar(_ reason: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: verdict.showsComposer ? "exclamationmark.circle" : "person.crop.circle.badge.xmark")
            Text(reason)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// The owner's way out.
    ///
    /// Android offers two — make a key, or ask the members for the one
    /// they hold — and the second is deliberately **not** here yet:
    /// nothing on this client routes an inbound key share, so a button
    /// that sent a request no answer could ever satisfy would be worse
    /// than no button. It arrives with the rest of the key exchange.
    private var ownerKeyActions: some View {
        HStack(spacing: 8) {
            Button("Generate a key", action: onGenerateKey)
                .help("Make a new key for this \(style.noun) and share it with the members. Messages sealed under an older key stay readable to whoever holds that one.")
            Spacer(minLength: 0)
        }
        .font(.caption)
    }

    // MARK: - composer

    private var textComposer: some View {
        HStack(spacing: 8) {
            if sizeClass == .compact {
                // A phone has no width to spare beside the text field:
                // emoji, attach and call go behind one button.
                moreMenu
            } else {
                composerIcons
            }

            Button(action: onStartRecording) {
                Image(systemName: "mic")
            }
            .buttonStyle(.borderless)
            .disabled(!enabled || attaching)
            .help("Record a voice note. A short one rides inside the message; a long one goes to DISK like a shared file.")

            TextField(enabled ? "Message" : "Can't send here", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .fieldInputStyle()
                .disabled(!enabled)
                .focused($typing)
                .onSubmit(onSend)

            Button(action: onSend) {
                // The icon alone: the word took room from the text field.
                Label("Send", systemImage: "paperplane.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!enabled || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onChange(of: focusRequest) { _, _ in
            // Once the sheet has finished going away: focus asked for
            // while it is still on screen is lost with it.
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                typing = true
            }
        }
        .popover(isPresented: $showEmoji, arrowEdge: .bottom) {
            EmojiPicker { emoji in
                draft += emoji
                showEmoji = false
            }
        }
    }

    /// The phone's one button for everything that is not typing.
    private var moreMenu: some View {
        Menu {
            Button {
                showEmoji = true
            } label: {
                Label("Emoji", systemImage: "face.smiling")
            }
            .disabled(!enabled)

            Button(action: onAttach) {
                Label("Share a file", systemImage: "paperclip")
            }
            .disabled(!enabled || attaching)

            if let call {
                if call.choices.count == 1, let only = call.choices.first {
                    Button(action: only.action) {
                        Label(call.title, systemImage: "phone")
                    }
                    .disabled(call.disabled)
                } else {
                    Menu {
                        ForEach(call.choices) { choice in
                            Button(choice.title, action: choice.action)
                        }
                    } label: {
                        Label(call.title, systemImage: "phone")
                    }
                    .disabled(call.disabled)
                }
            }
        } label: {
            if attaching {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "plus.circle")
            }
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text("More"))
    }

    /// The same buttons laid out one by one, where there is room.
    @ViewBuilder
    private var composerIcons: some View {
            Button {
                showEmoji.toggle()
            } label: {
                Image(systemName: "face.smiling")
            }
            .buttonStyle(.borderless)
            .disabled(!enabled)
            .help("Insert an emoji")

            Button(action: onAttach) {
                if attaching {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "paperclip")
                }
            }
            .buttonStyle(.borderless)
            .disabled(!enabled || attaching)
            .help("Share a file — it is encrypted, uploaded to DISK, and the message carries the key")

            if let call {
                if call.choices.count == 1, let only = call.choices.first {
                    Button(action: only.action) { Image(systemName: "phone") }
                        .buttonStyle(.borderless)
                        .opacity(call.dimmed ? 0.4 : 1)
                        .help(call.help)
                        .disabled(call.disabled)
                } else {
                    Menu {
                        ForEach(call.choices) { choice in
                            Button(choice.title, action: choice.action)
                        }
                    } label: {
                        Image(systemName: "phone")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(call.help)
                    .disabled(call.disabled)
                }
            }
    }

    /// What the composer becomes while a note is being recorded.
    ///
    /// The text field goes away on purpose: there is one thing to decide
    /// here — send it or bin it — and leaving a half-typed message next
    /// to a running microphone invites sending the wrong one.
    private var recordingBar: some View {
        HStack(spacing: 10) {
            Button(action: onCancelRecording) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(sendingVoice)
            .help("Discard this recording")

            Circle()
                .fill(recorder.isCapturing ? Color.red : Color.secondary)
                .frame(width: 8, height: 8)

            Text(VoiceNote.formatDuration(recorder.elapsedMs))
                .font(.callout.monospacedDigit())

            ChatTrack(fraction: recorder.level, width: 120, color: .red)
                .animation(.linear(duration: 0.1), value: recorder.level)

            if recorder.atLimit {
                Text("Five minutes is the cap — send it or start again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Voice messages carry your real voice, which can identify you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            Button(action: onSendVoice) {
                if sendingVoice {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Send", systemImage: "paperplane.fill")
                        .labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(sendingVoice || !enabled)
        }
    }

    /// What sealing this conversation gets. Drawn in the flavour's
    /// colour, so the square's is red and impossible to read as the
    /// same reassurance the other three carry.
    private var sealingNote: some View {
        HStack(spacing: 4) {
            Image(systemName: style.sealingIcon)
            Text(style.sealingNote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption2)
        .foregroundStyle(style.isPublic ? AnyShapeStyle(style.tint) : AnyShapeStyle(.tertiary))
    }
}

/// A composer error, copyable — the same rule the rest of the app
/// follows for anything a user might need to paste into a bug report.
private struct CopyableComposerError: View {
    let text: String

    var body: some View {
        CopyableText(text, font: .caption)
            .foregroundStyle(.orange)
    }
}

/// The phone in the composer, described rather than drawn, so that it can
/// be an icon beside the text field or a row in the phone's More menu.
struct ComposerCall {
    struct Choice: Identifiable {
        let id = UUID()
        let title: String
        let action: () -> Void
    }

    /// What the More menu calls it: "Voice call" or "Voice meeting".
    let title: String
    /// One choice is pressed directly; more are offered as a menu.
    let choices: [Choice]
    let help: String
    /// Shown faded but still pressable: see `ChatView.composerCall(for:)`.
    var dimmed = false
    var disabled = false
}
