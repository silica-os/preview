// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Preview';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuView => 'View';

  @override
  String get menuGo => 'Go';

  @override
  String get menuTools => 'Tools';

  @override
  String get open => 'Open…';

  @override
  String get export => 'Export…';

  @override
  String get copy => 'Copy';

  @override
  String get selectAll => 'Select All';

  @override
  String get find => 'Find…';

  @override
  String get findNext => 'Find Next';

  @override
  String get findPrevious => 'Find Previous';

  @override
  String get hideSidebar => 'Hide Sidebar';

  @override
  String get thumbnails => 'Thumbnails';

  @override
  String get tableOfContents => 'Table of Contents';

  @override
  String get continuousScroll => 'Continuous Scroll';

  @override
  String get singlePage => 'Single Page';

  @override
  String get twoPages => 'Two Pages';

  @override
  String get actualSize => 'Actual Size';

  @override
  String get zoomToFit => 'Zoom to Fit';

  @override
  String get zoomIn => 'Zoom In';

  @override
  String get zoomOut => 'Zoom Out';

  @override
  String get previousPage => 'Previous Page';

  @override
  String get nextPage => 'Next Page';

  @override
  String get firstPage => 'First Page';

  @override
  String get lastPage => 'Last Page';

  @override
  String get previousImage => 'Previous Image';

  @override
  String get nextImage => 'Next Image';

  @override
  String get goToPage => 'Go to Page…';

  @override
  String get rotateLeft => 'Rotate Left';

  @override
  String get rotateRight => 'Rotate Right';

  @override
  String get flipHorizontal => 'Flip Horizontal';

  @override
  String get flipVertical => 'Flip Vertical';

  @override
  String get showInspector => 'Show Inspector';

  @override
  String get hideInspector => 'Hide Inspector';

  @override
  String get sidebarTooltip => 'Sidebar';

  @override
  String get viewOptionsTooltip => 'View options';

  @override
  String get rotateTooltip => 'Rotate';

  @override
  String get searchTooltip => 'Search';

  @override
  String get searchPlaceholder => 'Search';

  @override
  String get searchClear => 'Clear';

  @override
  String get searching => 'Searching…';

  @override
  String get noMatches => 'Not found';

  @override
  String get emptyTitle => 'No document';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get openButton => 'Open';

  @override
  String get go => 'Go';

  @override
  String get save => 'Save…';

  @override
  String get openDialogTitle => 'Open';

  @override
  String get exportDialogTitle => 'Export';

  @override
  String get dialogUnavailable => 'The file dialog isn\'t available.';

  @override
  String get dialogUnavailableDetail =>
      'Silica\'s file chooser portal did not answer.';

  @override
  String get passwordMessage => 'Enter the password to open it.';

  @override
  String get passwordWrong => 'The password is incorrect. Try again.';

  @override
  String get passwordPlaceholder => 'Password';

  @override
  String get goToTitle => 'Go to Page';

  @override
  String get format => 'Format:';

  @override
  String get quality => 'Quality:';

  @override
  String get qualityLeast => 'Least';

  @override
  String get qualityBest => 'Best';

  @override
  String get exportFailed => 'The image couldn\'t be exported.';

  @override
  String get inspectorTitle => 'General Info';

  @override
  String get infoName => 'Name';

  @override
  String get infoKind => 'Kind';

  @override
  String get infoSize => 'File size';

  @override
  String get infoDimensions => 'Dimensions';

  @override
  String get infoColour => 'Color model';

  @override
  String get infoDepth => 'Depth';

  @override
  String get infoAlpha => 'Alpha channel';

  @override
  String get infoFrames => 'Frames';

  @override
  String get infoPages => 'Pages';

  @override
  String get infoPageSize => 'Page size';

  @override
  String get infoVersion => 'Version';

  @override
  String get infoTitle => 'Title';

  @override
  String get infoAuthor => 'Author';

  @override
  String get infoSubject => 'Subject';

  @override
  String get infoCreator => 'Creator';

  @override
  String get infoProducer => 'Producer';

  @override
  String get infoExif => 'EXIF';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get kindPdf => 'PDF document';

  @override
  String get colourRgb => 'RGB';

  @override
  String get colourGray => 'Gray';

  @override
  String get colourCmyk => 'CMYK';

  @override
  String get colourIndexed => 'Indexed';

  @override
  String get colourVector => 'Vector';

  @override
  String get colourUnknown => 'Unknown';

  @override
  String get exifImageMake => 'Make';

  @override
  String get exifImageModel => 'Model';

  @override
  String get exifLensModel => 'Lens';

  @override
  String get exifDateTimeOriginal => 'Date taken';

  @override
  String get exifExposureTime => 'Exposure';

  @override
  String get exifFNumber => 'F-number';

  @override
  String get exifISOSpeedRatings => 'ISO';

  @override
  String get exifFocalLength => 'Focal length';

  @override
  String get exifFlash => 'Flash';

  @override
  String get exifImageSoftware => 'Software';

  @override
  String openFailedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files couldn\'t be opened',
      one: 'The file couldn\'t be opened',
    );
    return '$_temp0';
  }

  @override
  String failMissing(Object name) {
    return '“$name” doesn\'t exist or can\'t be read.';
  }

  @override
  String failUnsupported(Object name) {
    return '“$name” is in a format Preview can\'t open.';
  }

  @override
  String failDamaged(Object name) {
    return '“$name” may be damaged.';
  }

  @override
  String failNoPdf(Object name) {
    return '“$name” needs the PDF library (poppler-glib), which isn\'t installed.';
  }

  @override
  String failOnePdf(Object name) {
    return '“$name”: Preview opens one PDF per window.';
  }

  @override
  String pageOf(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String imageOf(int index, int count) {
    return '$index of $count';
  }

  @override
  String pixels(int width, int height) {
    return '$width × $height pixels';
  }

  @override
  String points(String width, String height) {
    return '$width × $height pt';
  }

  @override
  String bits(int bits) {
    return '$bits bits per channel';
  }

  @override
  String matches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String matchOf(int index, int count) {
    return '$index of $count';
  }

  @override
  String passwordTitle(Object name) {
    return '“$name” is protected with a password.';
  }

  @override
  String goToMessage(int count) {
    return 'Page number (1–$count):';
  }

  @override
  String exportTitle(Object name) {
    return 'Export “$name”';
  }

  @override
  String kindImage(Object format) {
    return '$format image';
  }

  @override
  String fileSize(Object size, Object bytes) {
    return '$size ($bytes bytes)';
  }

  @override
  String pageLabel(int page) {
    return '$page';
  }
}
