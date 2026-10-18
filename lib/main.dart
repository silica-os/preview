// Preview, the image and PDF viewer of Silica.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'src/app_info.dart';
import 'src/args.dart';
import 'src/model/document.dart';
import 'src/model/viewer.dart';
import 'src/pdf/poppler.dart';
import 'src/pdf/qpdf.dart';
import 'src/portal.dart';
import 'src/style.dart';
import 'src/ui/app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // About Preview and the standard app menu (silica-ui#99).
  SilicaApp.info = appInfo;
  // The toolbar is unified with the window: Ossido draws only the window buttons.
  SilicaWindow.setFullSizeContent(toolbarHeight).ignore();
  SilicaWindow.setSizeLimits(min: PreviewMetrics.minWindow).ignore();
  // A document app: closing its last window keeps it running (APP-LC); a reopen builds a new
  // window with the Open dialog (`SilicaAppWindow` in the app).
  SilicaApp.quitWhenLastWindowCloses = false;
  ViewerController.forgetOriginals();
  runApp(
    PreviewApp(
      loader: DocumentLoader(
        pdf: const PopplerBackend(),
        // Without qpdf PDFs are still annotated; pages, bookmarks and permissions are not
        // offered.
        writer: QpdfWriter.available ? const QpdfWriter() : null,
      ),
      dialogs: PortalFileDialogs(),
      files: filesFromArgs(args),
    ),
  );
}
