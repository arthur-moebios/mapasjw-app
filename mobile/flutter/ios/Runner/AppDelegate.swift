import Flutter
import GoogleMaps
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var configuredGoogleMapsAPIKey: String?
  private var pendingMapImportResult: FlutterResult?
  private let maximumMapFileBytes = 20 * 1024 * 1024

  private func activeWindowRootViewController() -> UIViewController? {
    let activeScenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
    let sceneWindows = activeScenes.flatMap(\.windows)
    let activeWindow = sceneWindows.first(where: \.isKeyWindow)
      ?? sceneWindows.first(where: { !$0.isHidden && $0.alpha > 0 })
      ?? window

    return activeWindow?.rootViewController
  }

  private func topMostViewController(from rootViewController: UIViewController) -> UIViewController {
    let nextViewController: UIViewController?
    if let presentedViewController = rootViewController.presentedViewController,
       !presentedViewController.isBeingDismissed
    {
      nextViewController = presentedViewController
    } else if let navigationController = rootViewController as? UINavigationController {
      nextViewController = navigationController.visibleViewController
    } else if let tabBarController = rootViewController as? UITabBarController {
      nextViewController = tabBarController.selectedViewController
    } else {
      nextViewController = nil
    }

    guard let nextViewController, nextViewController !== rootViewController else {
      return rootViewController
    }

    return topMostViewController(from: nextViewController)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let mapsChannel = FlutterMethodChannel(
      name: "br.com.mapasjw.cartas/google_maps",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    mapsChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "configureGoogleMaps",
            let mapsApiKey = call.arguments as? String,
            !mapsApiKey.isEmpty
      else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let self else {
        result(FlutterError(
          code: "maps_unavailable",
          message: "O serviço de mapas não está disponível.",
          details: nil
        ))
        return
      }

      if let configuredKey = self.configuredGoogleMapsAPIKey {
        if configuredKey == mapsApiKey {
          result(true)
        } else {
          result(FlutterError(
            code: "maps_key_conflict",
            message: "A chave de mapas já foi configurada para outra congregação.",
            details: nil
          ))
        }
        return
      }

      guard GMSServices.provideAPIKey(mapsApiKey) else {
        result(FlutterError(
          code: "maps_key_rejected",
          message: "A configuração do Google Maps foi rejeitada.",
          details: nil
        ))
        return
      }

      self.configuredGoogleMapsAPIKey = mapsApiKey
      result(true)
    }

    let shareChannel = FlutterMethodChannel(
      name: "br.com.mapasjw.cartas/share",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    shareChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "shareFile", let self,
            let arguments = call.arguments as? [String: Any],
            let requestedName = arguments["fileName"] as? String,
            let fileData = arguments["bytes"] as? FlutterStandardTypedData
      else {
        result(FlutterMethodNotImplemented)
        return
      }

      let allowedCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
      )
      let fileName = requestedName
        .components(separatedBy: allowedCharacters.inverted)
        .joined(separator: "_")
      let safeFileName = fileName.isEmpty ? "programacao" : fileName
      let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(safeFileName)

      do {
        try fileData.data.write(to: fileURL, options: .atomic)
      } catch {
        result(FlutterError(
          code: "share_file_write_failed",
          message: "Não foi possível preparar o arquivo para compartilhar.",
          details: nil
        ))
        return
      }

      DispatchQueue.main.async {
        guard let rootViewController = self.activeWindowRootViewController() else {
          try? FileManager.default.removeItem(at: fileURL)
          result(FlutterError(
            code: "share_view_unavailable",
            message: "A tela de compartilhamento não está disponível.",
            details: nil
          ))
          return
        }

        let presenter = self.topMostViewController(from: rootViewController)

        let activityController = UIActivityViewController(
          activityItems: [fileURL],
          applicationActivities: nil
        )
        if let popover = activityController.popoverPresentationController {
          popover.sourceView = presenter.view
          popover.sourceRect = CGRect(
            x: presenter.view.bounds.midX,
            y: presenter.view.bounds.midY,
            width: 1,
            height: 1
          )
        }
        activityController.completionWithItemsHandler = { _, _, _, _ in
          try? FileManager.default.removeItem(at: fileURL)
          result(true)
        }
        presenter.present(activityController, animated: true)
      }
    }

    let mapImportChannel = FlutterMethodChannel(
      name: "br.com.mapasjw.cartas/map_import",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    mapImportChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickMapFile", let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard self.pendingMapImportResult == nil else {
        result(FlutterError(
          code: "picker_busy",
          message: "Já existe uma seleção de arquivo aberta.",
          details: nil
        ))
        return
      }

      guard let presenter = self.activeWindowRootViewController() else {
        result(FlutterError(
          code: "picker_unavailable",
          message: "Não foi possível abrir os arquivos.",
          details: nil
        ))
        return
      }

      let types = [
        UTType(filenameExtension: "kml") ?? .xml,
        UTType(filenameExtension: "kmz") ?? .zip,
        .xml,
        .zip,
      ]
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
      picker.delegate = self
      self.pendingMapImportResult = result
      self.topMostViewController(from: presenter).present(picker, animated: true)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingMapImportResult else { return }
    pendingMapImportResult = nil

    guard let fileURL = urls.first else {
      result(nil)
      return
    }

    let hasScopedAccess = fileURL.startAccessingSecurityScopedResource()
    defer {
      if hasScopedAccess {
        fileURL.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let fileData = try Data(contentsOf: fileURL, options: .mappedIfSafe)
      guard !fileData.isEmpty, fileData.count <= maximumMapFileBytes else {
        result(FlutterError(
          code: "map_file_size_invalid",
          message: "O arquivo deve ter até 20 MB e não pode estar vazio.",
          details: nil
        ))
        return
      }

      result([
        "fileName": fileURL.lastPathComponent,
        "bytes": FlutterStandardTypedData(bytes: fileData),
      ])
    } catch {
      result(FlutterError(
        code: "map_file_read_failed",
        message: "Não foi possível ler o arquivo selecionado.",
        details: nil
      ))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let result = pendingMapImportResult else { return }
    pendingMapImportResult = nil
    result(nil)
  }
}
