import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../core/config/legal_acceptance_config.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_validation.dart';
import '../../l10n/l10n.dart';
import '../../widgets/ui/ui.dart';

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

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: AppMotion.slow,
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: AppMotion.base,
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: AppMotion.standard),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: AppMotion.standard),
    );

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
    showAppSnack(context, message, tone: SnackTone.error);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = context.l10n;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Close: back to the app without signing in.
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: () => context.go('/home'),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                      side: const BorderSide(color: AppColors.border),
                      fixedSize: const Size(44, 44),
                    ),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),

                          // Logo
                          _buildLogo(),
                          const SizedBox(height: 24),

                          // Title
                          AnimatedSwitcher(
                            duration: AppMotion.of(context, AppMotion.base),
                            child: Text(
                              _isLogin
                                  ? l10n.authWelcomeBack
                                  : l10n.authCreateAccount,
                              key: ValueKey(_isLogin),
                              style: AppFonts.jakarta(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isLogin
                                ? l10n.authSignInSubtitle
                                : l10n.authJoinSubtitle,
                            style: AppFonts.jakarta(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Role Toggle
                          if (_isLogin) ...[
                            _buildRoleToggle(),
                            const SizedBox(height: 20),
                          ],

                          // Error Message
                          if (authState.error != null) ...[
                            _buildErrorBanner(authState.error!),
                            const SizedBox(height: 16),
                          ],

                          // Form Fields
                          _buildForm(),
                          const SizedBox(height: 24),

                          if (!_isLogin) ...[
                            _buildBusinessConsentCheckbox(),
                            const SizedBox(height: 20),
                          ],

                          // Submit Button
                          _buildSubmitButton(authState.isLoading),
                          const SizedBox(height: 16),

                          // Toggle Auth Mode
                          _buildAuthToggle(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: AppColors.surfaceLight,
        shape: AppShapes.squircle(
          AppRadius.md,
          side: const BorderSide(color: AppColors.border),
        ),
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

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          shape: AppShapes.squircle(AppRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _toggleRole(isWholesaler),
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.base),
              curve: AppMotion.standard,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: isSelected ? AppColors.primarySoft : Colors.transparent,
                shape: AppShapes.squircle(AppRadius.sm),
              ),
              child: Text(
                label,
                style: AppFonts.jakarta(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primaryDeep
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final l10n = context.l10n;
    return AnimatedSize(
      duration: AppMotion.of(context, AppMotion.slow),
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
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
            const SizedBox(height: 8),
            Text(
              l10n.authWholesalerProofNote,
              style: AppFonts.jakarta(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],

          // Account-access support (login only)
          if (_isLogin) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    l10n.authTroubleSignIn,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/help'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCustomerSupport,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    l10n.authContactSupport,
                    style: AppFonts.jakarta(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
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
            Text(
              label,
              style: AppFonts.jakarta(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (!required) ...[
              const SizedBox(width: 6),
              Text(
                context.l10n.fieldOptionalTag,
                style: AppFonts.jakarta(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: AppFonts.jakarta(
            fontSize: 16,
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
            prefixText: prefix,
            prefixStyle: AppFonts.jakarta(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            suffixIcon: isPassword
                ? IconButton(
                    icon: HugeIcon(
                      icon: obscureText
                          ? HugeIcons.strokeRoundedViewOff
                          : HugeIcons.strokeRoundedView,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.borderStrong),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isLoading) {
    return AppButton(
      label: _isLogin
          ? context.l10n.authSignIn
          : context.l10n.authCreateAccount,
      loading: isLoading,
      onPressed: isLoading ? null : _handleSubmit,
    );
  }

  Widget _buildBusinessConsentCheckbox() {
    final l10n = context.l10n;
    final linkStyle = AppFonts.jakarta(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
    );
    final textStyle = AppFonts.jakarta(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _acceptedTermsAndPrivacy
              ? AppColors.primarySoft
              : AppColors.border,
        ),
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
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.authConsentIntro, style: textStyle),
                      Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () =>
                                context.push('/legal/terms-conditions'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.legalTermsConditions,
                              style: linkStyle,
                            ),
                          ),
                          Text(l10n.authConsentAnd, style: textStyle),
                          TextButton(
                            onPressed: () =>
                                context.push('/legal/privacy-policy'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.authConsentPrivacyLink,
                              style: linkStyle,
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
                icon: AnimatedRotation(
                  turns: _showPolicyDetails ? 0.5 : 0,
                  duration: AppMotion.of(context, AppMotion.base),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.base),
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: _showPolicyDetails
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final point in [
                          l10n.authConsentPointCollect,
                          l10n.authConsentPointUse,
                          l10n.authConsentPointShare,
                          l10n.authConsentPointRights,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              point,
                              style: AppFonts.jakarta(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthToggle() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _isLogin
                ? context.l10n.authNoAccount
                : context.l10n.authHaveAccount,
            style: AppFonts.jakarta(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          TextButton(
            onPressed: _toggleAuthMode,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              _isLogin ? context.l10n.authSignUp : context.l10n.authSignIn,
              style: AppFonts.jakarta(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
