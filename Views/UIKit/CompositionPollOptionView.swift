// Copyright © 2021 Metabolist. All rights reserved.

import Combine
import UIKit
import ViewModels

final class CompositionPollOptionView: UIView {
    let textField = UITextField()
    let option: CompositionViewModel.PollOption
    let removeButton = UIButton(type: .close)
    private let viewModel: CompositionViewModel
    private let parentViewModel: NewStatusViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: CompositionViewModel,
         parentViewModel: NewStatusViewModel,
         option: CompositionViewModel.PollOption) {
        self.viewModel = viewModel
        self.parentViewModel = parentViewModel
        self.option = option

        super.init(frame: .zero)

        initialSetup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension CompositionPollOptionView {
    // swiftlint:disable:next function_body_length
    func initialSetup() {
        let stackView = UIStackView()
        let remainingCharactersLabel = UILabel()

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = .defaultSpacing

        stackView.addArrangedSubview(textField)
        textField.borderStyle = .roundedRect
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        let textInputAccessoryView = CompositionInputAccessoryView(
            viewModel: viewModel,
            parentViewModel: parentViewModel,
            autocompleteQueryPublisher: option.$autocompleteQuery.eraseToAnyPublisher())
        textField.inputAccessoryView = textInputAccessoryView
        textField.tag = textInputAccessoryView.tagForInputView
        textField.addAction(
            UIAction { [weak self] _ in
                guard let self = self, let text = self.textField.text  else { return }

                self.option.text = text

                if let textToSelectedRange = self.textField.textToSelectedRange {
                    self.option.textToSelectedRange = textToSelectedRange
                }
            },
            for: .editingChanged)
        textField.text = option.text

        stackView.addArrangedSubview(remainingCharactersLabel)
        remainingCharactersLabel.adjustsFontForContentSizeCategory = true
        remainingCharactersLabel.font = .preferredFont(forTextStyle: .callout)
        remainingCharactersLabel.setContentHuggingPriority(.required, for: .horizontal)

        stackView.addArrangedSubview(removeButton)
        removeButton.showsMenuAsPrimaryAction = true
        removeButton.menu = UIMenu(
            children: [
                UIAction(
                    title: NSLocalizedString("remove", comment: ""),
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }

                    self.viewModel.remove(pollOption: self.option)
                }])
        removeButton.setContentHuggingPriority(.required, for: .horizontal)
        removeButton.setContentHuggingPriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        option.$remainingCharacters
            .sink {
                remainingCharactersLabel.text = String($0)
                remainingCharactersLabel.textColor = $0 < 0 ? .systemRed : .label
            }
            .store(in: &cancellables)
    }
}
