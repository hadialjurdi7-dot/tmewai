/// The model installer for the platform this build targets.
///
/// Native builds get the real downloader; the web build gets a stub that
/// reports "unsupported". Only this file is imported by UI code, so `dart:io`
/// never becomes reachable from the browser build through the search screen.
library;

export 'model_installer_contract.dart';
export 'model_installer_stub.dart'
    if (dart.library.io) 'model_installer_native.dart';
