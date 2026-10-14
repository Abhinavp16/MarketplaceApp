import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _avatarController;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name);
    _phoneController = TextEditingController(text: user?.phone);
    _avatarController = TextEditingController(text: user?.avatar);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authProvider.notifier)
          .updateProfile(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            avatar: _avatarController.text.trim(),
          );

      if (mounted) {
        final l10n = context.l10n;
        if (success) {
          showAppSnack(
            context,
            l10n.editProfileUpdated,
            tone: SnackTone.success,
          );
          context.pop();
        } else {
          final error = ref.read(authProvider).error;
          showAppSnack(
            context,
            error ?? l10n.editProfileUpdateFailed,
            tone: SnackTone.error,
          );
        }
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;

      setState(() => _isUploadingAvatar = true);
      final avatarUrl = await ref
          .read(authProvider.notifier)
          .uploadProfileAvatar(file.path);

      if (!mounted) return;
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        setState(() => _avatarController.text = avatarUrl);
        showAppSnack(
          context,
          context.l10n.editProfileUpdated,
          tone: SnackTone.success,
        );
      } else {
        final error = ref.read(authProvider).error;
        showAppSnack(
          context,
          error ?? context.l10n.editProfileUpdateFailed,
          tone: SnackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppHeader(title: l10n.profileEditProfile),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Semantics(
                  button: true,
                  label: l10n.profileEditProfile,
                  child: InkWell(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    customBorder: const CircleBorder(),
                    child: Stack(
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primarySoft,
                            border: Border.all(
                              color: AppColors.surfaceLight,
                              width: 3,
                            ),
                            image: _avatarController.text.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_avatarController.text),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _avatarController.text.isEmpty
                              ? const Center(
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedUser,
                                    size: 40,
                                    color: AppColors.primaryDeep,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surfaceLight,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCamera01,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      label: l10n.fieldFullName,
                      controller: _nameController,
                      icon: HugeIcons.strokeRoundedUser,
                      validator: (val) => val == null || val.isEmpty
                          ? l10n.fieldEnterName
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: l10n.fieldPhoneNumber,
                      controller: _phoneController,
                      icon: HugeIcons.strokeRoundedSmartPhone01,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              AppButton(
                label: l10n.commonSaveChanges,
                loading: isLoading,
                onPressed: isLoading ? null : _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.jakarta(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
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
                size: 20,
                color: AppColors.textTertiary,
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
}
