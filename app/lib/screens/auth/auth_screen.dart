import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/config/legal_acceptance_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/utils/phone_validation.dart';
import '../../l10n/l10n.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _businessNameController = TextEditingController();

  // State
  bool _isLogin = true;
  bool _isWholesaler = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTermsAndPrivacy = false;
  bool _showPolicyDetails = false;

  // Animation Controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Colors
  static const _primaryGreen = Color(0xFF2D6A4F);
  static const _primaryBlue = Color(0xFF115E59);
  static const _backgroundLight = Color(0xFFF8FAF9);
  static const _textDark = Color(0xFF1A1A1A);
  static const _textMuted = Color(0xFF6B7280);
  static const _borderColor = Color(0xFFE5E7EB);

  Color get _primaryColor => _isWholesaler ? _primaryBlue : _primaryGreen;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _businessNameController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() async {
    await _fadeController.reverse();
    setState(() {
      _isLogin = !_isLogin;
      if (!_isLogin) {
        _isWholesaler = false;
      }
      _clearFields();
    });
    _slideController.reset();
    _slideController.forward();
    _fadeController.forward();
  }

  void _toggleRole(bool isWholesaler) {
    if (_isWholesaler == isWholesaler) return;

    setState(() {
      _isWholesaler = isWholesaler;
    });
  }

  void _clearFields() {
    _phoneController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _nameController.clear();
    _businessNameController.clear();
    _acceptedTermsAndPrivacy = false;
    _showPolicyDetails = false;
  }

  Future<void> _handleSubmit() async {
    final phone = _isLogin
        ? _phoneController.text.trim()
        : _phoneController.text;
    final password = _passwordController.text;

    final l10n = context.l10n;
    final phoneError = _isLogin
        ? (phone.isEmpty || phone.length < 10
              ? l10n.authErrorInvalidPhone
              : null)
        : _registrationPhoneError(phone);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }
    if (password.isEmpty || password.length < 6) {
      _showError(l10n.authErrorPasswordShort);
      return;
    }

    if (_isLogin) {
      final success = await ref
          .read(authProvider.notifier)
          .loginWithPhone(
            phone: phone,
            password: password,
            expectedRole: _isWholesaler ? 'wholesaler' : 'buyer',
          );
      if (success && mounted) {
        context.go('/home');
      }
    } else {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _showError(l10n.fieldEnterName);
        return;
      }
      if (_confirmPasswordController.text != password) {
        _showError(l10n.authErrorPasswordMismatch);
        return;
      }
      if (!_acceptedTermsAndPrivacy) {
        _showError(l10n.authErrorAcceptTerms);
        return;
      }

      final success = await ref
          .read(authProvider.notifier)
          .registerWithPhone(
            name: name,
            phone: phone,
            password: password,
            isWholesaler: _isWholesaler,
            termsAccepted: true,
            privacyPolicyAccepted: true,
            termsVersion: LegalAcceptanceConfig.termsVersion,
            privacyPolicyVersion: LegalAcceptanceConfig.privacyPolicyVersion,
            businessName: _isWholesaler
                ? _businessNameController.text.trim()
                : null,
          );
      if (success && mounted) {
        context.go('/home');
      }
    }
  }

  /// Localized version of [PhoneValidation.registrationError].
  String? _registrationPhoneError(String phone) {
    if (PhoneValidation.registrationError(phone) == null) return null;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone)
        ? context.l10n.authErrorPhoneNotReal
        : context.l10n.authErrorPhoneIndian;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppFonts.bodyMedium(color: Colors.white)),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = context.l10n;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _backgroundLight,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Logo
                      _buildLogo(),
                      const SizedBox(height: 32),

                      // Title
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _isLogin
                              ? l10n.authWelcomeBack
                              : l10n.authCreateAccount,
                          key: ValueKey(_isLogin),
                          style: AppFonts.h1(color: _textDark),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin
                            ? l10n.authSignInSubtitle
                            : l10n.authJoinSubtitle,
                        style: AppFonts.bodyMedium(color: _textMuted),
                      ),
                      const SizedBox(height: 32),

                      // Role Toggle
                      if (_isLogin) ...[
                        _buildRoleToggle(),
                        const SizedBox(height: 28),
                      ],

                      // Error Message
                      if (authState.error != null) ...[
                        _buildErrorBanner(authState.error!),
                        const SizedBox(height: 20),
                      ],

                      // Form Fields
                      _buildForm(),
                      const SizedBox(height: 28),

                      if (!_isLogin) ...[
                        _buildBusinessConsentCheckbox(),
                        const SizedBox(height: 20),
                      ],

                      // Submit Button
                      _buildSubmitButton(authState.isLoading),
                      const SizedBox(height: 24),

                      // Toggle Auth Mode
                      _buildAuthToggle(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleButton(context.l10n.authRoleCustomer, false),
          ),
          Expanded(
            child: _buildRoleButton(context.l10n.authRoleWholesaler, true),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String label, bool isWholesaler) {
    final isSelected = _isWholesaler == isWholesaler;

    return GestureDetector(
      onTap: () => _toggleRole(isWholesaler),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: AppFonts.labelLarge(
              color: isSelected ? Colors.white : _textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: AppFonts.bodySmall(color: const Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final l10n = context.l10n;
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field (signup only)
          if (!_isLogin) ...[
            _buildTextField(
              controller: _nameController,
              label: l10n.fieldFullName,
              hint: l10n.authNameHint,
              icon: HugeIcons.strokeRoundedUser,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
          ],

          // Phone field
          _buildTextField(
            controller: _phoneController,
            label: l10n.fieldPhoneNumber,
            hint: l10n.authPhoneHint,
            icon: HugeIcons.strokeRoundedCall,
            keyboardType: TextInputType.phone,
            prefix: '+91 ',
            maxLength: _isLogin ? null : 10,
            inputFormatters: _isLogin
                ? null
                : [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          // Password field
          _buildTextField(
            controller: _passwordController,
            label: l10n.authPasswordLabel,
            hint: l10n.authPasswordHint,
            icon: HugeIcons.strokeRoundedLockPassword,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),

          // Confirm password (signup only)
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmPasswordController,
              label: l10n.authConfirmPasswordLabel,
              hint: l10n.authConfirmPasswordHint,
              icon: HugeIcons.strokeRoundedLockPassword,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onToggleObscure: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
          ],

          // Wholesaler fields
          if (!_isLogin && _isWholesaler) ...[
            const SizedBox(height: 16),
            _buildTextField(
              controller: _businessNameController,
              label: l10n.fieldBusinessName,
              hint: l10n.authBusinessNameHint,
              icon: HugeIcons.strokeRoundedStore01,
              required: false,
            ),
            const SizedBox(height: 10),
            Text(
              l10n.authWholesalerProofNote,
              style: AppFonts.caption(color: _textMuted),
            ),
          ],

          // Account-access support (login only)
          if (_isLogin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/help'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.authNeedHelp,
                  style: AppFonts.bodySmall(
                    color: _primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefix,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppFonts.labelMedium(color: _textDark)),
            if (!required) ...[
              const SizedBox(width: 6),
              Text(
                context.l10n.fieldOptionalTag,
                style: AppFonts.caption(color: _textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: AppFonts.bodyLarge(color: _textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppFonts.bodyMedium(color: const Color(0xFFADB5BD)),
              prefixIcon: HugeIcon(icon: icon, color: _textMuted, size: 22),
              prefixText: prefix,
              prefixStyle: AppFonts.bodyLarge(color: _textDark),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: HugeIcon(
                        icon: obscureText
                            ? HugeIcons.strokeRoundedViewOff
                            : HugeIcons.strokeRoundedView,
                        color: _textMuted,
                        size: 22,
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primaryColor.withOpacity(0.6),
          elevation: 0,
          shadowColor: _primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                _isLogin
                    ? context.l10n.authSignIn
                    : context.l10n.authCreateAccount,
                style: AppFonts.button(color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildBusinessConsentCheckbox() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedTermsAndPrivacy,
                onChanged: (value) =>
                    setState(() => _acceptedTermsAndPrivacy = value ?? false),
                activeColor: _primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: const BorderSide(color: Color(0xFFC7C7CC), width: 1.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.authConsentIntro,
                        style: AppFonts.bodyMedium(
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Wrap(
                        spacing: 2,
                        children: [
                          TextButton(
                            onPressed: () =>
                                context.push('/legal/terms-conditions'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.legalTermsConditions,
                              style: AppFonts.bodyMedium(
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            l10n.authConsentAnd,
                            style: AppFonts.bodyMedium(
                              color: _textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.push('/legal/privacy-policy'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.authConsentPrivacyLink,
                              style: AppFonts.bodyMedium(
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _showPolicyDetails = !_showPolicyDetails),
                icon: Icon(
                  _showPolicyDetails
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _textMuted,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _showPolicyDetails
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.authConsentPointCollect,
                    style: AppFonts.bodySmall(color: _textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.authConsentPointUse,
                    style: AppFonts.bodySmall(color: _textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.authConsentPointShare,
                    style: AppFonts.bodySmall(color: _textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.authConsentPointRights,
                    style: AppFonts.bodySmall(color: _textMuted),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthToggle() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isLogin
                ? context.l10n.authNoAccount
                : context.l10n.authHaveAccount,
            style: AppFonts.bodyMedium(color: _textMuted),
          ),
          GestureDetector(
            onTap: _toggleAuthMode,
            child: Text(
              _isLogin ? context.l10n.authSignUp : context.l10n.authSignIn,
              style: AppFonts.bodyMedium(
                color: _primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
