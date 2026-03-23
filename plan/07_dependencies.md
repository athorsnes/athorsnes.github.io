# Dependencies

## pubspec.yaml additions

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Tar and zip archive extraction — pure Dart, WASM compatible
  archive: ^3.6.0

  # XML parsing — pure Dart, WASM compatible
  xml: ^6.5.0

  # Multi-file picker for web (uses <input type="file">)
  file_picker: ^8.0.0

  # Web interop for Blob download (replaces dart:html)
  web: ^1.0.0
```

## WASM Compatibility Notes

| Package | WASM safe? | Notes |
|---|---|---|
| `archive` | ✓ | Pure Dart; no FFI |
| `xml` | ✓ | Pure Dart |
| `file_picker` | ✓ | Web target uses `<input>` element |
| `web` | ✓ | This IS the WASM web API package |
| `dart:html` | ✗ | Deprecated; do not use in WASM builds |
| `dart:io` | ✗ | Not available in WASM |
| `dart:isolate` | ⚠ | Limited in WASM; avoid `Isolate.run` for parsing |

## Flutter WASM Build Notes

To build for WASM:
```bash
flutter build web --wasm
```

Requires Flutter SDK with Dart 3.3+ (Dart WASM is stable from Flutter 3.22).
The project `pubspec.yaml` already targets `sdk: ^3.6.0-232.0.dev` which is sufficient.

## File Download (WASM)

In WASM builds, `dart:html` is unavailable. Use `package:web` instead:

```dart
import 'package:web/web.dart' as web;
import 'dart:js_interop';

void downloadFile(String content, String filename) {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'application/xml'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
```

## Drag & Drop (WASM)

Flutter's built-in `DragTarget` handles drag-and-drop gestures. For reading dropped
files from the browser's `DataTransfer` API, `package:web` is used:

```dart
// Access the native drop event's files via js_interop
final dt = (event as web.DragEvent).dataTransfer;
final files = dt?.files;
```

Alternatively, clicking the drop zone triggers `FilePicker.platform.pickFiles(
  allowMultiple: true, withData: true)` which returns `Uint8List` byte data
directly — the simplest approach for WASM.

## archive Package: Reading Tar

```dart
import 'package:archive/archive.dart';

// Outer tar
final archive = TarDecoder().decodeBytes(fileBytes);
for (final file in archive.files) {
  print(file.name); // "metadata.txt", "xmlfiles.tar", etc.
}

// Get specific file
final xmlTar = archive.findFile('xmlfiles.tar');
final innerArchive = TarDecoder().decodeBytes(xmlTar!.content as Uint8List);

// Find a file by name (strip leading ./)
final xmlFile = innerArchive.files.firstWhere(
  (f) => f.name.replaceFirst('./', '') == 'ControllerInfo.xml'
);
final xmlContent = utf8.decode(xmlFile.content as Uint8List);
```
