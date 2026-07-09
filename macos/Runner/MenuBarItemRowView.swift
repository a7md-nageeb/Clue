import AppKit

private final class NonInteractiveImageView: NSImageView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class NonInteractiveLabel: NSTextField {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class MenuBarItemRowView: NSView {
  var onActivate: (() -> Void)?

  private let content: String
  private let iconView = NonInteractiveImageView()
  private let titleField = NonInteractiveLabel(labelWithString: "")
  private let copyIconView = NonInteractiveImageView()
  private var trackingArea: NSTrackingArea?
  private var isHovered = false

  init(iconPng: Data?, title: String, content: String) {
    self.content = content
    super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
    wantsLayer = true
    setupViews(iconPng: iconPng, title: title)
    updateAppearance(highlighted: false)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupViews(iconPng: Data?, title: String) {
    if let iconPng, let image = NSImage(data: iconPng) {
      image.isTemplate = true
      iconView.image = image
    }
    iconView.imageScaling = .scaleProportionallyDown
    iconView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(iconView)

    titleField.stringValue = title
    titleField.lineBreakMode = .byTruncatingTail
    titleField.font = NSFont.menuFont(ofSize: NSFont.systemFontSize)
    titleField.isEnabled = false
    titleField.translatesAutoresizingMaskIntoConstraints = false
    addSubview(titleField)

    copyIconView.image = NSImage(
      systemSymbolName: "doc.on.doc",
      accessibilityDescription: "Copy"
    )?.withSymbolConfiguration(
      NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
    )
    copyIconView.imageScaling = .scaleProportionallyDown
    copyIconView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(copyIconView)

    NSLayoutConstraint.activate([
      iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 16),
      iconView.heightAnchor.constraint(equalToConstant: 16),

      titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
      titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
      titleField.trailingAnchor.constraint(lessThanOrEqualTo: copyIconView.leadingAnchor, constant: -8),

      copyIconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      copyIconView.centerYAnchor.constraint(equalTo: centerYAnchor),
      copyIconView.widthAnchor.constraint(equalToConstant: 14),
      copyIconView.heightAnchor.constraint(equalToConstant: 14),
    ])
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()

    if let trackingArea {
      removeTrackingArea(trackingArea)
    }

    trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    if let trackingArea {
      addTrackingArea(trackingArea)
    }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func mouseDown(with event: NSEvent) {
    updateAppearance(highlighted: true)
  }

  override func mouseUp(with event: NSEvent) {
    guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
    activateRow()
  }

  override func mouseEntered(with event: NSEvent) {
    isHovered = true
    updateAppearance(highlighted: true)
  }

  override func mouseExited(with event: NSEvent) {
    isHovered = false
    updateAppearance(highlighted: false)
  }

  override func resetCursorRects() {
    discardCursorRects()
    addCursorRect(bounds, cursor: .pointingHand)
  }

  func updateWidth(_ width: CGFloat) {
    let targetWidth = max(width, 200)
    if abs(frame.width - targetWidth) > 0.5 {
      setFrameSize(NSSize(width: targetWidth, height: 22))
    }
  }

  private func activateRow() {
    copyToClipboard()
    onActivate?()
    enclosingMenuItem?.menu?.cancelTracking()
  }

  private func updateAppearance(highlighted: Bool) {
    if highlighted {
      layer?.backgroundColor = NSColor.controlAccentColor.cgColor
      titleField.textColor = .white
      iconView.contentTintColor = .white
      copyIconView.contentTintColor = NSColor.white.withAlphaComponent(0.85)
    } else {
      layer?.backgroundColor = NSColor.clear.cgColor
      titleField.textColor = .labelColor
      iconView.contentTintColor = .labelColor
      copyIconView.contentTintColor = .tertiaryLabelColor
    }
  }

  private func copyToClipboard() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(content, forType: .string)
  }
}
