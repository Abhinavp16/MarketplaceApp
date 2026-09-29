import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../l10n/l10n.dart';

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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.editProfileUpdated)));
          context.pop();
        } else {
          final error = ref.read(authProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error ?? l10n.editProfileUpdateFailed)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.editProfileUpdated)),
        );
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? context.l10n.editProfileUpdateFailed),
          ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.black,
          ),
        ),
        title: Text(
          l10n.profileEditProfile,
          style: AppFonts.jakarta(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: InkWell(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  borderRadius: BorderRadius.circular(60),
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[100],
                          image: _avatarController.text.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_avatarController.text),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _avatarController.text.isEmpty
                            ? const Icon(
                                HugeIcons.strokeRoundedUser,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F766E),
                            shape: BoxShape.circle,
                          ),
                          child: _isUploadingAvatar
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  HugeIcons.strokeRoundedCamera01,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                label: l10n.fieldFullName,
                controller: _nameController,
                icon: HugeIcons.strokeRoundedUser,
                validator: (val) =>
                    val == null || val.isEmpty ? l10n.fieldEnterName : null,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: l10n.fieldPhoneNumber,
                controller: _phoneController,
                icon: HugeIcons.strokeRoundedSmartPhone01,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          l10n.commonSaveChanges,
                          style: AppFonts.jakarta(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0F766E)),
            ),
          ),
        ),
      ],
    );
  }
}
