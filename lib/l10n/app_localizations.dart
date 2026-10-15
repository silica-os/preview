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
