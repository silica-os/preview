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

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String get removeBookmark => 'Remove Bookmark';

  @override
  String get addNote => 'Add Note';

  @override
  String get adjustSize => 'Adjust Size…';

  @override
  String get allowPrinting => 'Printing';

  @override
  String get allowCopying => 'Copying text and images';

  @override
  String get allowAssembling => 'Inserting, deleting and rotating pages';

  @override
  String get allowAnnotating => 'Adding annotations and signatures';

  @override
  String get allowForms => 'Filling in forms';

  @override
  String get alpha => 'Keep transparency';

  @override
  String get annotate => 'Annotate';

  @override
  String get apply => 'Apply';

  @override
  String get autoSize => 'Fit Automatically';

  @override
  String get back => 'Back';

  @override
  String get forward => 'Forward';

  @override
  String get blankPage => 'Blank Page';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get borderColour => 'Border Colour';

  @override
  String get fillColour => 'Fill Colour';

  @override
  String get closeImage => 'Close';

  @override
  String get closeWindow => 'Close Window';

  @override
  String get colourYellow => 'Yellow';

  @override
  String get colourGreen => 'Green';

  @override
  String get colourBlue => 'Blue';

  @override
  String get colourPink => 'Pink';

  @override
  String get colourPurple => 'Purple';

  @override
  String get columnPage => 'Page';

  @override
  String get columnType => 'Kind';

  @override
  String get columnAuthor => 'Author';

  @override
  String get columnDate => 'Date';

  @override
  String get contactSheet => 'Contact Sheet';

  @override
  String get custom => 'Custom';

  @override
  String get dashed => 'Dashed';

  @override
  String get delete => 'Delete';

  @override
  String get deletePage => 'Delete Page';

  @override
  String documentsTotal(int documents, int pages) {
    return '$documents documents, $pages pages in all';
  }

  @override
  String get done => 'Done';

  @override
  String get edited => 'Edited';

  @override
  String withEdited(String line) {
    return '$line — Edited';
  }

  @override
  String get editPermissions => 'Edit Permissions…';

  @override
  String get exportAs => 'Export As…';

  @override
  String get exportAsPdf => 'Export as PDF…';

  @override
  String get fileSizeLabel => 'File size:';

  @override
  String get findMenu => 'Find';

  @override
  String get fitInto => 'Fit into:';

  @override
  String get widthLabel => 'Width:';

  @override
  String get heightLabel => 'Height:';

  @override
  String foundOnPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Found on $count pages',
      one: 'Found on 1 page',
    );
    return '$_temp0';
  }

  @override
  String get showMarkupToolbar => 'Show Markup Toolbar';

  @override
  String get hideMarkupToolbar => 'Hide Markup Toolbar';

  @override
  String get showToolbar => 'Show Toolbar';

  @override
  String get hideToolbar => 'Hide Toolbar';

  @override
  String get highlightsAndNotes => 'Highlights and Notes';

  @override
  String get highlightText => 'Highlight Text';

  @override
  String get underlineText => 'Underline Text';

  @override
  String get strikethroughText => 'Strike Through Text';

  @override
  String get highlightTooltip => 'Highlight';

  @override
  String get markupTooltip => 'Markup';

  @override
  String get inspectorTooltip => 'Inspector';

  @override
  String get viewMenuTooltip => 'View';

  @override
  String get zoomTooltip => 'Zoom';

  @override
  String get overflowTooltip => 'More';

  @override
  String get textSize => 'Text size';

  @override
  String get bold => 'Bold';

  @override
  String get italic => 'Italic';

  @override
  String get alignLeft => 'Align left';

  @override
  String get alignCenter => 'Centre';

  @override
  String get alignRight => 'Align right';

  @override
  String get alignJustify => 'Justify';

  @override
  String get infoModified => 'Modified';

  @override
  String get insert => 'Insert';

  @override
  String get inspectorGeneral => 'General';

  @override
  String get inspectorMore => 'More Info';

  @override
  String get inspectorKeywords => 'Keywords';

  @override
  String get inspectorAnnotations => 'Annotations';

  @override
  String get kindHighlight => 'Highlight';

  @override
  String get underline => 'Underline';

  @override
  String get strikethrough => 'Strikethrough';

  @override
  String get note => 'Note';

  @override
  String get revertTo => 'Revert To';

  @override
  String get lastOpened => 'Last Opened…';

  @override
  String get revert => 'Revert';

  @override
  String get revertTitle => 'Go back to the file as it was opened?';

  @override
  String get revertMessage => 'The changes made since then will be lost.';

  @override
  String get revertFailed => 'The file couldn\'t be reverted.';

  @override
  String get nameLabel => 'Name:';

  @override
  String get whereLabel => 'Where:';

  @override
  String get newKeyword => 'New keyword';

  @override
  String get noKeywords => 'No Keywords';

  @override
  String get pageUp => 'Page Up';

  @override
  String get pageDown => 'Page Down';

  @override
  String get previousDocument => 'Previous Document';

  @override
  String get nextDocument => 'Next Document';

  @override
  String get previousItem => 'Previous Item';

  @override
  String get nextItem => 'Next Item';

  @override
  String pageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get passwordProtected => 'This document is locked with a password.';

  @override
  String get passwordEnter => 'Type the password to open it.';

  @override
  String get passwordInvalid => 'That password is not right.';

  @override
  String get passwordMissing => 'Type a password to open the document.';

  @override
  String get passwordsDiffer => 'The two passwords are not the same.';

  @override
  String get ownerPasswordMissing =>
      'Restricting what can be done needs an owner password.';

  @override
  String get ownerPassword => 'Owner password';

  @override
  String get permissions => 'Allowed';

  @override
  String get permissionsButton => 'Permissions…';

  @override
  String get requirePassword => 'Ask for a password to open the document';

  @override
  String get verify => 'Again';

  @override
  String ppiValue(int value) {
    return '$value ppi';
  }

  @override
  String get pixelsPerInch => 'pixels/inch';

  @override
  String get resolution => 'Resolution:';

  @override
  String get scaleProportionally => 'Keep proportions';

  @override
  String get resultingSize => 'Resulting size';

  @override
  String resultingDetail(String percent, String before, String after) {
    return '$percent %, $before before, about $after after';
  }

  @override
  String get redo => 'Redo';

  @override
  String get undo => 'Undo';

  @override
  String get removeHighlight => 'Remove Highlight';

  @override
  String get removeNote => 'Remove Note';

  @override
  String get renameCommand => 'Rename…';

  @override
  String renameFailed(Object name) {
    return '“$name” can\'t be used: a file with that name is already there, or the folder can\'t be written.';
  }

  @override
  String resultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String get saveCommand => 'Save';

  @override
  String get saveFailed => 'The changes couldn\'t be saved.';

  @override
  String get shadow => 'Shadow';

  @override
  String get shapes => 'Shapes';

  @override
  String get shapeLine => 'Line';

  @override
  String get shapeArrow => 'Arrow';

  @override
  String get shapeRectangle => 'Rectangle';

  @override
  String get shapeRoundedRectangle => 'Rounded Rectangle';

  @override
  String get shapeOval => 'Oval';

  @override
  String get shapeBubble => 'Speech Balloon';

  @override
  String get shapeStar => 'Star';

  @override
  String get shapePolygon => 'Polygon';

  @override
  String get shapeText => 'Text Box';

  @override
  String get shapeStyle => 'Shape Style';

  @override
  String get textStyle => 'Text Style';

  @override
  String get textColour => 'Colour';

  @override
  String get textPlaceholder => 'Text';

  @override
  String get slideshow => 'Slideshow';

  @override
  String get sortBy => 'Sort By';

  @override
  String get sortName => 'Name';

  @override
  String get sortPath => 'Folder';

  @override
  String get sortDate => 'Date';

  @override
  String get sortSize => 'Size';

  @override
  String get sortKind => 'Kind';

  @override
  String get sortNone => 'As Opened';

  @override
  String get sortRank => 'Matches';

  @override
  String get sortPage => 'Page';

  @override
  String get unitPixels => 'pixels';

  @override
  String get unitPercent => 'percent';

  @override
  String get unitInches => 'inches';

  @override
  String get unitCentimetres => 'cm';

  @override
  String get unitMillimetres => 'mm';

  @override
  String get unitPoints => 'points';

  @override
  String get useSelectionForFind => 'Use Selection for Find';

  @override
  String get menuWindow => 'Window';

  @override
  String get menuHelp => 'Help';

  @override
  String get newFromClipboard => 'New from Clipboard';

  @override
  String get openRecent => 'Open Recent';

  @override
  String get clearMenu => 'Clear Menu';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get moveTo => 'Move To…';

  @override
  String get enterPassword => 'Enter Password…';

  @override
  String get print => 'Print…';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get invertSelection => 'Invert Selection';

  @override
  String get pageFromFile => 'Page from File…';

  @override
  String get moveToTrash => 'Move to Trash';

  @override
  String get jumpToSelection => 'Jump to Selection';

  @override
  String get zoomToSelection => 'Zoom to Selection';

  @override
  String get customizeToolbar => 'Customize Toolbar…';

  @override
  String get showMagnifier => 'Show Magnifier';

  @override
  String get rectangularSelection => 'Rectangular Selection';

  @override
  String get textSelection => 'Text Selection';

  @override
  String get redact => 'Redact';

  @override
  String get mask => 'Mask';

  @override
  String get loupe => 'Loupe';

  @override
  String get signature => 'Signature';

  @override
  String get crop => 'Crop';

  @override
  String get removeBackground => 'Remove Background';
}
