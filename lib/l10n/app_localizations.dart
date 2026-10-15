import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get appName;

  /// No description provided for @menuFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// No description provided for @menuEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// No description provided for @menuView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// No description provided for @menuGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get menuGo;

  /// No description provided for @menuTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get menuTools;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open…'**
  String get open;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get export;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find…'**
  String get find;

  /// No description provided for @findNext.
  ///
  /// In en, this message translates to:
  /// **'Find Next'**
  String get findNext;

  /// No description provided for @findPrevious.
  ///
  /// In en, this message translates to:
  /// **'Find Previous'**
  String get findPrevious;

  /// No description provided for @hideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide Sidebar'**
  String get hideSidebar;

  /// No description provided for @thumbnails.
  ///
  /// In en, this message translates to:
  /// **'Thumbnails'**
  String get thumbnails;

  /// No description provided for @tableOfContents.
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get tableOfContents;

  /// No description provided for @continuousScroll.
  ///
  /// In en, this message translates to:
  /// **'Continuous Scroll'**
  String get continuousScroll;

  /// No description provided for @singlePage.
  ///
  /// In en, this message translates to:
  /// **'Single Page'**
  String get singlePage;

  /// No description provided for @twoPages.
  ///
  /// In en, this message translates to:
  /// **'Two Pages'**
  String get twoPages;

  /// No description provided for @actualSize.
  ///
  /// In en, this message translates to:
  /// **'Actual Size'**
  String get actualSize;

  /// No description provided for @zoomToFit.
  ///
  /// In en, this message translates to:
  /// **'Zoom to Fit'**
  String get zoomToFit;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get zoomOut;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next Page'**
  String get nextPage;

  /// No description provided for @firstPage.
  ///
  /// In en, this message translates to:
  /// **'First Page'**
  String get firstPage;

  /// No description provided for @lastPage.
  ///
  /// In en, this message translates to:
  /// **'Last Page'**
  String get lastPage;

  /// No description provided for @previousImage.
  ///
  /// In en, this message translates to:
  /// **'Previous Image'**
  String get previousImage;

  /// No description provided for @nextImage.
  ///
  /// In en, this message translates to:
  /// **'Next Image'**
  String get nextImage;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to Page…'**
  String get goToPage;

  /// No description provided for @rotateLeft.
  ///
  /// In en, this message translates to:
  /// **'Rotate Left'**
  String get rotateLeft;

  /// No description provided for @rotateRight.
  ///
  /// In en, this message translates to:
  /// **'Rotate Right'**
  String get rotateRight;

  /// No description provided for @flipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip Horizontal'**
  String get flipHorizontal;

  /// No description provided for @flipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip Vertical'**
  String get flipVertical;

  /// No description provided for @showInspector.
  ///
  /// In en, this message translates to:
  /// **'Show Inspector'**
  String get showInspector;

  /// No description provided for @hideInspector.
  ///
  /// In en, this message translates to:
  /// **'Hide Inspector'**
  String get hideInspector;

  /// No description provided for @sidebarTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get sidebarTooltip;

  /// No description provided for @viewOptionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'View options'**
  String get viewOptionsTooltip;

  /// No description provided for @rotateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get rotateTooltip;

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTooltip;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchPlaceholder;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searching;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get noMatches;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No document'**
  String get emptyTitle;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @openButton.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openButton;

  /// No description provided for @go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save…'**
  String get save;

  /// No description provided for @openDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openDialogTitle;

  /// No description provided for @exportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportDialogTitle;

  /// No description provided for @dialogUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The file dialog isn\'t available.'**
  String get dialogUnavailable;

  /// No description provided for @dialogUnavailableDetail.
  ///
  /// In en, this message translates to:
  /// **'Silica\'s file chooser portal did not answer.'**
  String get dialogUnavailableDetail;

  /// No description provided for @passwordMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the password to open it.'**
  String get passwordMessage;

  /// No description provided for @passwordWrong.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect. Try again.'**
  String get passwordWrong;

  /// No description provided for @passwordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordPlaceholder;

  /// No description provided for @goToTitle.
  ///
  /// In en, this message translates to:
  /// **'Go to Page'**
  String get goToTitle;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format:'**
  String get format;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality:'**
  String get quality;

  /// No description provided for @qualityLeast.
  ///
  /// In en, this message translates to:
  /// **'Least'**
  String get qualityLeast;

  /// No description provided for @qualityBest.
  ///
  /// In en, this message translates to:
  /// **'Best'**
  String get qualityBest;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'The image couldn\'t be exported.'**
  String get exportFailed;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'General Info'**
  String get inspectorTitle;

  /// No description provided for @infoName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get infoName;

  /// No description provided for @infoKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get infoKind;

  /// No description provided for @infoSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get infoSize;

  /// No description provided for @infoDimensions.
  ///
  /// In en, this message translates to:
  /// **'Dimensions'**
  String get infoDimensions;

  /// No description provided for @infoColour.
  ///
  /// In en, this message translates to:
  /// **'Color model'**
  String get infoColour;

  /// No description provided for @infoDepth.
  ///
  /// In en, this message translates to:
  /// **'Depth'**
  String get infoDepth;

  /// No description provided for @infoAlpha.
  ///
  /// In en, this message translates to:
  /// **'Alpha channel'**
  String get infoAlpha;

  /// No description provided for @infoFrames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get infoFrames;

  /// No description provided for @infoPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get infoPages;

  /// No description provided for @infoPageSize.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get infoPageSize;

  /// No description provided for @infoVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get infoVersion;

  /// No description provided for @infoTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get infoTitle;

  /// No description provided for @infoAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get infoAuthor;

  /// No description provided for @infoSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get infoSubject;

  /// No description provided for @infoCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get infoCreator;

  /// No description provided for @infoProducer.
  ///
  /// In en, this message translates to:
  /// **'Producer'**
  String get infoProducer;

  /// No description provided for @infoExif.
  ///
  /// In en, this message translates to:
  /// **'EXIF'**
  String get infoExif;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @kindPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF document'**
  String get kindPdf;

  /// No description provided for @colourRgb.
  ///
  /// In en, this message translates to:
  /// **'RGB'**
  String get colourRgb;

  /// No description provided for @colourGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colourGray;

  /// No description provided for @colourCmyk.
  ///
  /// In en, this message translates to:
  /// **'CMYK'**
  String get colourCmyk;

  /// No description provided for @colourIndexed.
  ///
  /// In en, this message translates to:
  /// **'Indexed'**
  String get colourIndexed;

  /// No description provided for @colourVector.
  ///
  /// In en, this message translates to:
  /// **'Vector'**
  String get colourVector;

  /// No description provided for @colourUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get colourUnknown;

  /// No description provided for @exifImageMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get exifImageMake;

  /// No description provided for @exifImageModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get exifImageModel;

  /// No description provided for @exifLensModel.
  ///
  /// In en, this message translates to:
  /// **'Lens'**
  String get exifLensModel;

  /// No description provided for @exifDateTimeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Date taken'**
  String get exifDateTimeOriginal;

  /// No description provided for @exifExposureTime.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get exifExposureTime;

  /// No description provided for @exifFNumber.
  ///
  /// In en, this message translates to:
  /// **'F-number'**
  String get exifFNumber;

  /// No description provided for @exifISOSpeedRatings.
  ///
  /// In en, this message translates to:
  /// **'ISO'**
  String get exifISOSpeedRatings;

  /// No description provided for @exifFocalLength.
  ///
  /// In en, this message translates to:
  /// **'Focal length'**
  String get exifFocalLength;

  /// No description provided for @exifFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get exifFlash;

  /// No description provided for @exifImageSoftware.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get exifImageSoftware;

  /// No description provided for @openFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The file couldn\'t be opened} other{{count} files couldn\'t be opened}}'**
  String openFailedTitle(int count);

  /// No description provided for @failMissing.
  ///
  /// In en, this message translates to:
  /// **'“{name}” doesn\'t exist or can\'t be read.'**
  String failMissing(Object name);

  /// No description provided for @failUnsupported.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is in a format Preview can\'t open.'**
  String failUnsupported(Object name);

  /// No description provided for @failDamaged.
  ///
  /// In en, this message translates to:
  /// **'“{name}” may be damaged.'**
  String failDamaged(Object name);

  /// No description provided for @failNoPdf.
  ///
  /// In en, this message translates to:
  /// **'“{name}” needs the PDF library (poppler-glib), which isn\'t installed.'**
  String failNoPdf(Object name);

  /// No description provided for @failOnePdf.
  ///
  /// In en, this message translates to:
  /// **'“{name}”: Preview opens one PDF per window.'**
  String failOnePdf(Object name);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String pageOf(int page, int count);

  /// No description provided for @imageOf.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String imageOf(int index, int count);

  /// No description provided for @pixels.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height} pixels'**
  String pixels(int width, int height);

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height} pt'**
  String points(String width, String height);

  /// No description provided for @bits.
  ///
  /// In en, this message translates to:
  /// **'{bits} bits per channel'**
  String bits(int bits);

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String matches(int count);

  /// No description provided for @matchOf.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String matchOf(int index, int count);

  /// No description provided for @passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is protected with a password.'**
  String passwordTitle(Object name);

  /// No description provided for @goToMessage.
  ///
  /// In en, this message translates to:
  /// **'Page number (1–{count}):'**
  String goToMessage(int count);

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export “{name}”'**
  String exportTitle(Object name);

  /// No description provided for @kindImage.
  ///
  /// In en, this message translates to:
  /// **'{format} image'**
  String kindImage(Object format);

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'{size} ({bytes} bytes)'**
  String fileSize(Object size, Object bytes);

  /// No description provided for @pageLabel.
  ///
  /// In en, this message translates to:
  /// **'{page}'**
  String pageLabel(int page);

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add Bookmark'**
  String get addBookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove Bookmark'**
  String get removeBookmark;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get addNote;

  /// No description provided for @adjustSize.
  ///
  /// In en, this message translates to:
  /// **'Adjust Size…'**
  String get adjustSize;

  /// No description provided for @allowPrinting.
  ///
  /// In en, this message translates to:
  /// **'Printing'**
  String get allowPrinting;

  /// No description provided for @allowCopying.
  ///
  /// In en, this message translates to:
  /// **'Copying text and images'**
  String get allowCopying;

  /// No description provided for @allowAssembling.
  ///
  /// In en, this message translates to:
  /// **'Inserting, deleting and rotating pages'**
  String get allowAssembling;

  /// No description provided for @allowAnnotating.
  ///
  /// In en, this message translates to:
  /// **'Adding annotations and signatures'**
  String get allowAnnotating;

  /// No description provided for @allowForms.
  ///
  /// In en, this message translates to:
  /// **'Filling in forms'**
  String get allowForms;

  /// No description provided for @alpha.
  ///
  /// In en, this message translates to:
  /// **'Keep transparency'**
  String get alpha;

  /// No description provided for @annotate.
  ///
  /// In en, this message translates to:
  /// **'Annotate'**
  String get annotate;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @autoSize.
  ///
  /// In en, this message translates to:
  /// **'Fit Automatically'**
  String get autoSize;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @blankPage.
  ///
  /// In en, this message translates to:
  /// **'Blank Page'**
  String get blankPage;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @borderColour.
  ///
  /// In en, this message translates to:
  /// **'Border Colour'**
  String get borderColour;

  /// No description provided for @fillColour.
  ///
  /// In en, this message translates to:
  /// **'Fill Colour'**
  String get fillColour;

  /// No description provided for @closeImage.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeImage;

  /// No description provided for @closeWindow.
  ///
  /// In en, this message translates to:
  /// **'Close Window'**
  String get closeWindow;

  /// No description provided for @colourYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colourYellow;

  /// No description provided for @colourGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colourGreen;

  /// No description provided for @colourBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colourBlue;

  /// No description provided for @colourPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colourPink;

  /// No description provided for @colourPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colourPurple;

  /// No description provided for @columnPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get columnPage;

  /// No description provided for @columnType.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get columnType;

  /// No description provided for @columnAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get columnAuthor;

  /// No description provided for @columnDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get columnDate;

  /// No description provided for @contactSheet.
  ///
  /// In en, this message translates to:
  /// **'Contact Sheet'**
  String get contactSheet;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @dashed.
  ///
  /// In en, this message translates to:
  /// **'Dashed'**
  String get dashed;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete Page'**
  String get deletePage;

  /// No description provided for @documentsTotal.
  ///
  /// In en, this message translates to:
  /// **'{documents} documents, {pages} pages in all'**
  String documentsTotal(int documents, int pages);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get edited;

  /// No description provided for @withEdited.
  ///
  /// In en, this message translates to:
  /// **'{line} — Edited'**
  String withEdited(String line);

  /// No description provided for @editPermissions.
  ///
  /// In en, this message translates to:
  /// **'Edit Permissions…'**
  String get editPermissions;

  /// No description provided for @exportAs.
  ///
  /// In en, this message translates to:
  /// **'Export As…'**
  String get exportAs;

  /// No description provided for @exportAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF…'**
  String get exportAsPdf;

  /// No description provided for @fileSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'File size:'**
  String get fileSizeLabel;

  /// No description provided for @findMenu.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get findMenu;

  /// No description provided for @fitInto.
  ///
  /// In en, this message translates to:
  /// **'Fit into:'**
  String get fitInto;

  /// No description provided for @widthLabel.
  ///
  /// In en, this message translates to:
  /// **'Width:'**
  String get widthLabel;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height:'**
  String get heightLabel;

  /// No description provided for @foundOnPages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Found on 1 page} other{Found on {count} pages}}'**
  String foundOnPages(int count);

  /// No description provided for @showMarkupToolbar.
  ///
  /// In en, this message translates to:
  /// **'Show Markup Toolbar'**
  String get showMarkupToolbar;

  /// No description provided for @hideMarkupToolbar.
  ///
  /// In en, this message translates to:
  /// **'Hide Markup Toolbar'**
  String get hideMarkupToolbar;

  /// No description provided for @showToolbar.
  ///
  /// In en, this message translates to:
  /// **'Show Toolbar'**
  String get showToolbar;

  /// No description provided for @hideToolbar.
  ///
  /// In en, this message translates to:
  /// **'Hide Toolbar'**
  String get hideToolbar;

  /// No description provided for @highlightsAndNotes.
  ///
  /// In en, this message translates to:
  /// **'Highlights and Notes'**
  String get highlightsAndNotes;

  /// No description provided for @highlightText.
  ///
  /// In en, this message translates to:
  /// **'Highlight Text'**
  String get highlightText;

  /// No description provided for @underlineText.
  ///
  /// In en, this message translates to:
  /// **'Underline Text'**
  String get underlineText;

  /// No description provided for @strikethroughText.
  ///
  /// In en, this message translates to:
  /// **'Strike Through Text'**
  String get strikethroughText;

  /// No description provided for @highlightTooltip.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlightTooltip;

  /// No description provided for @markupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Markup'**
  String get markupTooltip;

  /// No description provided for @inspectorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get inspectorTooltip;

  /// No description provided for @viewMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewMenuTooltip;

  /// No description provided for @zoomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoomTooltip;

  /// No description provided for @infoModified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get infoModified;

  /// No description provided for @insert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insert;

  /// No description provided for @inspectorGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get inspectorGeneral;

  /// No description provided for @inspectorMore.
  ///
  /// In en, this message translates to:
  /// **'More Info'**
  String get inspectorMore;

  /// No description provided for @inspectorKeywords.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get inspectorKeywords;

  /// No description provided for @inspectorAnnotations.
  ///
  /// In en, this message translates to:
  /// **'Annotations'**
  String get inspectorAnnotations;

  /// No description provided for @kindHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get kindHighlight;

  /// No description provided for @underline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get underline;

  /// No description provided for @strikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get strikethrough;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @revertTo.
  ///
  /// In en, this message translates to:
  /// **'Revert To'**
  String get revertTo;

  /// No description provided for @lastOpened.
  ///
  /// In en, this message translates to:
  /// **'Last Opened…'**
  String get lastOpened;

  /// No description provided for @revert.
  ///
  /// In en, this message translates to:
  /// **'Revert'**
  String get revert;

  /// No description provided for @revertTitle.
  ///
  /// In en, this message translates to:
  /// **'Go back to the file as it was opened?'**
  String get revertTitle;

  /// No description provided for @revertMessage.
  ///
  /// In en, this message translates to:
  /// **'The changes made since then will be lost.'**
  String get revertMessage;

  /// No description provided for @revertFailed.
  ///
  /// In en, this message translates to:
  /// **'The file couldn\'t be reverted.'**
  String get revertFailed;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name:'**
  String get nameLabel;

  /// No description provided for @whereLabel.
  ///
  /// In en, this message translates to:
  /// **'Where:'**
  String get whereLabel;

  /// No description provided for @newKeyword.
  ///
  /// In en, this message translates to:
  /// **'New keyword'**
  String get newKeyword;

  /// No description provided for @noKeywords.
  ///
  /// In en, this message translates to:
  /// **'No Keywords'**
  String get noKeywords;

  /// No description provided for @pageUp.
  ///
  /// In en, this message translates to:
  /// **'Page Up'**
  String get pageUp;

  /// No description provided for @pageDown.
  ///
  /// In en, this message translates to:
  /// **'Page Down'**
  String get pageDown;

  /// No description provided for @previousDocument.
  ///
  /// In en, this message translates to:
  /// **'Previous Document'**
  String get previousDocument;

  /// No description provided for @nextDocument.
  ///
  /// In en, this message translates to:
  /// **'Next Document'**
  String get nextDocument;

  /// No description provided for @previousItem.
  ///
  /// In en, this message translates to:
  /// **'Previous Item'**
  String get previousItem;

  /// No description provided for @nextItem.
  ///
  /// In en, this message translates to:
  /// **'Next Item'**
  String get nextItem;

  /// No description provided for @pageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String pageNumber(int page);

  /// No description provided for @passwordProtected.
  ///
  /// In en, this message translates to:
  /// **'This document is locked with a password.'**
  String get passwordProtected;

  /// No description provided for @passwordEnter.
  ///
  /// In en, this message translates to:
  /// **'Type the password to open it.'**
  String get passwordEnter;

  /// No description provided for @passwordInvalid.
  ///
  /// In en, this message translates to:
  /// **'That password is not right.'**
  String get passwordInvalid;

  /// No description provided for @passwordMissing.
  ///
  /// In en, this message translates to:
  /// **'Type a password to open the document.'**
  String get passwordMissing;

  /// No description provided for @passwordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The two passwords are not the same.'**
  String get passwordsDiffer;

  /// No description provided for @ownerPasswordMissing.
  ///
  /// In en, this message translates to:
  /// **'Restricting what can be done needs an owner password.'**
  String get ownerPasswordMissing;

  /// No description provided for @ownerPassword.
  ///
  /// In en, this message translates to:
  /// **'Owner password'**
  String get ownerPassword;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get permissions;

  /// No description provided for @permissionsButton.
  ///
  /// In en, this message translates to:
  /// **'Permissions…'**
  String get permissionsButton;

  /// No description provided for @requirePassword.
  ///
  /// In en, this message translates to:
  /// **'Ask for a password to open the document'**
  String get requirePassword;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get verify;

  /// No description provided for @pixelsPerInch.
  ///
  /// In en, this message translates to:
  /// **'pixels/inch'**
  String get pixelsPerInch;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution:'**
  String get resolution;

  /// No description provided for @scaleProportionally.
  ///
  /// In en, this message translates to:
  /// **'Keep proportions'**
  String get scaleProportionally;

  /// No description provided for @resultingSize.
  ///
  /// In en, this message translates to:
  /// **'Resulting size'**
  String get resultingSize;

  /// No description provided for @resultingDetail.
  ///
  /// In en, this message translates to:
  /// **'{percent} %, {before} before, about {after} after'**
  String resultingDetail(String percent, String before, String after);

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @removeHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove Highlight'**
  String get removeHighlight;

  /// No description provided for @removeNote.
  ///
  /// In en, this message translates to:
  /// **'Remove Note'**
  String get removeNote;

  /// No description provided for @renameCommand.
  ///
  /// In en, this message translates to:
  /// **'Rename…'**
  String get renameCommand;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'“{name}” can\'t be used: a file with that name is already there, or the folder can\'t be written.'**
  String renameFailed(Object name);

  /// No description provided for @resultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String resultCount(int count);

  /// No description provided for @saveCommand.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveCommand;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'The changes couldn\'t be saved.'**
  String get saveFailed;

  /// No description provided for @shadow.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get shadow;

  /// No description provided for @shapes.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get shapes;

  /// No description provided for @shapeLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get shapeLine;

  /// No description provided for @shapeArrow.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get shapeArrow;

  /// No description provided for @shapeRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get shapeRectangle;

  /// No description provided for @shapeRoundedRectangle.
  ///
  /// In en, this message translates to:
  /// **'Rounded Rectangle'**
  String get shapeRoundedRectangle;

  /// No description provided for @shapeOval.
  ///
  /// In en, this message translates to:
  /// **'Oval'**
  String get shapeOval;

  /// No description provided for @shapeBubble.
  ///
  /// In en, this message translates to:
  /// **'Speech Balloon'**
  String get shapeBubble;

  /// No description provided for @shapeStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get shapeStar;

  /// No description provided for @shapePolygon.
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get shapePolygon;

  /// No description provided for @shapeText.
  ///
  /// In en, this message translates to:
  /// **'Text Box'**
  String get shapeText;

  /// No description provided for @shapeStyle.
  ///
  /// In en, this message translates to:
  /// **'Shape Style'**
  String get shapeStyle;

  /// No description provided for @textStyle.
  ///
  /// In en, this message translates to:
  /// **'Text Style'**
  String get textStyle;

  /// No description provided for @textColour.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get textColour;

  /// No description provided for @textPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textPlaceholder;

  /// No description provided for @slideshow.
  ///
  /// In en, this message translates to:
  /// **'Slideshow'**
  String get slideshow;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortName;

  /// No description provided for @sortPath.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get sortPath;

  /// No description provided for @sortDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get sortDate;

  /// No description provided for @sortSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sortSize;

  /// No description provided for @sortKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get sortKind;

  /// No description provided for @sortNone.
  ///
  /// In en, this message translates to:
  /// **'As Opened'**
  String get sortNone;

  /// No description provided for @sortRank.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get sortRank;

  /// No description provided for @sortPage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get sortPage;

  /// No description provided for @unitPixels.
  ///
  /// In en, this message translates to:
  /// **'pixels'**
  String get unitPixels;

  /// No description provided for @unitPercent.
  ///
  /// In en, this message translates to:
  /// **'percent'**
  String get unitPercent;

  /// No description provided for @unitInches.
  ///
  /// In en, this message translates to:
  /// **'inches'**
  String get unitInches;

  /// No description provided for @unitCentimetres.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get unitCentimetres;

  /// No description provided for @unitMillimetres.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get unitMillimetres;

  /// No description provided for @unitPoints.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get unitPoints;

  /// No description provided for @useSelectionForFind.
  ///
  /// In en, this message translates to:
  /// **'Use Selection for Find'**
  String get useSelectionForFind;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
