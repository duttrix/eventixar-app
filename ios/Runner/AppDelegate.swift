import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "eventixar/whatsapp",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "shareImages",
            let args = call.arguments as? [String: Any],
            let phone = args["phone"] as? String,
            let paths = args["paths"] as? [String],
            !phone.isEmpty,
            !paths.isEmpty
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        self.openWhatsApp(phone: phone, paths: paths, result: result)
      }
    }
  }

  private func openWhatsApp(phone: String, paths: [String], result: @escaping FlutterResult) {
    let images = paths.compactMap { UIImage(contentsOfFile: $0) }
    guard let image = images.first else {
      result(FlutterError(code: "whatsapp", message: "No se pudo leer la imagen del ticket.", details: nil))
      return
    }
    let payload = images.count == 1 ? image : stitch(images)
    UIPasteboard.general.image = payload

    let schemes = ["whatsapp", "whatsapp-business"]
    guard let url = schemes.compactMap({ URL(string: "\($0)://send?phone=\(phone)") }).first(where: {
      UIApplication.shared.canOpenURL($0)
    }) else {
      result(FlutterError(code: "whatsapp", message: "No está instalado WhatsApp.", details: nil))
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      if opened {
        result(nil)
      } else {
        result(FlutterError(code: "whatsapp", message: "No se pudo abrir WhatsApp.", details: nil))
      }
    }
  }

  private func stitch(_ images: [UIImage]) -> UIImage {
    let width = images.map(\.size.width).max() ?? 1
    let gap: CGFloat = 24
    let height = images.reduce(0) { $0 + $1.size.height } + gap * CGFloat(images.count - 1)
    let format = UIGraphicsImageRendererFormat()
    format.scale = images.first?.scale ?? 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
    return renderer.image { _ in
      var y: CGFloat = 0
      for image in images {
        let x = (width - image.size.width) / 2
        image.draw(in: CGRect(x: x, y: y, width: image.size.width, height: image.size.height))
        y += image.size.height + gap
      }
    }
  }
}
