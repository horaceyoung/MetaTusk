// Copyright © 2020 Metabolist. All rights reserved.

import AVFoundation
import Combine
import Mastodon
import UIKit
import ViewModels

final class CompositionInputAccessoryView: UIToolbar {
    let tagForInputView = UUID().hashValue

    private let viewModel: CompositionViewModel
    private let parentViewModel: NewStatusViewModel
    private let autocompleteQueryPublisher: AnyPublisher<String?, Never>
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: CompositionViewModel,
         parentViewModel: NewStatusViewModel,
         autocompleteQueryPublisher: AnyPublisher<String?, Never>) {
        self.viewModel = viewModel
        self.parentViewModel = parentViewModel
        self.autocompleteQueryPublisher = autocompleteQueryPublisher

        super.init(
            frame: .init(
                origin: .zero,
                size: .init(width: UIScreen.main.bounds.width, height: .minimumButtonDimension)))

        initialSetup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension CompositionInputAccessoryView {
    // swiftlint:disable:next function_body_length
    func initialSetup() {
        autoresizingMask = .flexibleHeight

        heightAnchor.constraint(equalToConstant: .minimumButtonDimension).isActive = true

        var attachmentActions = [
            UIAction(
                title: NSLocalizedString("compose.browse", comment: ""),
                image: UIImage(systemName: "ellipsis")) { [weak self] _ in
                guard let self = self else { return }

                self.parentViewModel.presentDocumentPicker(viewModel: self.viewModel)
            },
            UIAction(
                title: NSLocalizedString("compose.photo-library", comment: ""),
                image: UIImage(systemName: "rectangle.on.rectangle")) { [weak self] _ in
                guard let self = self else { return }

                self.parentViewModel.presentMediaPicker(viewModel: self.viewModel)
            }
        ]

        #if !IS_SHARE_EXTENSION
        attachmentActions.insert(UIAction(
            title: NSLocalizedString("compose.take-photo-or-video", comment: ""),
            image: UIImage(systemName: "camera.fill")) { [weak self] _ in
            guard let self = self else { return }

            self.parentViewModel.presentCamera(viewModel: self.viewModel)
        },
        at: 1)
        #endif

        let attachmentButton = UIBarButtonItem(
            image: UIImage(systemName: "paperclip"),
            menu: UIMenu(children: attachmentActions))

        attachmentButton.accessibilityLabel =
            NSLocalizedString("compose.attachments-button.accessibility-label", comment: "")

        let pollButton = UIBarButtonItem(
            image: UIImage(systemName: "chart.bar.xaxis"),
            primaryAction: UIAction { [weak self] _ in self?.viewModel.displayPoll.toggle() })

        pollButton.accessibilityLabel = NSLocalizedString("compose.poll-button.accessibility-label", comment: "")

        let visibilityButton = UIBarButtonItem(
            image: UIImage(systemName: parentViewModel.visibility.systemImageName),
            menu: visibilityMenu(selectedVisibility: parentViewModel.visibility))

        let contentWarningButton = UIBarButtonItem(
            title: NSLocalizedString("status.content-warning-abbreviation", comment: ""),
            primaryAction: UIAction { [weak self] _ in self?.viewModel.displayContentWarning.toggle() })

        viewModel.$displayContentWarning.sink {
            if $0 {
                contentWarningButton.accessibilityHint =
                    NSLocalizedString("compose.content-warning-button.remove", comment: "")
            } else {
                contentWarningButton.accessibilityHint =
                    NSLocalizedString("compose.content-warning-button.add", comment: "")
            }
        }
        .store(in: &cancellables)

        let emojiButton = UIBarButtonItem(
            image: UIImage(systemName: "face.smiling"),
            primaryAction: UIAction { [weak self] _ in
                guard let self = self else { return }

                self.parentViewModel.presentEmojiPicker(tag: self.tagForInputView)
            })

        emojiButton.accessibilityLabel = NSLocalizedString("compose.emoji-button", comment: "")

        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            primaryAction: UIAction { [weak self] _ in
                guard let self = self else { return }

                self.parentViewModel.insert(after: self.viewModel)
            })

        switch parentViewModel.identityContext.appPreferences.statusWord {
        case .toot:
            addButton.accessibilityLabel =
                NSLocalizedString("compose.add-button-accessibility-label.toot", comment: "")
        case .post:
            addButton.accessibilityLabel =
                NSLocalizedString("compose.add-button-accessibility-label.post", comment: "")
        }

        let charactersLabel = UILabel()

        charactersLabel.font = .preferredFont(forTextStyle: .callout)
        charactersLabel.adjustsFontForContentSizeCategory = true
        charactersLabel.adjustsFontSizeToFitWidth = true

        let charactersBarItem = UIBarButtonItem(customView: charactersLabel)

        items = [
            attachmentButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            pollButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            visibilityButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            contentWarningButton,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            emojiButton,
            UIBarButtonItem.flexibleSpace(),
            charactersBarItem,
            UIBarButtonItem.fixedSpace(.defaultSpacing),
            addButton]

        viewModel.$canAddAttachment
            .sink { attachmentButton.isEnabled = $0 }
            .store(in: &cancellables)

        viewModel.$attachmentViewModels
            .combineLatest(viewModel.$attachmentUpload)
            .sink { pollButton.isEnabled = $0.isEmpty && $1 == nil }
            .store(in: &cancellables)

        viewModel.$remainingCharacters.sink {
            charactersLabel.text = String($0)
            charactersLabel.textColor = $0 < 0 ? .systemRed : .label
            charactersLabel.accessibilityLabel = String.localizedStringWithFormat(
                NSLocalizedString("compose.characters-remaining-accessibility-label-%ld", comment: ""),
                $0)
        }
        .store(in: &cancellables)

        viewModel.$isPostable
            .sink { addButton.isEnabled = $0 }
            .store(in: &cancellables)

        autocompleteQueryPublisher
            .print()
            .sink { _ in /* TODO */ }
            .store(in: &cancellables)

        parentViewModel.$visibility
            .sink { [weak self] in
                visibilityButton.image = UIImage(systemName: $0.systemImageName)
                visibilityButton.menu = self?.visibilityMenu(selectedVisibility: $0)
                visibilityButton.accessibilityLabel = String.localizedStringWithFormat(
                    NSLocalizedString("compose.visibility-button.accessibility-label-%@", comment: ""),
                    $0.title ?? "")
            }
            .store(in: &cancellables)
    }
}

private extension CompositionInputAccessoryView {
    func visibilityMenu(selectedVisibility: Status.Visibility) -> UIMenu {
        UIMenu(children: Status.Visibility.allCasesExceptUnknown.reversed().map { visibility in
            UIAction(
                title: visibility.title ?? "",
                image: UIImage(systemName: visibility.systemImageName),
                discoverabilityTitle: visibility.description,
                state: visibility == selectedVisibility ? .on : .off) { [weak self] _ in
                self?.parentViewModel.visibility = visibility
            }
        })
    }
}
