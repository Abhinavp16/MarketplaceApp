// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutBrand => 'TradeHub Demo';

  @override
  String get aboutDescription =>
      'TradeHub Demo is a demonstration marketplace that shows how retailers, wholesalers, and buyers can work together on one platform. You can discover products, place orders, negotiate bulk deals, and manage delivery from one app. All data in this environment is synthetic.';

  @override
  String get aboutFeatureCatalogue =>
      'A sample catalogue across many product categories';

  @override
  String get aboutFeatureDealerSupport => 'Dealer and bulk order support';

  @override
  String get aboutFeatureDirectContact =>
      'Direct contact with the business support team';

  @override
  String get aboutFeatureDispatch => 'Sales and dispatch coordination';

  @override
  String get aboutTagline => 'Distribution made simple';

  @override
  String get aboutTitle => 'About TradeHub Demo';

  @override
  String get aboutWhatYouCanDo => 'What you can do';

  @override
  String get addProductAllowNegotiation => 'Allow Price Negotiation';

  @override
  String get addProductAllowNegotiationHint =>
      'Buyers can send price proposals';

  @override
  String get addProductBasicInfo => 'Basic Information';

  @override
  String get addProductCategoryHarvesters => 'Harvesters';

  @override
  String get addProductCategoryLabel => 'Category';

  @override
  String get addProductCategoryMills => 'Mills';

  @override
  String get addProductCategoryOther => 'Other';

  @override
  String get addProductCategoryPumps => 'Pumps';

  @override
  String get addProductCategorySprayers => 'Sprayers';

  @override
  String get addProductCategoryTillers => 'Tillers';

  @override
  String get addProductDescriptionHint => 'Enter product description';

  @override
  String get addProductDescriptionLabel => 'Description';

  @override
  String get addProductEnginePowerHint => 'e.g., 7HP';

  @override
  String get addProductEnginePowerLabel => 'Engine Power';

  @override
  String get addProductFuelTypeHint => 'e.g., Petrol';

  @override
  String get addProductFuelTypeLabel => 'Fuel Type';

  @override
  String get addProductMinOrderQtyLabel => 'Minimum Order Qty';

  @override
  String get addProductNameHint => 'Enter product name';

  @override
  String get addProductNameLabel => 'Product Name';

  @override
  String get addProductPriceLabel => 'Price (\$)';

  @override
  String get addProductPricingStock => 'Pricing & Stock';

  @override
  String get addProductPublish => 'Publish Product';

  @override
  String get addProductPublished => 'Product published successfully!';

  @override
  String get addProductSaveDraft => 'Save Draft';

  @override
  String get addProductSpecifications => 'Specifications';

  @override
  String get addProductStockQtyLabel => 'Stock Qty';

  @override
  String get addProductTitle => 'Add New Product';

  @override
  String get addProductUploadHint => 'Add up to 5 images (JPG, PNG)';

  @override
  String get addProductUploadImages => 'Upload Product Images';

  @override
  String get addProductWarrantyHint => 'e.g., 1 Year';

  @override
  String get addProductWarrantyLabel => 'Warranty';

  @override
  String get addProductWeightHint => 'e.g., 50kg';

  @override
  String get addProductWeightLabel => 'Weight';

  @override
  String get addProductWholesaleSettings => 'Wholesale Settings';

  @override
  String get addressAdd => 'Add';

  @override
  String get addressBanner =>
      'Keep two delivery slots ready: Primary and Secondary.';

  @override
  String get addressDefaultBadge => 'Default';

  @override
  String get addressDefaultForDelivery => 'Default for delivery';

  @override
  String get addressEmpty =>
      'No address saved yet. Add this delivery slot now.';

  @override
  String get addressPrimarySaved => 'Primary address saved';

  @override
  String get addressPrimarySetDefault => 'Primary set as default';

  @override
  String get addressPrimaryTitle => 'Primary Address';

  @override
  String get addressSaveButton => 'Save Address';

  @override
  String get addressSaveFailed => 'Could not save address. Please try again.';

  @override
  String get addressSecondarySaved => 'Secondary address saved';

  @override
  String get addressSecondarySetDefault => 'Secondary set as default';

  @override
  String get addressSecondaryTitle => 'Secondary Address';

  @override
  String get addressSetAsDefault => 'Set as default';

  @override
  String get addressSlotPrimary => 'Primary';

  @override
  String get addressSlotSecondary => 'Secondary';

  @override
  String get apiErrorAccountDeactivated =>
      'Your account is deactivated. Please contact support.';

  @override
  String get apiErrorAddressIncomplete =>
      'Your address is incomplete. Please enter the full delivery address.';

  @override
  String get apiErrorCartEmpty => 'Your cart is empty.';

  @override
  String get apiErrorCouponMinPurchase =>
      'Your order total is below the minimum amount for this coupon.';

  @override
  String apiErrorCouponMinPurchaseAmount(String amount) {
    return 'Minimum purchase amount for this coupon is ₹$amount.';
  }

  @override
  String get apiErrorCouponNotApplicable =>
      'This coupon can\'t be used for this order.';

  @override
  String get apiErrorInsufficientStock =>
      'Some items don\'t have enough stock. Please update the quantity.';

  @override
  String get apiErrorInvalidCoupon => 'Invalid or expired coupon code.';

  @override
  String get apiErrorInvalidQuantity => 'Please enter a valid quantity.';

  @override
  String get apiErrorMinWholesaleQuantity =>
      'Please order at least the minimum wholesale quantity.';

  @override
  String get apiErrorNegotiationCheckoutDisabled =>
      'Ordering from a deal is turned off right now.';

  @override
  String get apiErrorNegotiationDisabled =>
      'Negotiation is not available for this product.';

  @override
  String get apiErrorNegotiationExpired => 'This deal has expired.';

  @override
  String get apiErrorNegotiationNotFound => 'This deal is no longer available.';

  @override
  String get apiErrorNoPermission => 'You don\'t have permission to do this.';

  @override
  String get apiErrorOrderNotFound => 'This order could not be found.';

  @override
  String get apiErrorProductNotFound => 'This product is no longer available.';

  @override
  String get apiErrorServiceUnavailable =>
      'The service is temporarily unavailable. Please try again later.';

  @override
  String get apiErrorSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get apiErrorTooManyRequests =>
      'Too many requests. Please wait a moment and try again.';

  @override
  String get appTitle => 'TradeHub Demo';

  @override
  String get authBusinessNameHint => 'Your shop or company name';

  @override
  String get authConfirmPasswordHint => 'Re-enter your password';

  @override
  String get authConfirmPasswordLabel => 'Confirm Password';

  @override
  String get authConsentAnd => 'and';

  @override
  String get authConsentIntro => 'By continuing, you agree to our:';

  @override
  String get authConsentPointCollect =>
      '- We collect basic details like name, phone, email, and app usage data.';

  @override
  String get authConsentPointRights =>
      '- You can request access, correction, or deletion of your data where permitted.';

  @override
  String get authConsentPointShare =>
      '- We share data only with logistics, payment, service partners, or legal authorities.';

  @override
  String get authConsentPointUse =>
      '- We use this data to process orders, provide support, and improve services.';

  @override
  String get authConsentPrivacyLink => 'Privacy Policy.';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authErrorAcceptTerms =>
      'Please accept Terms & Conditions and Privacy Policy';

  @override
  String get authErrorInvalidPhone => 'Please enter a valid phone number';

  @override
  String get authErrorPasswordMismatch => 'Passwords do not match';

  @override
  String get authErrorPasswordShort => 'Password must be at least 6 characters';

  @override
  String get authErrorPhoneIndian =>
      'Enter a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9.';

  @override
  String get authErrorPhoneNotReal =>
      'Enter a real mobile number, not a repeated or sequential number.';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authJoinSubtitle => 'Join TradeHub Demo today';

  @override
  String get authNameHint => 'Enter your name';

  @override
  String get authNeedHelp =>
      'Need help accessing your account? Contact Support';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authPasswordHint => 'Enter your password';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPhoneHint => '10-digit mobile number';

  @override
  String get authRoleCustomer => 'Customer';

  @override
  String get authRoleWholesaler => 'Wholesaler';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authSignInSubtitle => 'Sign in to continue to TradeHub Demo';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authWelcomeBack => 'Welcome Back';

  @override
  String get authWholesalerProofNote =>
      'After creating your account, submit your business proof from Become a Wholesaler for admin review.';

  @override
  String get buyNowAddAddress => 'Add';

  @override
  String get buyNowAddDeliveryAddress => 'Add Delivery Address';

  @override
  String get buyNowAddNewAddress => '+ Add New';

  @override
  String get buyNowChangeAddress => 'Change';

  @override
  String get buyNowDeliveryAddress => 'Delivery Address';

  @override
  String get buyNowLoginRequiredMessage =>
      'Login is required before placing an order. Please log in to continue checkout.';

  @override
  String get buyNowOrderFailed => 'Failed to create order';

  @override
  String get buyNowPreviewDisabled =>
      'Buy Now is disabled in customer preview mode. Your wholesaler account remains unchanged.';

  @override
  String get buyNowPreviewTitle => 'Customer Preview';

  @override
  String get buyNowPrimaryAddress => 'Primary';

  @override
  String get buyNowSelectAddress => 'Select Address';

  @override
  String get buyNowSubmitOrder => 'Submit Order';

  @override
  String get buyNowTitle => 'Order Summary';

  @override
  String get cartBrowseProducts => 'Browse Products';

  @override
  String get cartCheckingStock => 'Checking stock...';

  @override
  String get cartCheckoutFailed => 'Checkout failed';

  @override
  String cartCouponApplied(String amount) {
    return 'Code applied: -₹$amount';
  }

  @override
  String get cartCouponEnterCode => 'Please enter a coupon code';

  @override
  String get cartCouponFailed => 'Failed to apply coupon';

  @override
  String get cartCouponHint => 'Enter coupon code';

  @override
  String get cartCouponInvalid => 'Invalid coupon code';

  @override
  String get cartDeliveryFee => 'Delivery Fee';

  @override
  String get cartDiscount => 'Discount';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get cartFixStockIssues => 'Fix Stock Issues';

  @override
  String get cartGrandTotal => 'Grand Total';

  @override
  String cartInStockCount(String count) {
    return '$count in stock';
  }

  @override
  String get cartIssueGeneric => 'Stock issue';

  @override
  String cartIssueInsufficientStock(int count, String product) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return 'Only $_temp0 of $product available';
  }

  @override
  String cartIssueMinWholesale(String product, String quantity) {
    return 'Minimum wholesale quantity for $product is $quantity';
  }

  @override
  String cartIssueOutOfStock(String product) {
    return '$product is out of stock';
  }

  @override
  String cartIssueUnavailable(String product) {
    return '$product is currently unavailable';
  }

  @override
  String cartItemMinWholesale(String quantity) {
    return 'Minimum wholesale quantity is $quantity';
  }

  @override
  String cartItemOnlyAvailable(String available, String selected) {
    return 'Only $available available (you selected $selected)';
  }

  @override
  String cartItemOnlyStockAvailable(String available) {
    return 'Only $available available';
  }

  @override
  String get cartItemOutOfStock => 'Out of stock — please remove this item';

  @override
  String get cartItemUnavailable => 'This product is currently unavailable';

  @override
  String get cartLoginRequiredMessage =>
      'You can add products to cart, but login is required to place an order.';

  @override
  String get cartLoginRequiredTitle => 'Login Required';

  @override
  String cartMinusRupees(String amount) {
    return '-₹$amount';
  }

  @override
  String get cartNotNow => 'Not now';

  @override
  String cartOnlyUnitsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return 'Only $_temp0 available';
  }

  @override
  String get cartPreviewCheckoutDisabled =>
      'Checkout is disabled in customer preview mode.';

  @override
  String get cartPreviewDisabled => 'Shopping is disabled in preview mode';

  @override
  String get cartPreviewPrivate =>
      'Your wholesaler cart is private and remains unchanged.';

  @override
  String get cartPreviewTitle => 'Customer Cart Preview';

  @override
  String get cartPriceSummary => 'Price Summary';

  @override
  String get cartProceedToCheckout => 'Proceed to Checkout';

  @override
  String get cartProcessing => 'Processing...';

  @override
  String cartSetQuantity(String quantity) {
    return 'Set to $quantity';
  }

  @override
  String get cartStockIssuesBanner =>
      'Some items have stock issues. Please adjust quantities.';

  @override
  String get cartStockIssuesMessage =>
      'Some items in your cart have stock issues. Please update quantities before checkout.';

  @override
  String get cartStockIssuesTitle => 'Stock Issues';

  @override
  String get cartTitle => 'Shopping Cart';

  @override
  String get categoryBackToCategories => 'Back to categories';

  @override
  String get categoryBackToTypes => 'Back to types';

  @override
  String get categoryBrandNotFound =>
      'Brand not found. Select a brand from the left.';

  @override
  String categoryCategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String get categoryGeneralProducts => 'General Products';

  @override
  String get categoryLoadProductsError => 'Could not load products';

  @override
  String get categoryNoBrands => 'No brands found';

  @override
  String get categoryNoCategoriesForBrand =>
      'No categories available for this brand';

  @override
  String get categoryNoProductsInCategory => 'No products in this category';

  @override
  String get categoryNoProductsInSubcategory =>
      'No products in this subcategory';

  @override
  String get categoryOtherProducts => 'Other Products';

  @override
  String get categorySelectCategory => 'Select a category';

  @override
  String get categorySelectType => 'Select a type';

  @override
  String categorySubcategoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subcategories',
      one: '1 subcategory',
    );
    return '$_temp0';
  }

  @override
  String get categoryTitle => 'Categories';

  @override
  String categoryTypesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count types',
      one: '1 type',
    );
    return '$_temp0';
  }

  @override
  String get categoryViewProduct => 'View Product';

  @override
  String get checkoutAddressLine1 => 'Address Line 1';

  @override
  String get checkoutApprovalNote =>
      'We’ll notify you after the TradeHub Demo team reviews your order.';

  @override
  String get checkoutAwaitingApproval => 'Awaiting Approval';

  @override
  String get checkoutChooseAnotherWay =>
      'Choose another way to send or save your receipt.';

  @override
  String get checkoutConfirmAndPay => 'Confirm & Pay';

  @override
  String get checkoutContinueShopping => 'Continue Shopping';

  @override
  String get checkoutCopyOrderDetails => 'Copy Order Details';

  @override
  String get checkoutFullName => 'Full Name';

  @override
  String get checkoutOrderDetailsCopied => 'Order details copied.';

  @override
  String get checkoutOrderSaved => 'Order saved successfully';

  @override
  String checkoutOrderSavedChooseAnotherWay(String orderNumber) {
    return 'Order $orderNumber is saved. Choose another way to send or save your receipt.';
  }

  @override
  String get checkoutOrderSubmitted => 'Order Submitted';

  @override
  String get checkoutPhone => 'Phone';

  @override
  String checkoutPhoneValue(String phone) {
    return 'Phone: $phone';
  }

  @override
  String get checkoutReceiptPrepareFailed =>
      'We saved your order, but could not prepare the PDF receipt.';

  @override
  String get checkoutReceiptShareFailed =>
      'We saved your order, but could not open the receipt sharing options.';

  @override
  String get checkoutReceiptUnavailableNow =>
      'Unable to prepare the PDF receipt right now.';

  @override
  String get checkoutShareOptionsFailed =>
      'Unable to open receipt sharing options.';

  @override
  String get checkoutShareReceipt => 'Share Receipt';

  @override
  String get checkoutShareSheetOpened => 'Choose an app to send your receipt.';

  @override
  String get checkoutShippingAddress => 'Shipping Address';

  @override
  String get checkoutViewOrder => 'View Order';

  @override
  String get checkoutWebSavedMessage =>
      'Your order was saved. You can try sharing the receipt again.';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCall => 'Call';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonDate => 'Date';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonDone => 'Done';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonInStock => 'In Stock';

  @override
  String commonItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonLogin => 'Log In';

  @override
  String get commonLoginRequired => 'Please log in to continue';

  @override
  String get commonLogout => 'Log Out';

  @override
  String get commonMrp => 'MRP';

  @override
  String get commonNetworkError =>
      'Could not connect. Please check your internet and try again.';

  @override
  String get commonNext => 'Next';

  @override
  String get commonNo => 'No';

  @override
  String get commonNoDataFound => 'Nothing to show yet';

  @override
  String get commonOk => 'OK';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonOutOfStock => 'Out of Stock';

  @override
  String get commonPerUnit => '/unit';

  @override
  String commonPercentOff(String percent) {
    return '$percent% OFF';
  }

  @override
  String get commonPrice => 'Price';

  @override
  String commonPricePerUnit(String price) {
    return '₹$price/unit';
  }

  @override
  String commonProductsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String commonQtyValue(String quantity) {
    return 'Qty: $quantity';
  }

  @override
  String get commonQuantity => 'Quantity';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonRetry => 'Retry';

  @override
  String commonRupees(String amount) {
    return '₹$amount';
  }

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaveChanges => 'Save Changes';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSeeAll => 'See All';

  @override
  String get commonShare => 'Share';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonSomethingWentWrong =>
      'Something went wrong. Please try again.';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonStock => 'Stock';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonSubtotal => 'Subtotal';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String commonUnitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return '$_temp0';
  }

  @override
  String get commonView => 'View';

  @override
  String get commonViewAll => 'View All';

  @override
  String get commonViewDetails => 'View Details';

  @override
  String get commonYes => 'Yes';

  @override
  String get conversionAddressRequired => 'Address is required';

  @override
  String get conversionAlreadyAppliedBody =>
      'Your wholesaler application is currently under review by our team. We will notify you shortly once it has been processed.';

  @override
  String get conversionAlreadyAppliedTitle => 'Already Applied';

  @override
  String get conversionBusinessAddress => 'Business Address';

  @override
  String get conversionBusinessAddressHint => 'Enter full office address';

  @override
  String get conversionBusinessNameHint => 'Enter your company name';

  @override
  String get conversionBusinessNameRequired => 'Business name is required';

  @override
  String get conversionChange => 'Change';

  @override
  String get conversionContactPerson => 'Contact Person';

  @override
  String get conversionContactPersonHint => 'Full name';

  @override
  String get conversionContactPersonRequired =>
      'Contact person name is required';

  @override
  String get conversionGoBack => 'Go Back';

  @override
  String get conversionGstHint => 'Enter 15-digit GSTIN';

  @override
  String get conversionGstInvalid => 'Invalid GST number format';

  @override
  String get conversionGstNumber => 'GST Number';

  @override
  String get conversionHeaderSubtitle =>
      'Get access to exclusive bulk pricing, negotiation tools, and priority support.';

  @override
  String get conversionHeaderTitle => 'Wholesaler Account Application';

  @override
  String get conversionImageFormats => 'JPG, PNG, or similar image files';

  @override
  String conversionImagesSelected(int count) {
    return '$count/3 images selected';
  }

  @override
  String get conversionLoginFirst =>
      'Please login first, then submit your application.';

  @override
  String get conversionLoginRequiredBody =>
      'Please login to your account first, then submit your wholesaler application.';

  @override
  String get conversionLoginRequiredTitle => 'Login Required';

  @override
  String get conversionMaxProofImages =>
      'You can upload up to 3 proof images only.';

  @override
  String get conversionPhoneHint => 'Enter 10-digit mobile number';

  @override
  String get conversionPhoneInvalid => 'Enter a valid phone number';

  @override
  String get conversionPhoneRequired => 'Phone number is required';

  @override
  String get conversionPick => 'Pick';

  @override
  String get conversionPickLocationError =>
      'Please pick your shop location on the map.';

  @override
  String get conversionPickShopLocation => 'Pick shop location on map';

  @override
  String get conversionProofAdd => 'Add';

  @override
  String get conversionProofDescription =>
      'Upload shop photo, GST certificate, trade license, or any valid business proof.';

  @override
  String get conversionProofFull => 'Full';

  @override
  String get conversionProofImagesTrimmed =>
      'Only the first 3 proof images were added.';

  @override
  String get conversionProofLimit => '(Up to 3)';

  @override
  String get conversionProofTitle => 'Valid Image Proof';

  @override
  String get conversionRejectedNote =>
      'Your previous application was not approved. You can review your details and submit again.';

  @override
  String get conversionSectionBusiness => 'BUSINESS INFORMATION';

  @override
  String get conversionSectionContact => 'CONTACT INFORMATION';

  @override
  String get conversionShopLocation => 'Shop Location';

  @override
  String get conversionShopLocationDescription =>
      'Mark your shop on the map. You can use current location and then adjust the pin before saving it.';

  @override
  String get conversionShopLocationHint =>
      'Use current location or manually place a pin';

  @override
  String get conversionShopLocationSelected => 'Shop location selected';

  @override
  String get conversionStatusTitle => 'Application Status';

  @override
  String get conversionSubmit => 'Submit Application';

  @override
  String get conversionSubmitFailed =>
      'Failed to submit application. Please try again.';

  @override
  String get conversionSubmitted =>
      'Application submitted successfully! Our team will verify your details.';

  @override
  String get conversionTitle => 'Apply for wholesaler account';

  @override
  String get conversionUnexpectedError => 'An unexpected error occurred.';

  @override
  String get conversionUploadProof => 'Upload proof images';

  @override
  String get dealAcceptedByPlatform => 'Accepted by TradeHub Demo';

  @override
  String dealAcceptedByPlatformName(String name) {
    return 'Accepted by TradeHub Demo: $name';
  }

  @override
  String dealBulletTotal(String amount) {
    return '• Total: ₹$amount';
  }

  @override
  String get dealChatAndHistory => 'Chat & History';

  @override
  String get dealConfirmAndProceed => 'Confirm & Proceed';

  @override
  String get dealCreateOrderFailed => 'Failed to create order';

  @override
  String get dealCurrentPricePerUnit => 'Current Price/unit';

  @override
  String get dealDeclinedByPlatform => 'Declined by TradeHub Demo';

  @override
  String get dealEnterMessage => 'Please enter a message';

  @override
  String dealErrorWithDetails(String error) {
    return 'Error: $error';
  }

  @override
  String get dealFieldAddressLine1 => 'Address Line 1';

  @override
  String get dealFieldCouponCode => 'Coupon / Affiliate Code (Optional)';

  @override
  String get dealFieldFullName => 'Full Name';

  @override
  String get dealFieldPhone => 'Phone';

  @override
  String get dealPlatform => 'TradeHub Demo';

  @override
  String dealPlatformActor(String name) {
    return 'TradeHub Demo: $name';
  }

  @override
  String get dealLoadFailed => 'Failed to load';

  @override
  String dealLrLine(String tracking) {
    return 'LR: $tracking';
  }

  @override
  String dealLrLineWithCourier(String tracking, String courier) {
    return 'LR: $tracking · $courier';
  }

  @override
  String get dealMessageHint => 'Message';

  @override
  String get dealMessageSent => 'Message sent!';

  @override
  String dealMessageTooLong(String max) {
    return 'Message too long (max $max characters)';
  }

  @override
  String get dealOrderStatusCancelled => 'Cancelled';

  @override
  String get dealOrderStatusDelivered => 'Delivered';

  @override
  String get dealOrderStatusDispatched => 'Dispatched';

  @override
  String dealOrderStatusLine(String orderNumber, String status) {
    return 'Order $orderNumber · $status';
  }

  @override
  String get dealOrderStatusPacking => 'Packing';

  @override
  String get dealOrderStatusPaymentPending => 'Payment Pending';

  @override
  String get dealOrderStatusPaymentVerificationPending =>
      'Payment Verification Pending';

  @override
  String get dealOrderStatusPaymentVerified => 'Payment Verified';

  @override
  String get dealOrderTrackingNote =>
      'Live status from your order. Open full order for payment & dispatch details.';

  @override
  String get dealProductFallback => 'Product';

  @override
  String dealQtyUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return 'Qty: $_temp0';
  }

  @override
  String get dealReplyInChat => 'Reply in Chat';

  @override
  String dealRetailPrice(String price) {
    return 'Retail: ₹$price';
  }

  @override
  String get dealSendMessageFailed => 'Failed to send message';

  @override
  String get dealShippingAddressTitle => 'Shipping Address';

  @override
  String get dealStatusAccepted => 'Accepted';

  @override
  String get dealStatusNewPriceFromPlatform => 'New Price from TradeHub Demo';

  @override
  String get dealStatusNewPriceReceived => 'New Price Received';

  @override
  String get dealStatusRequirementDeclined => 'Requirement Declined';

  @override
  String get dealStatusRequirementExpired => 'Requirement Expired';

  @override
  String get dealStatusRequirementSent => 'Requirement Sent';

  @override
  String get dealStatusYourCounterOffer => 'Your Counter Offer';

  @override
  String dealTotalForUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return 'Total ($_temp0)';
  }

  @override
  String dealTyping(String name) {
    return '$name is typing...';
  }

  @override
  String get dealViewOrder => 'View Order';

  @override
  String dealViewOrderNumber(String orderNumber) {
    return 'View Order $orderNumber';
  }

  @override
  String get dealYou => 'You';

  @override
  String get dealYouAccepted => 'You Accepted';

  @override
  String get dealYouCancelled => 'You Cancelled';

  @override
  String get editProfileUpdateFailed => 'Failed to update profile';

  @override
  String get editProfileUpdated => 'Profile updated successfully';

  @override
  String get featuredEmpty => 'No products available';

  @override
  String get featuredHotDealsCustomer => 'Hot Deals';

  @override
  String get featuredHotDealsDealer => 'Dealer Schemes';

  @override
  String get featuredLoadError => 'Error loading products';

  @override
  String get featuredPopularCustomer => 'Popular Products';

  @override
  String get featuredPopularDealer => 'Fast-Moving Products';

  @override
  String get fieldAddressLine1 => 'Address Line 1';

  @override
  String get fieldBusinessName => 'Business Name';

  @override
  String get fieldCity => 'City';

  @override
  String get fieldEnterName => 'Please enter your name';

  @override
  String get fieldEnterPincode => 'Enter a pincode';

  @override
  String get fieldFullName => 'Full Name';

  @override
  String get fieldOptionalTag => '(Optional)';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get fieldPhoneNumber => 'Phone Number';

  @override
  String get fieldPincodeEditable => 'Pincode (editable)';

  @override
  String get fieldSelectCity => 'Select a city';

  @override
  String get fieldSelectState => 'Select a state';

  @override
  String get fieldState => 'State';

  @override
  String get guestPreviewSubtitle => 'You\'re seeing what customers see';

  @override
  String get guestPreviewTitle => 'Viewing as Customer';

  @override
  String get guideContactSupport => 'Contact Support';

  @override
  String get guideHeroSubtitle =>
      'Learn how to request and review bulk-price offers.';

  @override
  String get guideHeroTitle => 'Bulk Pricing Guide';

  @override
  String get guideHowItWorksBody =>
      'Use negotiations for bulk requirements when you want to discuss quantity, price, and delivery expectations with the seller.';

  @override
  String get guideHowItWorksTitle => 'How price negotiation works';

  @override
  String get guideStep1Body =>
      'Open an eligible product and submit your quantity, target price, and delivery requirements.';

  @override
  String get guideStep1Title => 'Request a bulk price';

  @override
  String get guideStep2Body =>
      'The seller may accept your request or send a counter-offer. Check the app for updates before confirming an order.';

  @override
  String get guideStep2Title => 'Review the seller response';

  @override
  String get guideStep3Body =>
      'After your order is created, share its receipt with the TradeHub Demo team so they can coordinate the next step.';

  @override
  String get guideStep3Title => 'Send your order receipt';

  @override
  String get guideStep4Body =>
      'Complete payment at the shop or using QR or bank details provided by the TradeHub Demo team. Your order status is updated after admin verification.';

  @override
  String get guideStep4Title => 'Pay through the TradeHub Demo team';

  @override
  String get guideTip =>
      'Include the quantity and your preferred delivery timeline in your request so the seller can provide a useful response.';

  @override
  String get guideTitle => 'Negotiation Guide';

  @override
  String get guideViewNegotiations => 'View Negotiations';

  @override
  String get helpAppTagline => 'Distribution made simple';

  @override
  String get helpBrandName => 'TradeHub Demo';

  @override
  String get helpCallUs => 'Call Us';

  @override
  String get helpContactInfoSubtitle => 'Get in touch with our support team';

  @override
  String get helpContactInfoTitle => 'Contact Information';

  @override
  String get helpEmailUs => 'Email Us';

  @override
  String get helpFaqBulkOrderAnswer =>
      'Navigate to the product page and tap \"Initiate Negotiation\" to start the bulk ordering process. You can request custom pricing for large quantities.';

  @override
  String get helpFaqBulkOrderQuestion => 'How do I place a bulk order?';

  @override
  String get helpFaqDeliveryAnswer =>
      'Delivery availability and timing depend on the product, order, and location. Contact support to confirm delivery arrangements for your order.';

  @override
  String get helpFaqDeliveryQuestion => 'How long does delivery take?';

  @override
  String get helpFaqNegotiationAnswer =>
      'Wholesalers can negotiate prices for bulk orders. Submit a negotiation request with your preferred price, and our team will review and respond with a counter-offer or acceptance.';

  @override
  String get helpFaqNegotiationQuestion => 'How do negotiations work?';

  @override
  String get helpFaqPaymentAnswer =>
      'Retail orders are reviewed in the app after submission. Once accepted, complete payment at the shop or use the QR code, UPI, or bank details shared by our team. Your order status updates after payment is confirmed.';

  @override
  String get helpFaqPaymentQuestion => 'What payment methods are accepted?';

  @override
  String get helpFaqReturnAnswer =>
      'Return availability depends on the product and order. Contact support so our team can review your request.';

  @override
  String get helpFaqReturnQuestion => 'What is the return policy?';

  @override
  String get helpFaqTitle => 'Frequently Asked Questions';

  @override
  String get helpFaqTrackAnswer =>
      'Go to the Orders section in your profile and tap on any order to view its available status updates.';

  @override
  String get helpFaqTrackQuestion => 'How do I track my order?';

  @override
  String get helpFaqWholesalerAnswer =>
      'Register with a wholesaler account and provide your business details. Once verified by our team, you\'ll get access to wholesale pricing and negotiations.';

  @override
  String get helpFaqWholesalerQuestion => 'How do I become a wholesaler?';

  @override
  String get helpHeroSubtitle =>
      'We\'re here to help with anything you need.\nReach out and we\'ll respond as soon as we can.';

  @override
  String get helpHeroTitle => 'How can we help you?';

  @override
  String get helpSupportTitle => 'Help & Support';

  @override
  String helpVersion(String version) {
    return 'Version $version';
  }

  @override
  String get helpVersionLabel => 'Version';

  @override
  String get helpWorkingHours => 'Working Hours';

  @override
  String get helpWorkingHoursValue => 'Mon - Sat, 9:00 AM - 6:00 PM';

  @override
  String get homeAdd => 'Add';

  @override
  String get homeAddShippingDetails => 'Add Shipping Details';

  @override
  String get homeAddedToCart => 'Added to cart';

  @override
  String get homeAffiliateCodeApplied => 'Affiliate code applied';

  @override
  String get homeAllOrders => 'All Orders';

  @override
  String get homeApplyCoupon => 'APPLY COUPON';

  @override
  String get homeBadgeHot => 'HOT';

  @override
  String get homeBadgeNew => 'NEW';

  @override
  String get homeBadgeSale => 'SALE';

  @override
  String get homeBannerExploreProducts => 'Explore Products';

  @override
  String get homeBannerNewArrival => 'NEW ARRIVAL';

  @override
  String get homeBannerShopNow => 'Shop Now';

  @override
  String get homeBrandFirstWord => 'TradeHub';

  @override
  String get homeBrandName => 'TradeHub Demo';

  @override
  String get homeBrandSecondWord => 'Demo';

  @override
  String get homeBrandTagline => 'Grow Together  •  Trade Better';

  @override
  String homeBrandValue(String brand) {
    return 'Brand: $brand';
  }

  @override
  String get homeBrowseCategories => 'Browse Categories';

  @override
  String get homeBrowseProducts => 'Browse Products';

  @override
  String get homeCartEmptySubtitle => 'Discover products and add them here';

  @override
  String get homeCartEmptyTitle => 'Your cart is empty';

  @override
  String get homeCatalogProducts => 'Catalog Products';

  @override
  String get homeCategoriesTitle => 'Categories';

  @override
  String homeCategoryValue(String category) {
    return 'Category: $category';
  }

  @override
  String get homeChangeCode => 'Change code';

  @override
  String get homeCheckoutFailed => 'Checkout failed';

  @override
  String get homeCheckoutLoginMessage =>
      'You can add products to cart and view them, but login is required to buy.';

  @override
  String get homeClearAll => 'CLEAR ALL';

  @override
  String get homeConfirmAndProceed => 'Confirm & Proceed';

  @override
  String get homeContinueDealChat => 'Continue Deal Chat';

  @override
  String get homeCountdownSoon => 'Soon';

  @override
  String get homeCounterLabel => 'Counter:';

  @override
  String get homeCouponAppliedAtCheckout =>
      'Applied successfully during checkout';

  @override
  String get homeCouponAppliedButton => 'Applied';

  @override
  String get homeCouponAppliedSuccess => 'Coupon applied successfully';

  @override
  String homeCouponCopied(String code) {
    return '$code copied! Use it in cart or find it in \"My Coupons\" in Profile.';
  }

  @override
  String get homeCouponFieldHint => 'Enter coupon or affiliate code';

  @override
  String get homeCouponFieldLabel => 'Coupon / Affiliate Code';

  @override
  String homeCouponWithCode(String code) {
    return 'Coupon ($code)';
  }

  @override
  String get homeCreateOrderFailed => 'Failed to create order';

  @override
  String get homeCreatingOrder => 'Creating Order...';

  @override
  String get homeCurrentLabel => 'Current:';

  @override
  String get homeDealDeskTitle => 'Deal Desk';

  @override
  String get homeDealEmptyActive => 'No active negotiations';

  @override
  String get homeDealEmptyCompleted => 'No completed negotiations';

  @override
  String get homeDealEmptyHint => 'Start negotiating on product pages';

  @override
  String get homeDealNewPriceReceived => 'New Price Received';

  @override
  String homeDealQtyTotal(String quantity, String amount) {
    return 'Qty $quantity · ₹$amount';
  }

  @override
  String get homeDealRequirementSent => 'Requirement Sent';

  @override
  String get homeDealStatusCountered => 'COUNTER-OFFER';

  @override
  String get homeDealStatusExpired => 'EXPIRED';

  @override
  String get homeDealStatusPending => 'PENDING';

  @override
  String get homeDealStatusRejected => 'REJECTED';

  @override
  String get homeDealTabActive => 'Active';

  @override
  String get homeDealTabCompleted => 'Completed';

  @override
  String get homeDelivery => 'Delivery';

  @override
  String homeDurationHours(String hours) {
    return '${hours}h';
  }

  @override
  String homeDurationHoursMinutes(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String homeDurationMinutes(String minutes) {
    return '${minutes}m';
  }

  @override
  String get homeEditProfile => 'Edit Profile';

  @override
  String homeErrorWithDetails(String error) {
    return 'Error: $error';
  }

  @override
  String get homeExclusiveOffers => 'Exclusive Offers';

  @override
  String get homeExitCustomerPreview => 'Exit Customer Preview';

  @override
  String get homeExpired => 'Expired';

  @override
  String get homeExploreTitle => 'Explore';

  @override
  String get homeFeaturedProducts => 'Featured Products';

  @override
  String get homeFieldAddressLine1 => 'Address Line 1';

  @override
  String get homeFieldCity => 'City';

  @override
  String get homeFieldFullName => 'Full Name';

  @override
  String get homeFieldPhone => 'Phone';

  @override
  String get homeFieldPincode => 'Pincode';

  @override
  String get homeFieldState => 'State';

  @override
  String get homeGuestPromptMessage =>
      'Please login or sign up to continue enjoying all features.';

  @override
  String get homeGuestPromptTitle => 'Login Required';

  @override
  String get homeGuestUser => 'Guest User';

  @override
  String get homeHotDealsCustomer => 'Hot Deals';

  @override
  String get homeHotDealsDealer => 'Dealer Schemes';

  @override
  String get homeHotDealsSubtitleCustomer => 'Limited-time savings';

  @override
  String get homeHotDealsSubtitleDealer => 'Bulk offers for your business';

  @override
  String get homeInvalidCoupon => 'Invalid coupon code';

  @override
  String get homeLoginOrSignUp => 'Login / Sign Up';

  @override
  String homeMinWholesaleQtyValue(String quantity) {
    return 'Min. wholesale quantity: $quantity';
  }

  @override
  String get homeMyCart => 'My Cart';

  @override
  String get homeMyOrders => 'My Orders';

  @override
  String get homeNavCart => 'Cart';

  @override
  String get homeNavCategories => 'Categories';

  @override
  String get homeNavDealDesk => 'Deal Desk';

  @override
  String get homeNavHome => 'Home';

  @override
  String get homeNavProfile => 'Profile';

  @override
  String get homeNavSearch => 'Search';

  @override
  String get homeNegotiationFallback => 'NEGOTIATION';

  @override
  String homeNewPriceEffectiveIn(String time) {
    return 'New price effective in $time';
  }

  @override
  String get homeNoBrandsAvailable => 'No brands available';

  @override
  String get homeNoBrandsFound => 'No brands found';

  @override
  String get homeNoCategoriesFound => 'No categories found';

  @override
  String get homeNoDate => 'No date';

  @override
  String get homeNoOpenDeals =>
      'No open deals — browse the catalogue to send your first requirement';

  @override
  String get homeNoProductsAvailable => 'No products available';

  @override
  String get homeNotNow => 'Not now';

  @override
  String get homeNotificationsEmptySubtitle => 'You\'re all caught up!';

  @override
  String get homeNotificationsEmptyTitle => 'No notifications yet';

  @override
  String get homeNotificationsMarkAllRead => 'Mark all read';

  @override
  String get homeNotificationsTitle => 'Notifications';

  @override
  String get homeNotificationsViewAll => 'View All Notifications';

  @override
  String get homeOfferApplyDuringCheckout => 'Apply during checkout';

  @override
  String homeOfferCode(String code) {
    return 'Code: $code';
  }

  @override
  String get homeOfferOff => 'OFF';

  @override
  String get homeOfferRuleFallback => 'Apply during checkout to unlock offer';

  @override
  String homeOfferRuleFlat(String value) {
    return 'Flat Rs $value off on eligible orders';
  }

  @override
  String homeOfferRulePercent(String value) {
    return 'Up to $value% off on selected products';
  }

  @override
  String get homeOrderFallback => 'Order';

  @override
  String homeOrderNumber(String number) {
    return 'Order $number';
  }

  @override
  String homeOrderNumberTotal(String number, String amount) {
    return 'Order $number · ₹$amount';
  }

  @override
  String homeOrderStageTotal(String stage, String amount) {
    return '$stage · ₹$amount';
  }

  @override
  String get homePartnershipsTitle =>
      'AUTHORIZED REPRESENTATIVE & PARTNERSHIPS';

  @override
  String get homePayableTotal => 'Payable Total';

  @override
  String get homePopularProductsCustomer => 'Popular Products';

  @override
  String get homePopularProductsDealer => 'Fast-Moving Products';

  @override
  String get homePopularSubtitleCustomer => 'Loved by buyers';

  @override
  String get homePopularSubtitleDealer => 'Popular dealer picks';

  @override
  String get homePreviewAddToCartDisabled =>
      'Add to Cart disabled in preview mode';

  @override
  String get homePreviewCartMessage =>
      'Shopping is disabled in preview mode. Your wholesaler cart remains unchanged.';

  @override
  String get homePreviewCartTitle => 'Customer cart preview';

  @override
  String get homePreviewCheckoutDisabled => 'Checkout disabled in preview mode';

  @override
  String get homePreviewFeatureDisabled =>
      'This feature is disabled while viewing the customer experience. Exit preview mode to return to your wholesaler account.';

  @override
  String get homePreviewGuestCustomer => 'Guest Customer';

  @override
  String get homePreviewNotificationsHidden =>
      'Notifications hidden in preview mode';

  @override
  String get homePreviewOffersReadOnly =>
      'Offers are read-only in preview mode';

  @override
  String get homePreviewProfileMessage =>
      'This read-only profile shows the guest customer experience without exposing or changing your wholesaler account.';

  @override
  String get homePreviewWishlistDisabled => 'Wishlist disabled in preview mode';

  @override
  String get homePriceApplyingSoon => 'Applying soon';

  @override
  String get homeProceedToCheckout => 'Proceed to Checkout';

  @override
  String get homeProceedToOrder => 'Proceed to Order';

  @override
  String get homeProfileAbout => 'About';

  @override
  String get homeProfileAccountPrivacy => 'Account & Privacy';

  @override
  String get homeProfileAddresses => 'Addresses';

  @override
  String get homeProfileApplyWholesaler => 'Apply for wholesaler account';

  @override
  String get homeProfileApplyWholesalerSubtitle =>
      'Unlock bulk pricing & deals';

  @override
  String get homeProfileHelpSupport => 'Help & Support';

  @override
  String get homeProfileLegalPolicies => 'Legal & Policies';

  @override
  String get homeProfileMyCoupons => 'My Coupon & Offer Code';

  @override
  String get homeProfileTitle => 'Profile';

  @override
  String get homeProfileViewCustomerApp => 'View Customer App';

  @override
  String get homeProfileViewCustomerAppSubtitle => 'See what customers see';

  @override
  String homeQtyUnits(String quantity) {
    return 'Qty: $quantity units';
  }

  @override
  String get homeRecentSearches => 'Recent Searches';

  @override
  String get homeRejected => 'Rejected';

  @override
  String get homeRepeatButton => 'Repeat';

  @override
  String get homeRepeatFailed => 'Could not repeat requirement';

  @override
  String homeRepeatItemQty(String name, String quantity) {
    return '$name × $quantity';
  }

  @override
  String get homeRepeatProductUnavailable => 'Product unavailable for repeat';

  @override
  String get homeRepeatRequirement => 'Repeat Requirement';

  @override
  String get homeRequirementFallback => 'Requirement';

  @override
  String get homeRespondToCounter => 'Respond to Counter';

  @override
  String get homeReviewsEyebrow => 'Voices of Trust';

  @override
  String get homeReviewsTitle => 'What Our Customers Say';

  @override
  String get homeSampleReview1Name => 'Rajesh Kumar';

  @override
  String get homeSampleReview1Role => 'Retail Buyer, Sample City';

  @override
  String get homeSampleReview1Text =>
      'TradeHub Demo has completely changed how I source my stock. The bulk pricing and quality are unbeatable.';

  @override
  String get homeSampleReview2Name => 'Priya Sharma';

  @override
  String get homeSampleReview2Role => 'Retailer, Demo State';

  @override
  String get homeSampleReview2Text =>
      'As a retailer, I need reliable delivery and authentic brands. The service on TradeHub Demo is a lifesaver for my business.';

  @override
  String get homeSampleReview3Name => 'Amit Patel';

  @override
  String get homeSampleReview3Role => 'Wholesale Distributor, Gujarat';

  @override
  String get homeSampleReview3Text =>
      'I\'ve been using TradeHub Demo for a year now. It has greatly simplified how I manage large orders and track inventory.';

  @override
  String get homeSampleReview4Name => 'Anjali Singh';

  @override
  String get homeSampleReview4Role => 'Store Owner, Sample City';

  @override
  String get homeSampleReview4Text =>
      'The variety of products on TradeHub Demo is impressive. Truly a one-stop shop for wholesale buying.';

  @override
  String get homeSaveAddress => 'Save Address';

  @override
  String get homeScheduled => 'Scheduled';

  @override
  String get homeSearchFilterTooltip => 'Search filter';

  @override
  String get homeSearchHint => 'Search products, brands, categories...';

  @override
  String get homeSearchLoadFailed =>
      'Unable to load products. Please try again.';

  @override
  String get homeSearchLoadMoreFailed => 'Could not load more products.';

  @override
  String get homeSearchNoResults => 'No results found';

  @override
  String get homeSearchScopeBrand => 'Brand';

  @override
  String get homeSearchScopeCategory => 'Category';

  @override
  String get homeSearchScopeProduct => 'Product';

  @override
  String get homeSearchTryChangingFilters => 'Try changing your filters';

  @override
  String get homeShippingAddress => 'Shipping Address';

  @override
  String get homeSignInToSync => 'Sign in to sync data';

  @override
  String homeSoldIn24Hrs(String count) {
    return '$count sold in 24hrs';
  }

  @override
  String get homeStageCancelled => 'Cancelled';

  @override
  String get homeStageDelivered => 'Delivered';

  @override
  String get homeStageDispatched => 'Dispatched';

  @override
  String get homeStagePacking => 'Packing';

  @override
  String get homeStagePaymentPending => 'Payment Pending';

  @override
  String get homeStagePaymentVerified => 'Payment Verified';

  @override
  String get homeStageVerificationPending => 'Verification Pending';

  @override
  String get homeStockIssueFallback => 'Stock issue';

  @override
  String get homeStockIssuesTitle => 'Cannot proceed — stock issues:';

  @override
  String get homeTapApplyCoupon => 'Tap Apply to use this coupon';

  @override
  String homeTimeDaysAgo(String days) {
    return '${days}d ago';
  }

  @override
  String homeTimeHoursAgo(String hours) {
    return '${hours}h ago';
  }

  @override
  String get homeTimeJustNow => 'Just now';

  @override
  String get homeTimeLeft => 'LEFT';

  @override
  String homeTimeMinutesAgo(String minutes) {
    return '${minutes}m ago';
  }

  @override
  String get homeTopBrands => 'Top Brands';

  @override
  String get homeTotalLabel => 'Total:';

  @override
  String get homeTrackActiveOrders => 'Track Active Orders';

  @override
  String get homeTrustBulkSale => 'Bulk Sale Active';

  @override
  String get homeTrustCertifiedProducts => 'Certified Products';

  @override
  String get homeTrustExpertSupport => '24/7 Expert Support';

  @override
  String get homeTrustPanIndiaDelivery => 'Pan-India Delivery';

  @override
  String get homeTryDifferentSearch => 'Try a different search term';

  @override
  String get homeUnderReview => 'Under Review';

  @override
  String get homeUnknownProduct => 'Unknown Product';

  @override
  String get homeViewDeals => 'View Deals';

  @override
  String get homeWhyBuyDeliverySubtitle => 'Pan-India shipping';

  @override
  String get homeWhyBuyDeliveryTitle => 'Fast Delivery';

  @override
  String get homeWhyBuyPricingSubtitle => 'Best wholesale rates';

  @override
  String get homeWhyBuyPricingTitle => 'Bulk Pricing';

  @override
  String get homeWhyBuyQualitySubtitle => 'Certified products';

  @override
  String get homeWhyBuyQualityTitle => 'Premium Quality';

  @override
  String get homeWhyBuySupportSubtitle => 'Always here to help';

  @override
  String get homeWhyBuySupportTitle => '24/7 Support';

  @override
  String get homeWhyBuyTitle => 'Why Buy From Us?';

  @override
  String get homeWishlistCustomer => 'Wishlist';

  @override
  String get homeWishlistDealer => 'Regular Items';

  @override
  String get homeYourPriceLabel => 'Your Price:';

  @override
  String get languageChanged => 'Language changed to English';

  @override
  String get languageChooseSubtitle =>
      'You can change this anytime from your profile.';

  @override
  String get languageChooseTitle => 'Choose your language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get languageTitle => 'Language';

  @override
  String get legalCancellationPolicy => 'Cancellation Policy';

  @override
  String get legalCodDeliveryPolicy => 'COD Delivery Policy';

  @override
  String get legalComprehensivePolicies => 'Comprehensive Legal Policies';

  @override
  String get legalDealerAgreement => 'Dealer Agreement';

  @override
  String get legalDealerPricingPolicy => 'Dealer Pricing Policy';

  @override
  String get legalEnglishOnlyNote => 'This policy is available in English.';

  @override
  String get legalHubTitle => 'Legal & Policies';

  @override
  String get legalLoadFailed => 'Unable to load policy content.';

  @override
  String get legalNotFound => 'Policy not found.';

  @override
  String get legalPolicyBadge => 'Policy';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalRefundReturnPolicy => 'Refund & Return Policy';

  @override
  String get legalShippingPolicy => 'Shipping Policy';

  @override
  String get legalTermsConditions => 'Terms & Conditions';

  @override
  String get legalWarrantyPolicy => 'Warranty Policy';

  @override
  String get localNotificationBrand => 'TradeHub Demo';

  @override
  String get localNotificationCountdownChannel =>
      'Price Countdown Notifications';

  @override
  String get localNotificationCountdownChannelDescription =>
      'Live countdown notifications for scheduled price updates';

  @override
  String get localNotificationGeneralChannel => 'General Notifications';

  @override
  String get localNotificationGeneralChannelDescription =>
      'General notifications for TradeHub Demo';

  @override
  String get localNotificationPriceUpdateActive =>
      'A scheduled price update is active.';

  @override
  String get localNotificationPriceUpdateScheduled => 'Price update scheduled';

  @override
  String get localNotificationPricesApplied => 'New prices are now applied.';

  @override
  String get localNotificationShopNow => 'Shop Now';

  @override
  String get negotiationCompleted => 'Negotiation Completed';

  @override
  String get negotiationTitleFallback => 'Negotiation';

  @override
  String get negotiationsCurrentLabel => 'Current:';

  @override
  String get negotiationsEmptyActive => 'No active negotiations';

  @override
  String get negotiationsEmptyCompleted => 'No completed negotiations';

  @override
  String get negotiationsEmptyHint => 'Start negotiating on product pages';

  @override
  String get negotiationsLoadFailed => 'Failed to load negotiations';

  @override
  String get negotiationsNewPriceFromPlatformLabel =>
      'New Price from TradeHub Demo:';

  @override
  String get negotiationsNoDate => 'No date';

  @override
  String get negotiationsNumberFallback => 'NEGOTIATION';

  @override
  String get negotiationsTabActive => 'Active';

  @override
  String get negotiationsTabCompleted => 'Completed';

  @override
  String get negotiationsTitle => 'Negotiations';

  @override
  String get negotiationsTotalLabel => 'Total:';

  @override
  String get negotiationsUnknownProduct => 'Unknown Product';

  @override
  String get negotiationsYourExpectedPrice => 'Your Expected Price:';

  @override
  String notificationsDaysAgo(String count) {
    return '${count}d ago';
  }

  @override
  String get notificationsEmptySubtitle =>
      'You\'ll see your notifications here';

  @override
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String notificationsHoursAgo(String count) {
    return '${count}h ago';
  }

  @override
  String get notificationsJustNow => 'Just now';

  @override
  String notificationsMinutesAgo(String count) {
    return '${count}m ago';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get onboardingEnableNotifications => 'Enable Notifications';

  @override
  String get onboardingNotNow => 'Not now';

  @override
  String get onboardingNotificationsBody =>
      'Receive alerts when your order or payment status changes and when price updates are scheduled.';

  @override
  String get onboardingNotificationsTitle => 'Notifications';

  @override
  String get onboardingOtherPermissionsNote =>
      'Location and photo access are requested only when you choose a current shop location or upload an image.';

  @override
  String get onboardingSubtitle =>
      'Choose whether you would like order, payment, and price-update notifications. You can change this later in device settings.';

  @override
  String get onboardingTitle => 'Stay updated';

  @override
  String get orderIdLabel => 'Order ID';

  @override
  String orderNumberLabel(String orderNumber) {
    return 'Order $orderNumber';
  }

  @override
  String get orderSuccessDeliveryNote =>
      'Contact TradeHub Demo to confirm arrangements';

  @override
  String get orderSuccessMessage =>
      'Your order has been placed successfully.\nWe\'ll notify you once it\'s shipped.';

  @override
  String get orderSuccessPaymentPending => 'Payment Verification Pending';

  @override
  String get orderSuccessTitle => 'Order Confirmed!';

  @override
  String ordersCardSubtitle(String orderType, String date) {
    return '$orderType · $date';
  }

  @override
  String ordersCardSubtitleNegotiated(String orderType, String date) {
    return '$orderType · Negotiated price · $date';
  }

  @override
  String ordersCourierValue(String courier) {
    return 'Courier: $courier';
  }

  @override
  String get ordersDelivery => 'Delivery';

  @override
  String get ordersDeliveryDetails => 'Delivery Details';

  @override
  String get ordersEmpty => 'No orders yet';

  @override
  String get ordersFree => 'Free';

  @override
  String ordersItemQtyPrice(String quantity, String price) {
    return 'Qty: $quantity × ₹$price';
  }

  @override
  String get ordersLoadFailed => 'Failed to load orders';

  @override
  String ordersMrpValue(String price) {
    return 'MRP ₹$price';
  }

  @override
  String get ordersNegotiatedChip => 'Negotiated';

  @override
  String get ordersProductFallback => 'Product';

  @override
  String get ordersRejectedNoReason =>
      'This order was not approved. Contact support if you need more information.';

  @override
  String get ordersRejectedTitle => 'Order Rejected';

  @override
  String get ordersSendReceipt => 'Send Receipt';

  @override
  String get ordersStartShopping => 'Start Shopping';

  @override
  String get ordersStatusHistory => 'Status History';

  @override
  String get ordersTitle => 'My Orders';

  @override
  String get ordersTrackOrder => 'Track Order';

  @override
  String ordersTrackingValue(String trackingNumber) {
    return 'Tracking: $trackingNumber';
  }

  @override
  String get ordersTypeRetail => 'Retail order';

  @override
  String get ordersTypeWholesale => 'Wholesale order';

  @override
  String get ordersViewStatus => 'View Status';

  @override
  String priceNoticeChangeIn(
    String currentPrice,
    String newPrice,
    String time,
  ) {
    return '₹$currentPrice → ₹$newPrice in $time';
  }

  @override
  String get priceNoticeChangesSoon => 'Price changes soon';

  @override
  String priceNoticeDurationDaysHours(String days, String hours) {
    return '${days}d ${hours}h';
  }

  @override
  String priceNoticeDurationHoursMinutes(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String priceNoticeDurationMinutesSeconds(String minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String priceNoticeTimeLeft(String time) {
    return 'Time left: $time';
  }

  @override
  String get priceNoticeUpcomingChange => 'Upcoming price change';

  @override
  String get privacyAfterDeletionBody =>
      'Your account access is revoked. Profile details, saved addresses, uploaded account media, carts, notification tokens, notification history, and negotiations are deleted or anonymized. Orders and payment records are kept in restricted records for the applicable legal retention period. Backup handling follows our applicable operational and legal retention requirements.';

  @override
  String get privacyAfterDeletionTitle =>
      'What happens when deletion is completed';

  @override
  String get privacyCancelFailed => 'Unable to cancel deletion request.';

  @override
  String get privacyCancelPending => 'Cancel pending request';

  @override
  String privacyCompleteBy(String date) {
    return 'Complete by: $date';
  }

  @override
  String privacyCompletedOn(String date) {
    return 'Completed on: $date';
  }

  @override
  String privacyControlsBody(String url) {
    return 'Manage your account-deletion request here. You can also submit a request after uninstalling the app at $url.';
  }

  @override
  String get privacyControlsTitle => 'Your privacy controls';

  @override
  String get privacyDialogBody =>
      'We will process your request within 30 days. Direct account data, uploaded business documents, saved addresses, carts, device tokens, and notifications will be removed or anonymized. Financial records may be retained where required for tax, payment, fraud-prevention, dispute, or warranty obligations. Backup handling follows our applicable operational and legal retention requirements.';

  @override
  String get privacyDialogTitle => 'Request account deletion?';

  @override
  String get privacyKeepAccount => 'Keep account';

  @override
  String get privacyRequestBody =>
      'After Member verification, we complete deletion within 30 days. Restricted financial records may be retained only for legal, tax, payment, fraud-prevention, dispute, or warranty obligations.';

  @override
  String get privacyRequestButton => 'Request account deletion';

  @override
  String get privacyRequestDeletion => 'Request deletion';

  @override
  String get privacyRequestHeading => 'Request account deletion';

  @override
  String get privacyStatusCompleted => 'Completed';

  @override
  String get privacyStatusReceived => 'Request received';

  @override
  String get privacyStatusUnderReview => 'Under review';

  @override
  String get privacySubmitFailed => 'Unable to submit deletion request.';

  @override
  String get privacyTitle => 'Account & Privacy';

  @override
  String get productAddShort => 'Add';

  @override
  String get productAddToCart => 'Add to Cart';

  @override
  String get productAddToCartDisabledPreview =>
      'Add to Cart disabled in preview mode';

  @override
  String get productAddedToCart => 'Added to cart';

  @override
  String get productBadgeHot => 'HOT';

  @override
  String get productBadgeNew => 'NEW';

  @override
  String get productBadgeSale => 'SALE';

  @override
  String get productBrandFallback => 'TradeHub Demo';

  @override
  String productBrandValue(String brand) {
    return 'Brand: $brand';
  }

  @override
  String get productBulkNegotiation => 'Bulk Negotiation';

  @override
  String get productBulkNegotiationSubtitle =>
      'Get wholesale pricing for custom bulk orders';

  @override
  String get productBulkOrder => 'Bulk Order';

  @override
  String get productBulkQuantityNegotiation => 'Bulk Quantity Negotiation';

  @override
  String get productBulkQuantityNegotiationBody =>
      'Want to deal in more quantity? Send us your requirement and we\'ll get back to you with the best price.';

  @override
  String get productBulkUpiNote =>
      'Bulk orders require manual UPI verification before processing.';

  @override
  String get productBuyNow => 'Buy Now';

  @override
  String get productBuyNowDisabledPreview => 'Buy Now disabled in preview mode';

  @override
  String get productChooseVariantHint => 'Choose size or pack option';

  @override
  String get productConfirmBeforeSubmit => 'Confirm details before submitting';

  @override
  String get productContinueToPricing => 'Continue to Pricing';

  @override
  String get productCustomQuantity => 'Custom quantity';

  @override
  String get productDeliveryWithin5Days => 'Delivery within 5 days of Purchase';

  @override
  String get productDemoVideo => 'Product Demo';

  @override
  String get productDescription => 'Description';

  @override
  String get productEnterQuantity => 'Please enter quantity';

  @override
  String get productExpectedQuantity => 'Expected Quantity';

  @override
  String get productExpectedQuantityHint => 'e.g. 100 units';

  @override
  String get productGallery => 'Product Gallery';

  @override
  String get productGuestModeDisabledMessage =>
      'This feature is disabled while viewing the customer experience. Exit preview mode to return to your wholesaler account.';

  @override
  String get productHowManyUnits => 'How many units?';

  @override
  String get productHowManyUnitsSubtitle =>
      'Select quantity for your bulk quote';

  @override
  String get productInclTaxes => 'Incl. taxes';

  @override
  String get productLoadFailed => 'Failed to load product details';

  @override
  String get productLoading => 'Loading product...';

  @override
  String productMinWholesaleQuantity(String quantity) {
    return 'Minimum wholesale quantity: $quantity';
  }

  @override
  String get productMrpLabel => 'MRP: ';

  @override
  String get productNegotiationSubmitFailed => 'Failed to submit negotiation';

  @override
  String get productNoDescription =>
      'No description available for this product.';

  @override
  String get productNotFound => 'Product not found';

  @override
  String get productOnlyPlatformCanConfirm =>
      'Only TradeHub Demo can confirm the deal';

  @override
  String get productPlaceholderControlPanel => 'Control Panel';

  @override
  String get productPlaceholderDrone => 'Agri Drone';

  @override
  String get productPlaceholderFarmTool => 'Farm Tool';

  @override
  String get productPlaceholderFencing => 'Fencing';

  @override
  String get productPlaceholderFertilizer => 'Fertilizer';

  @override
  String get productPlaceholderGiFitting => 'GI Fitting';

  @override
  String get productPlaceholderHarvester => 'Harvester';

  @override
  String get productPlaceholderIrrigation => 'Irrigation';

  @override
  String get productPlaceholderPesticide => 'Pesticide';

  @override
  String get productPlaceholderPipe => 'Pipe';

  @override
  String get productPlaceholderProduct => 'Product';

  @override
  String get productPlaceholderPumpSet => 'Pump Set';

  @override
  String get productPlaceholderRiceMill => 'Rice Mill';

  @override
  String get productPlaceholderSeeds => 'Seeds';

  @override
  String get productPlaceholderStarterOil => 'Starter & Oil';

  @override
  String get productPlaceholderTestingKit => 'Testing Kit';

  @override
  String get productPlaceholderTractor => 'Tractor';

  @override
  String get productPlaceholderWireCable => 'Wire & Cable';

  @override
  String productPriceWithUnit(String price, String unit) {
    return '₹$price/$unit';
  }

  @override
  String productQtyRetailSummary(int count, String price) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return '$_temp0 · Retail: ₹$price/unit';
  }

  @override
  String get productQuickSelect => 'QUICK SELECT';

  @override
  String productQuotationSubmitted(int count, String number) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return 'Quotation $number submitted for $_temp0!';
  }

  @override
  String get productReadMore => 'Read more';

  @override
  String get productRelatedProducts => 'Related Products';

  @override
  String get productRequirementDetails => 'Requirement Details';

  @override
  String get productRequirementDetailsHint =>
      'Tell us about your requirement or target price...';

  @override
  String get productRetailPrice => 'Retail Price';

  @override
  String get productReviewProduct => 'Product';

  @override
  String get productReviewRequirement => 'Review Requirement';

  @override
  String productSaveAmount(String amount, String percent, String quantity) {
    return 'Save ₹$amount total ($percent% off × $quantity units)';
  }

  @override
  String get productSelectQuantity => 'Select Quantity:';

  @override
  String get productSelectVariant => 'Select Variant';

  @override
  String get productSendRequirement => 'Send Requirement';

  @override
  String get productSendToDealDesk => 'Send to Deal Desk';

  @override
  String productShareText(String name, String url) {
    return 'Check out $name on TradeHub Demo!\n\n$url';
  }

  @override
  String productShareTextWithPrice(String name, String price, String url) {
    return 'Check out $name - ₹$price on TradeHub Demo!\n\n$url';
  }

  @override
  String get productShippingReturns => 'Shipping & Returns';

  @override
  String get productShippingTermsDefault =>
      'Delivery, payment, and return arrangements depend on the product, order, and location. Contact TradeHub Demo to confirm the applicable terms before payment or dispatch.';

  @override
  String get productShowLess => 'Show less';

  @override
  String productSkuValue(String sku) {
    return 'SKU: $sku';
  }

  @override
  String productSoldLast24h(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return '$_temp0 sold in the last 24 hours';
  }

  @override
  String productSomethingWentWrongDetail(String error) {
    return 'Something went wrong: $error';
  }

  @override
  String get productSpecialPriceLabel => 'Special Price: ';

  @override
  String get productSpecifications => 'Specifications';

  @override
  String get productSubmitQuote => 'Submit Quote';

  @override
  String get productSuggestedSellingPriceLabel => 'Suggested Selling Price: ';

  @override
  String get productTapToSelect => 'Tap to select';

  @override
  String get productTargetPricePerUnit => 'TARGET PRICE PER UNIT';

  @override
  String get productTrustEasyReturns => 'Easy Returns';

  @override
  String get productTrustFastDelivery => 'Fast Delivery';

  @override
  String get productTrustReviews => 'Trusted Reviews';

  @override
  String get productTrustSecurePayments => 'Secure Payments';

  @override
  String get productTrustSupport => 'Guaranteed Support';

  @override
  String get productTrustVerifiedProducts => 'Verified Products';

  @override
  String get productUnitMeter => 'Meter';

  @override
  String get productUnitPacket => 'Packet';

  @override
  String get productUnitPiece => 'Piece';

  @override
  String get productVariantFallback => 'Variant';

  @override
  String get productVerifiedSeller => 'Verified Seller';

  @override
  String get productViewAllSpecifications => 'View all specifications';

  @override
  String get productWholesaleLabel => 'Wholesale: ';

  @override
  String get productWishlistDisabledPreview =>
      'Wishlist disabled in preview mode';

  @override
  String productYouSaveVsRetail(String amount) {
    return 'You save ₹$amount vs retail';
  }

  @override
  String get productYourDealerPriceLabel => 'Your Dealer Price: ';

  @override
  String get productYourExpectedPrice => 'Your Expected Price';

  @override
  String get profileAccountFallback => 'Account';

  @override
  String get profileAddProduct => 'Add Product';

  @override
  String get profileAddProductSubtitle => 'Create a product listing';

  @override
  String get profileAddresses => 'Addresses';

  @override
  String get profileAddressesSubtitle => 'Manage delivery addresses';

  @override
  String get profileBecomeWholesaler => 'Become a Wholesaler';

  @override
  String get profileCompleteWholesalerVerification =>
      'Complete Wholesaler Verification';

  @override
  String get profileEditProfile => 'Edit Profile';

  @override
  String get profileEditProfileSubtitle => 'Update your account information';

  @override
  String get profileHelpSupport => 'Help & Support';

  @override
  String get profileHelpSupportSubtitle => 'FAQs and contact information';

  @override
  String get profileNegotiations => 'Negotiations';

  @override
  String get profileNegotiationsSubtitle => 'View your price negotiations';

  @override
  String get profilePreviousOrders => 'Previous Orders';

  @override
  String get profilePreviousOrdersSubtitle => 'View order history and status';

  @override
  String get profilePrivacySubtitle => 'How we collect and use data';

  @override
  String get profileSectionAccount => 'ACCOUNT';

  @override
  String get profileSectionActivity => 'ACTIVITY';

  @override
  String get profileSectionSupportLegal => 'SUPPORT & LEGAL';

  @override
  String get profileSectionWholesale => 'WHOLESALE';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignOutSubtitle => 'Log out of your account';

  @override
  String get profileStatusApplicationPending =>
      'Wholesaler application pending';

  @override
  String get profileStatusApplicationRejected =>
      'Wholesaler application needs attention';

  @override
  String get profileStatusCustomer => 'Customer account';

  @override
  String get profileStatusVerificationRequired =>
      'Wholesaler verification required';

  @override
  String get profileStatusVerifiedWholesaler => 'Verified wholesaler';

  @override
  String get profileSubmitBusinessDetails =>
      'Submit business details for verification';

  @override
  String get profileSubmitBusinessProof =>
      'Submit business proof for admin review';

  @override
  String get profileTermsSubtitle => 'Terms of use';

  @override
  String get profileTitle => 'My Account';

  @override
  String get profileViewApplicationStatus => 'View your application status';

  @override
  String get profileViewCustomerApp => 'View Customer App';

  @override
  String get profileViewCustomerAppSubtitle => 'See what customers see';

  @override
  String get profileWholesalerApplication => 'Wholesaler Application';

  @override
  String get shopLocationConfirm => 'Use This Shop Location';

  @override
  String get shopLocationFailed =>
      'Could not get your current location. Please try again.';

  @override
  String get shopLocationHint =>
      'Tap anywhere on the map to place your shop, or use your current location and adjust it.';

  @override
  String get shopLocationLocating => 'Locating';

  @override
  String get shopLocationPermissionDenied => 'Location permission denied';

  @override
  String get shopLocationSelectedCoordinates => 'Selected Coordinates';

  @override
  String get shopLocationServicesOff => 'Location services are turned off';

  @override
  String get shopLocationTitle => 'Pick Shop Location';

  @override
  String get shopLocationUseCurrent => 'Use Current';

  @override
  String get splashTagline => 'Distribution made simple';

  @override
  String get statusAcceptedAwaitingPayment => 'Accepted · Awaiting Payment';

  @override
  String get statusAwaitingAcceptance => 'Submitted · Awaiting Approval';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusDealAcceptedOrderPending => 'Accepted · Order Pending';

  @override
  String get statusDealOrderCreated => 'Order Created';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusPaymentUploaded => 'Awaiting Shop Confirmation';

  @override
  String get statusPaymentVerified => 'Payment Confirmed';

  @override
  String get statusPendingPayment => 'Awaiting Payment Confirmation';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusRejected => 'Order Rejected';

  @override
  String get statusShipped => 'Shipped';

  @override
  String get trackingContactSupport =>
      'Contact support if you need more information.';

  @override
  String get trackingCourier => 'Courier';

  @override
  String get trackingCourierInfo => 'Courier Information';

  @override
  String get trackingDeliveredDate => 'Delivered Date';

  @override
  String get trackingInvalidOrder =>
      'This notification does not contain a valid order.';

  @override
  String trackingItemQtyTotal(String quantity, String amount) {
    return 'Qty: $quantity • ₹$amount';
  }

  @override
  String get trackingLatestBadge => 'LATEST';

  @override
  String get trackingLoadFailed =>
      'Could not load order details. Please try again.';

  @override
  String trackingMoreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more items',
      one: '+1 more item',
    );
    return '$_temp0';
  }

  @override
  String get trackingNotApproved => 'Order not approved';

  @override
  String get trackingNumberLabel => 'Tracking Number';

  @override
  String get trackingOrderGone => 'This order is no longer available.';

  @override
  String get trackingOrderJourney => 'Order Journey';

  @override
  String get trackingOrderNotFound => 'Order not found';

  @override
  String get trackingShippedDate => 'Shipped Date';

  @override
  String get trackingSignInToView => 'Please sign in to view this order.';

  @override
  String get trackingTitle => 'Shipment Details';

  @override
  String get trackingUnavailable => 'Order details are unavailable.';

  @override
  String get trackingViewPreviousOrders => 'View Previous Orders';

  @override
  String get updateCurrentVersion => 'Current';

  @override
  String get updateLatestVersion => 'Latest';

  @override
  String get updateNow => 'Update Now';

  @override
  String get updateOpeningStore => 'Opening Store...';

  @override
  String get updateStoreOpenFailed =>
      'Unable to open the app store. Check your connection and try again.';

  @override
  String get wishlistClearAll => 'Clear All';

  @override
  String get wishlistClearMessage => 'Remove all items from your wishlist?';

  @override
  String get wishlistClearTitle => 'Clear Wishlist?';

  @override
  String get wishlistEmptySubtitle =>
      'Save items you love by tapping the\nheart icon on product pages';

  @override
  String get wishlistEmptyTitle => 'Your wishlist is empty';

  @override
  String get wishlistSwipeToRemove => 'Swipe left on an item to remove it';

  @override
  String get wishlistTitle => 'My Wishlist';

  @override
  String get productRequirementMessageLabel =>
      'MESSAGE / DELIVERY REQUIREMENT (OPTIONAL)';

  @override
  String get productRequirementMessageHint =>
      'e.g. preferred delivery date, packaging or site details';

  @override
  String get productRequirementMessageReview => 'Message';

  @override
  String get negotiationBuyerMessage => 'Message';
}
