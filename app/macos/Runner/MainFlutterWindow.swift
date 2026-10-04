import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 1000, height: 680)
    let frameName = NSWindow.FrameAutosaveName("TuyuBookingMainWindow")
    if !self.setFrameUsingName(frameName) {
      self.center()
    }
    self.setFrameAutosaveName(frameName)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
