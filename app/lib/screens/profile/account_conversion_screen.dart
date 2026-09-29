import 'dart:io';

import 'package:flutter/material.dart';
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
import '../../l10n/l10n.dart';

class AccountConversionScreen extends ConsumerStatefulWidget {
  const AccountConversionScreen({super.key});

  @override
  ConsumerState<AccountConversionScreen> createState() =>
      _AccountConversionScreenState();
}

class _AccountConversionScreenState
    extends ConsumerState<AccountConversionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;
  final List<XFile> _proofImages = [];
  ShopLocation? _shopLocation;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _businessNameController.text = user.businessInfo?.businessName ?? '';
      _gstNumberController.text = user.businessInfo?.gstNumber ?? '';
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.conversionSubmitted),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } on DioException catch (e) {
      final rawMessage =
          e.response?.data['message']?.toString() ?? '';
      final statusCode = e.response?.statusCode;
      final isAuthError =
          statusCode == 401 || statusCode == 403 ||
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0F766E);
    const backgroundWhite = Color(0xFFF8FAFC);
    const surfaceWhite = Color(0xFFFFFFFF);
    const textPrimary = Color(0xFF1E293B);
    const textSecondary = Color(0xFF64748B);
    const borderLight = Color(0xFFE2E8F0);

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final l10n = context.l10n;
    final isPending = user?.isBuyer == true && user?.businessInfo?.status == 'pending';
    final isRejected = user?.isBuyer == true && user?.businessInfo?.status == 'rejected';

    if (!authState.isAuthenticated) {
      return Scaffold(
        backgroundColor: backgroundWhite,
        appBar: AppBar(
          backgroundColor: surfaceWhite,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: textPrimary, size: 24),
          ),
          title: Text(l10n.conversionTitle, style: AppFonts.jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedUser, color: primaryBlue, size: 64),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.conversionLoginRequiredTitle,
                  style: AppFonts.jakarta(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.conversionLoginRequiredBody,
                  textAlign: TextAlign.center,
                  style: AppFonts.jakarta(fontSize: 16, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(l10n.commonLogin, style: AppFonts.jakarta(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (isPending) {
      return Scaffold(
        backgroundColor: backgroundWhite,
        appBar: AppBar(
          backgroundColor: surfaceWhite,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: textPrimary, size: 24),
          ),
          title: Text(l10n.conversionStatusTitle, style: AppFonts.jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedTime02, color: primaryBlue, size: 64),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.conversionAlreadyAppliedTitle,
                  style: AppFonts.jakarta(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.conversionAlreadyAppliedBody,
                  textAlign: TextAlign.center,
                  style: AppFonts.jakarta(fontSize: 16, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(l10n.conversionGoBack, style: AppFonts.jakarta(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: textPrimary,
            size: 24,
          ),
        ),
        title: Text(
          l10n.conversionTitle,
          style: AppFonts.jakarta(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Illustration/Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceWhite,
                border: Border(
                  bottom: BorderSide(color: borderLight.withOpacity(0.5)),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const HugeIcon(
                      icon: HugeIcons.strokeRoundedStore01,
                      color: primaryBlue,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.conversionHeaderTitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.jakarta(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.conversionHeaderSubtitle,
                    textAlign: TextAlign.center,
                    style: AppFonts.jakarta(
                      fontSize: 14,
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderLight.withOpacity(0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRejected) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.conversionRejectedNote,
                                  style: AppFonts.jakarta(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        l10n.conversionSectionBusiness,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return null;
                          }
                          if (trimmed.length != 15) {
                            return l10n.conversionGstInvalid;
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
                        validator: (value) => value?.isEmpty ?? true
                            ? l10n.conversionAddressRequired
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildShopLocationSection(),
                      const SizedBox(height: 16),
                      _buildProofUploadSection(),
                      const SizedBox(height: 24),
                      Text(
                        l10n.conversionSectionContact,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
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

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: AppFonts.jakarta(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitConversion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  l10n.conversionSubmit,
                                  style: AppFonts.jakarta(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
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
  }) {
    const textPrimary = Color(0xFF1E293B);
    const textSecondary = Color(0xFF64748B);
    const borderLight = Color(0xFFE2E8F0);
    const primaryBlue = Color(0xFF0F766E);

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
                color: textPrimary,
              ),
            ),
            if (optional) ...[
              const SizedBox(width: 6),
              Text(
                context.l10n.fieldOptionalTag,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
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
          style: AppFonts.jakarta(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppFonts.jakarta(
              fontSize: 14,
              color: textSecondary.withOpacity(0.5),
            ),
            prefixIcon: HugeIcon(icon: icon, color: textSecondary, size: 20),
            filled: true,
            fillColor: Colors.black.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofUploadSection() {
    const textPrimary = Color(0xFF1E293B);
    const textSecondary = Color(0xFF64748B);
    const borderLight = Color(0xFFE2E8F0);
    const primaryBlue = Color(0xFF0F766E);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.conversionProofTitle,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.conversionProofLimit,
              style: AppFonts.jakarta(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.conversionProofDescription,
          style: AppFonts.jakarta(
            fontSize: 12,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickProofImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
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
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.conversionImageFormats,
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _proofImages.length >= 3
                      ? l10n.conversionProofFull
                      : l10n.conversionProofAdd,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_proofImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _proofImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = _proofImages[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderLight),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(image.path), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _removeProofImage(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
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
    const textPrimary = Color(0xFF1E293B);
    const textSecondary = Color(0xFF64748B);
    const borderLight = Color(0xFFE2E8F0);
    const primaryBlue = Color(0xFF0F766E);

    final selected = _shopLocation;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.conversionShopLocation,
          style: AppFonts.jakarta(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.conversionShopLocationDescription,
          style: AppFonts.jakarta(
            fontSize: 12,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickShopLocation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected == null
                    ? borderLight
                    : primaryBlue.withOpacity(0.45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
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
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selected == null
                            ? l10n.conversionShopLocationHint
                            : '${selected.lat.toStringAsFixed(6)}, ${selected.lng.toStringAsFixed(6)}',
                        style: AppFonts.jakarta(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  selected == null
                      ? l10n.conversionPick
                      : l10n.conversionChange,
                  style: AppFonts.jakarta(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderLight),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
                          color: Colors.red,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
