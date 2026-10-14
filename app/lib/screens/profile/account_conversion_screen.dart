import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config/brand_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/user_model.dart';
import 'shop_location_picker_screen.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

/// GSTIN: 2-digit state code, PAN (5 letters, 4 digits, 1 letter), entity
/// number, "Z", check character.
final RegExp _gstinPattern = RegExp(
  r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
);

class AccountConversionScreen extends ConsumerStatefulWidget {
  const AccountConversionScreen({super.key});

  @override
  ConsumerState<AccountConversionScreen> createState() =>
      _AccountConversionScreenState();
}

class _AccountConversionScreenState
    extends ConsumerState<AccountConversionScreen> {
  static const int _stepCount = 3;

  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  String? _errorMessage;
  final List<XFile> _proofImages = [];
  ShopLocation? _shopLocation;

  /// 0 Business, 1 Shop location, 2 Proof photos.
  int _step = 0;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _businessNameController.text = user.businessInfo?.businessName ?? '';
      _gstNumberController.text = (user.businessInfo?.gstNumber ?? '')
          .toUpperCase();
      _businessAddressController.text =
          user.businessInfo?.businessAddress ?? user.address ?? '';
      _contactPersonController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _shopLocation = user.businessInfo?.shopLocation;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _gstNumberController.dispose();
    _businessAddressController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitConversion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_shopLocation == null) {
      setState(() {
        _errorMessage = context.l10n.conversionPickLocationError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final gstNumber = _gstNumberController.text.trim();
      final formData = FormData.fromMap({
        'businessName': _businessNameController.text.trim(),
        if (gstNumber.isNotEmpty) 'gstNumber': gstNumber,
        'businessAddress': _businessAddressController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'phone': _phoneController.text.trim(),
        'shopLocationLat': _shopLocation!.lat,
        'shopLocationLng': _shopLocation!.lng,
        'shopLocationLabel': _businessAddressController.text.trim(),
        if (_proofImages.isNotEmpty)
          'proofImages': await Future.wait(
            _proofImages.map(
              (image) =>
                  MultipartFile.fromFile(image.path, filename: image.name),
            ),
          ),
      });

      final response = await apiClient.post(
        '/auth/convert-to-wholesaler',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final userData = response.data['data'];
        final newUser = UserModel.fromJson(userData);
        ref.read(authProvider.notifier).updateUser(newUser);

        if (mounted) {
          showAppSnack(
            context,
            context.l10n.conversionSubmitted,
            tone: SnackTone.success,
          );
          context.pop();
        }
      }
    } on DioException catch (e) {
      final rawMessage = e.response?.data['message']?.toString() ?? '';
      final statusCode = e.response?.statusCode;
      final isAuthError =
          statusCode == 401 ||
          statusCode == 403 ||
          rawMessage.contains('Access token') ||
          rawMessage.contains('AUTH_TOKEN');
      setState(() {
        _errorMessage = isAuthError
            ? context.l10n.conversionLoginFirst
            : (rawMessage.isNotEmpty
                  ? rawMessage
                  : context.l10n.conversionSubmitFailed);
      });
    } catch (e) {
      setState(() {
        _errorMessage = context.l10n.conversionUnexpectedError;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickShopLocation() async {
    final result = await Navigator.of(context).push<ShopLocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => ShopLocationPickerScreen(
          initialLat: _shopLocation?.lat,
          initialLng: _shopLocation?.lng,
          initialLabel: _businessAddressController.text.trim(),
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _shopLocation = ShopLocation(
        lat: result.lat,
        lng: result.lng,
        placeLabel: _businessAddressController.text.trim().isEmpty
            ? result.label
            : _businessAddressController.text.trim(),
        capturedAt: DateTime.now(),
      );
      _errorMessage = null;
    });
  }

  Future<void> _pickProofImages() async {
    final remainingSlots = 3 - _proofImages.length;
    if (remainingSlots <= 0) {
      _showMessage(context.l10n.conversionMaxProofImages);
      return;
    }

    final pickedImages = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (pickedImages.isEmpty || !mounted) return;

    setState(() {
      _proofImages.addAll(pickedImages.take(remainingSlots));
    });

    if (pickedImages.length > remainingSlots) {
      _showMessage(context.l10n.conversionProofImagesTrimmed);
    }
  }

  void _removeProofImage(int index) {
    setState(() => _proofImages.removeAt(index));
  }

  void _showMessage(String message) {
    showAppSnack(context, message, tone: SnackTone.info);
  }

  // ---- Steps -------------------------------------------------------------

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step.clamp(0, _stepCount - 1));
    if (_scrollController.hasClients) {
      if (AppMotion.reduced(context)) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: AppMotion.base,
          curve: AppMotion.standard,
        );
      }
    }
  }

  /// Next: the same checks the submit runs, one step at a time.
  void _next() {
    if (_step == 0) {
      if (!_formKey.currentState!.validate()) return;
    } else if (_step == 1 && _shopLocation == null) {
      setState(() {
        _errorMessage = context.l10n.conversionPickLocationError;
      });
      return;
    }
    setState(() => _errorMessage = null);
    _goToStep(_step + 1);
  }

  /// Submit: sends the form; if a check fails, shows the step it belongs to.
  void _submitFromLastStep() {
    if (!_formKey.currentState!.validate()) {
      _goToStep(0);
      return;
    }
    if (_shopLocation == null) {
      _goToStep(1);
    }
    _submitConversion();
  }

  // ---- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final l10n = context.l10n;
    final isPending =
        user?.isBuyer == true && user?.businessInfo?.status == 'pending';
    final isRejected =
        user?.isBuyer == true && user?.businessInfo?.status == 'rejected';

    if (!authState.isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(title: l10n.conversionTitle),
        body: EmptyState(
          icon: HugeIcons.strokeRoundedUser,
          title: l10n.conversionLoginRequiredTitle,
          message: l10n.conversionLoginRequiredBody,
          actionLabel: l10n.commonLogin,
          onAction: () => context.push('/login'),
        ),
      );
    }

    if (isPending) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppHeader(title: l10n.conversionStatusTitle),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusChip(
                    label: l10n.accTrackUnderReview,
                    tone: ChipTone.warning,
                    icon: HugeIcons.strokeRoundedTime02,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.conversionAlreadyAppliedTitle,
                    style: AppFonts.jakarta(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.accReviewNote,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _ApplicationTracker(rejected: false),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: l10n.conversionGoBack,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      );
    }

    final stepLabels = [
      l10n.accStepBusiness,
      l10n.accStepLocation,
      l10n.accStepProof,
    ];
    final isLastStep = _step == _stepCount - 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: l10n.conversionTitle),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRejected) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.conversionStatusTitle,
                            style: AppFonts.jakarta(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _ApplicationTracker(
                            rejected: true,
                            reason: l10n.conversionRejectedNote,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_step == 0 && !isRejected) ...[
                    _buildBenefitsCard(),
                    const SizedBox(height: 16),
                  ],
                  _StepProgress(labels: stepLabels, current: _step),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // All steps stay mounted so the form keeps its
                        // values and validates every field on submit.
                        _stepBody(0, _buildBusinessStep()),
                        _stepBody(1, _buildShopLocationSection()),
                        _stepBody(2, _buildProofStep()),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: AppMotion.of(context, AppMotion.fast),
                    alignment: Alignment.topCenter,
                    child: _errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.errorSoft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedAlert02,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppFonts.jakarta(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
          // Back / Next / Submit
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: l10n.commonBack,
                        variant: AppButtonVariant.secondary,
                        onPressed: _isLoading
                            ? null
                            : () => _goToStep(_step - 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 3,
                    child: isLastStep
                        ? AppButton(
                            label: l10n.conversionSubmit,
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _submitFromLastStep,
                          )
                        : AppButton(
                            label: l10n.commonNext,
                            trailingIcon: HugeIcons.strokeRoundedArrowRight01,
                            onPressed: _next,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(int index, Widget child) {
    return Visibility(
      visible: _step == index,
      maintainState: true,
      child: child,
    );
  }

  Widget _buildBenefitsCard() {
    final l10n = context.l10n;
    final benefits = [
      (HugeIcons.strokeRoundedTag01, l10n.accBenefitDealerPrices),
      (HugeIcons.strokeRoundedAgreement02, l10n.accBenefitDealDesk),
      (HugeIcons.strokeRoundedPackage, l10n.accBenefitBulkPacks),
      (HugeIcons.strokeRoundedShoppingCart01, l10n.accBenefitCartRequirement),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedStore01,
                    color: AppColors.primaryDeep,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.accUpgradeBenefitsTitle,
                  style: AppFonts.jakarta(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final (icon, text) in benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  HugeIcon(icon: icon, size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: AppFonts.jakarta(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Text(
            l10n.accReviewNote,
            style: AppFonts.jakarta(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessStep() {
    final l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.conversionSectionBusiness, style: AppText.eyebrow()),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _businessNameController,
            label: l10n.fieldBusinessName,
            hint: l10n.conversionBusinessNameHint,
            icon: HugeIcons.strokeRoundedBriefcase01,
            validator: (value) => value?.isEmpty ?? true
                ? l10n.conversionBusinessNameRequired
                : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _gstNumberController,
            label: l10n.conversionGstNumber,
            hint: l10n.conversionGstHint,
            icon: HugeIcons.strokeRoundedFile01,
            optional: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(15),
              const _UpperCaseFormatter(),
            ],
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return null;
              }
              if (!_gstinPattern.hasMatch(trimmed.toUpperCase())) {
                return l10n.accGstInvalidFormat;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _businessAddressController,
            label: l10n.conversionBusinessAddress,
            hint: l10n.conversionBusinessAddressHint,
            icon: HugeIcons.strokeRoundedLocation01,
            maxLines: 3,
            validator: (value) =>
                value?.isEmpty ?? true ? l10n.conversionAddressRequired : null,
          ),
          const SizedBox(height: 24),
          Text(l10n.conversionSectionContact, style: AppText.eyebrow()),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _contactPersonController,
            label: l10n.conversionContactPerson,
            hint: l10n.conversionContactPersonHint,
            icon: HugeIcons.strokeRoundedUser,
            validator: (value) => value?.isEmpty ?? true
                ? l10n.conversionContactPersonRequired
                : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _phoneController,
            label: l10n.fieldPhoneNumber,
            hint: l10n.conversionPhoneHint,
            icon: HugeIcons.strokeRoundedCall02,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return l10n.conversionPhoneRequired;
              }
              if (value!.length < 10) {
                return l10n.conversionPhoneInvalid;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProofStep() {
    return AppCard(child: _buildProofUploadSection());
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool optional = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (optional) ...[
              const SizedBox(width: 6),
              Text(
                context.l10n.fieldOptionalTag,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          style: AppFonts.jakarta(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: HugeIcon(
                icon: icon,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofUploadSection() {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                l10n.conversionProofTitle,
                style: AppFonts.jakarta(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.conversionProofLimit,
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.conversionProofDescription,
          style: AppFonts.jakarta(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Pressable(
          onTap: _pickProofImages,
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(AppRadius.md),
          semanticLabel: l10n.conversionUploadProof,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedImageAdd01,
                      color: AppColors.primaryDeep,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _proofImages.isEmpty
                            ? l10n.conversionUploadProof
                            : l10n.conversionImagesSelected(
                                _proofImages.length,
                              ),
                        style: AppFonts.jakarta(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.conversionImageFormats,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _proofImages.length >= 3
                      ? l10n.conversionProofFull
                      : l10n.conversionProofAdd,
                  style: AppFonts.jakarta(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _proofImages.length >= 3
                        ? AppColors.textTertiary
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_proofImages.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 6, right: 6),
              clipBehavior: Clip.none,
              itemCount: _proofImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final image = _proofImages[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(File(image.path), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Semantics(
                        button: true,
                        label: l10n.commonRemove,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _removeProofImage(index),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.textPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surfaceLight,
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShopLocationSection() {
    final selected = _shopLocation;
    final l10n = context.l10n;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.conversionShopLocation,
            style: AppFonts.jakarta(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.conversionShopLocationDescription,
            style: AppFonts.jakarta(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (selected != null) ...[
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(selected.lat, selected.lng),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: BrandConfig.packageName,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(selected.lat, selected.lng),
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Pressable(
            onTap: _pickShopLocation,
            color: selected == null ? AppColors.gray50 : AppColors.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.md),
            semanticLabel: selected == null
                ? l10n.conversionPickShopLocation
                : l10n.conversionShopLocationSelected,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected == null
                      ? AppColors.borderStrong
                      : AppColors.primarySoft,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: selected == null
                            ? HugeIcons.strokeRoundedMapPin
                            : HugeIcons.strokeRoundedCheckmarkCircle02,
                        color: AppColors.primaryDeep,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected == null
                              ? l10n.conversionPickShopLocation
                              : l10n.conversionShopLocationSelected,
                          style: AppFonts.jakarta(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected == null
                              ? l10n.conversionShopLocationHint
                              : '${selected.lat.toStringAsFixed(6)}, ${selected.lng.toStringAsFixed(6)}',
                          style:
                              AppFonts.jakarta(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ).copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selected == null
                        ? l10n.conversionPick
                        : l10n.conversionChange,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-part progress bar with the current step's label.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duration = AppMotion.of(context, AppMotion.base);
    return Semantics(
      label:
          '${l10n.accStepOf(current + 1, labels.length)}: ${labels[current]}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.accStepOf(current + 1, labels.length),
                  style: AppFonts.jakarta(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    labels[current],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.jakarta(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: AppMotion.standard,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= current
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: i == 0
                          ? TextAlign.start
                          : i == labels.length - 1
                          ? TextAlign.end
                          : TextAlign.center,
                      style: AppFonts.jakarta(
                        fontSize: 11,
                        fontWeight: i == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i <= current
                            ? AppColors.primaryDeep
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Submitted → Under review → Approved, or → Needs changes (with [reason])
/// when the last application was rejected.
class _ApplicationTracker extends StatelessWidget {
  const _ApplicationTracker({required this.rejected, this.reason});

  final bool rejected;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = <(String, _TrackState, String?)>[
      (l10n.accTrackSubmitted, _TrackState.done, null),
      (
        l10n.accTrackUnderReview,
        rejected ? _TrackState.done : _TrackState.current,
        null,
      ),
      rejected
          ? (l10n.accTrackNeedsChanges, _TrackState.failed, reason)
          : (l10n.accTrackApproved, _TrackState.upcoming, null),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      _TrackDot(state: steps[i].$2),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: steps[i].$2 == _TrackState.done
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 2,
                      bottom: i < steps.length - 1 ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].$1,
                          style: AppFonts.jakarta(
                            fontSize: 14,
                            fontWeight: steps[i].$2 == _TrackState.upcoming
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: switch (steps[i].$2) {
                              _TrackState.failed => AppColors.error,
                              _TrackState.upcoming => AppColors.textTertiary,
                              _ => AppColors.textPrimary,
                            },
                          ),
                        ),
                        if (steps[i].$3 != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            steps[i].$3!,
                            style: AppFonts.jakarta(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

enum _TrackState { done, current, upcoming, failed }

class _TrackDot extends StatelessWidget {
  const _TrackDot({required this.state});

  final _TrackState state;

  @override
  Widget build(BuildContext context) {
    final (
      Color bg,
      Color border,
      IconData? icon,
      Color iconColor,
    ) = switch (state) {
      _TrackState.done => (
        AppColors.primary,
        AppColors.primary,
        HugeIcons.strokeRoundedTick02,
        Colors.white,
      ),
      _TrackState.current => (
        AppColors.warningSoft,
        AppColors.warning,
        HugeIcons.strokeRoundedClock01,
        AppColors.warning,
      ),
      _TrackState.failed => (
        AppColors.errorSoft,
        AppColors.error,
        HugeIcons.strokeRoundedAlert02,
        AppColors.error,
      ),
      _TrackState.upcoming => (
        AppColors.surfaceLight,
        AppColors.borderStrong,
        null,
        AppColors.textTertiary,
      ),
    };
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: icon == null
          ? null
          : Center(
              child: HugeIcon(icon: icon, size: 13, color: iconColor),
            ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
