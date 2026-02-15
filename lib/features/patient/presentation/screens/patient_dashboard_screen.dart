import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../routing/route_names.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family/providers/family_provider.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch active profile
    final profile = ref.watch(activeContextProfileProvider);
    final todayDate = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100 - Slightly darker/cooler background
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────────────────────────────────
              // 1. HEADER (High Contrast)
              // ─────────────────────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todayDate.toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade600, // Darker grey for better readability
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hello, ${profile.valueOrNull?.fullName.split(' ').first ?? 'Patient'}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900, // Bolder
                          color: Color(0xFF1E293B), // Slate 800 - Nearly black
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  // Profile Avatar / Settings Button
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08), // Stronger shadow
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.person_outline_rounded,
                          color: Color(0xFF1E293B)),
                      onPressed: () => context.push(RouteNames.patientPrivacy),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ─────────────────────────────────────────────────────────────────
              // 2. EMERGENCY / ID CARD (Deep Premium Gradient)
              // ─────────────────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF115E59), // Teal 800
                      Color(0xFF0D9488), // Teal 600
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF115E59).withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Decorative Curves
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Content
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push(RouteNames.patientQrCode),
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: const Icon(Icons.qr_code_rounded,
                                        color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text(
                                    'Medical ID Access',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Text(
                                'Tap to show QR Code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'For emergency responders',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // ─────────────────────────────────────────────────────────────────
              // 3. TOP CATEGORIES (Professional "Solid Card" Style)
              // ─────────────────────────────────────────────────────────────────
              _buildTopCategories(context),
              const SizedBox(height: 36),

              // ─────────────────────────────────────────────────────────────────
              // 4. SERVICES GRID (More Defined Colors)
              // ─────────────────────────────────────────────────────────────────
              const Text(
                'Services',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B), // Slate 800
                ),
              ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.88,
                children: [
                  // CARD 1: My Prescriptions (Deep Blue)
                  _buildPatientTile(
                    title: 'My Rx',
                    subtitle: 'View Active',
                    icon: Icons.medication_rounded,
                    themeColor: const Color(0xFF0284C7), // Sky 600
                    onTap: () => context.push(RouteNames.patientPrescriptions),
                  ),

                  // CARD 2: Medical History (Deep Purple)
                  _buildPatientTile(
                    title: 'History',
                    subtitle: 'Past Records',
                    icon: Icons.history_rounded,
                    themeColor: const Color(0xFF7E22CE), // Purple 700
                    onTap: () => context.push(RouteNames.patientMedicalHistory),
                  ),

                  // CARD 3: Add New (Deep Orange)
                  _buildPatientTile(
                    title: 'New Rx',
                    subtitle: 'Add Script',
                    icon: Icons.add_circle_outline_rounded,
                    themeColor: const Color(0xFFEA580C), // Orange 600
                    onTap: () =>
                        context.push(RouteNames.patientNewPrescription),
                  ),

                  // CARD 4: Settings (Deep Teal)
                  _buildPatientTile(
                    title: 'Privacy',
                    subtitle: 'Manage Data',
                    icon: Icons.security_rounded,
                    themeColor: const Color(0xFF0F766E), // Teal 700
                    onTap: () => context.push(RouteNames.patientPrivacy),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HORIZONTAL SCROLL SECTION (High Contrast / Professional)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTopCategories(BuildContext context) {
    // Layout Layout Constants
    const double avatarSize = 40.0;
    const double xOverlap = 30.0;
    const double yOffset = 34.0;

    return SizedBox(
      height: 185,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        children: [
          // ─────────────────────────────────────────────────────────────
          // 1. TOP DOCTORS (Deep Green Gradient Highlight)
          // ─────────────────────────────────────────────────────────────
          _buildCategoryCard(
            title: 'Top Doctors',
            themeColor: const Color(0xFF059669), // Emerald 600
            iconWatermark: Icons.medical_services_outlined,
            isHighlighted: true,
            onTap: () {},
            content: SizedBox(
              height: 80,
              width: 140,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 0, top: 0, child: _buildAvatar(Icons.person, Colors.grey.shade200, Colors.grey.shade600, const Color(0xFF059669), avatarSize)),
                  Positioned(left: xOverlap + 4, top: 0, child: _buildAvatar(Icons.person_4, Colors.grey.shade100, Colors.grey.shade600, const Color(0xFF059669), avatarSize)),
                  Positioned(left: (xOverlap * 2) + 8, top: 0, child: _buildAvatar(Icons.person_2, Colors.grey.shade200, Colors.grey.shade600, const Color(0xFF059669), avatarSize)),
                  Positioned(left: (xOverlap / 2) + 2, top: yOffset, child: _buildAvatar(Icons.person_3, Colors.grey.shade100, Colors.grey.shade600, const Color(0xFF059669), avatarSize)),
                  Positioned(left: (xOverlap * 1.5) + 6, top: yOffset, child: _buildCountBadge('17+', const Color(0xFF059669), avatarSize, isDark: true)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ─────────────────────────────────────────────────────────────
          // 2. SPECIALTY DOCTORS (Solid White + Rose Accent)
          // ─────────────────────────────────────────────────────────────
          _buildCategoryCard(
            title: 'Specialty Doctors',
            themeColor: const Color(0xFFE11D48), // Rose 600
            iconWatermark: Icons.health_and_safety_outlined,
            isHighlighted: false,
            onTap: () {},
            content: SizedBox(
              height: 80,
              width: 140,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 0, top: 0, child: _buildAvatar(Icons.spa_rounded, const Color(0xFFFFF1F2), const Color(0xFFE11D48), Colors.white, avatarSize)),
                  Positioned(left: xOverlap + 4, top: 0, child: _buildAvatar(Icons.psychology_rounded, const Color(0xFFFFF1F2), const Color(0xFFE11D48), Colors.white, avatarSize)),
                  Positioned(left: (xOverlap / 2) + 2, top: yOffset, child: _buildAvatar(Icons.healing_rounded, const Color(0xFFFFF1F2), const Color(0xFFE11D48), Colors.white, avatarSize)),
                  Positioned(left: (xOverlap * 1.5) + 6, top: yOffset, child: _buildCountBadge('15+', const Color(0xFFE11D48), avatarSize, isDark: false)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ─────────────────────────────────────────────────────────────
          // 3. EMERGENCY SERVICES (Solid White + Blue Accent)
          // ─────────────────────────────────────────────────────────────
          _buildCategoryCard(
            title: 'Emergency Services',
            themeColor: const Color(0xFF2563EB), // Blue 600
            iconWatermark: Icons.emergency_outlined,
            isHighlighted: false,
            onTap: () {},
            content: SizedBox(
              height: 80,
              width: 130,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 4, top: 8, child: _buildAvatar(Icons.local_shipping_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB), Colors.white, avatarSize)),
                  Positioned(left: 44, top: 0, child: _buildAvatar(Icons.medical_services_rounded, const Color(0xFFEFF6FF), const Color(0xFF2563EB), Colors.white, avatarSize)),
                  Positioned(left: 54, top: yOffset + 4, child: _buildCountBadge('24/7', const Color(0xFF2563EB), avatarSize, isDark: false)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAvatar(IconData icon, Color bg, Color fg, Color borderColor, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        // Thicker border for better separation
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), // Stronger shadow
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: fg, size: size * 0.55),
    );
  }

  Widget _buildCountBadge(String text, Color themeColor, double size, {required bool isDark}) {
    // If card is dark (Green), badge is dark. If card is white, badge is white.
    final bgColor = isDark ? const Color(0xFF064E3B) : Colors.white; // Dark Green or White
    final textColor = isDark ? Colors.white : themeColor;
    final borderColor = isDark ? const Color(0xFF059669) : themeColor.withOpacity(0.2);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// ─────────────────────────────────────────────────────────────────────────────
  /// UNIFIED CATEGORY CARD (Stronger Contrast)
  /// ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryCard({
    required String title,
    required Color themeColor,
    required IconData iconWatermark,
    required Widget content,
    required VoidCallback onTap,
    required bool isHighlighted,
  }) {
    // Professional Look: Solid White for normal, Gradient for Highlighted
    final decoration = isHighlighted
        ? BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF047857)], // Deep Emerald
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF059669).withOpacity(0.4),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    )
        : BoxDecoration(
      color: Colors.white, // Solid White
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.grey.shade200, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06), // Subtle drop shadow
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );

    final textColor = isHighlighted ? Colors.white : const Color(0xFF1E293B);
    final arrowBg = isHighlighted ? Colors.white.withOpacity(0.2) : Colors.grey.shade100;
    final arrowColor = isHighlighted ? Colors.white : const Color(0xFF334155);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 165,
          padding: const EdgeInsets.all(20),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: arrowBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_outward_rounded,
                        color: arrowColor,
                        size: 16
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }

  /// ─────────────────────────────────────────────────────────────────────────────
  /// SERVICES GRID TILE (More Defined)
  /// ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPatientTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color themeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Solid white background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200), // Distinct border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          // Subtle color glow at the bottom
          BoxShadow(
            color: themeColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Large Watermark
              Positioned(
                right: -15,
                bottom: -15,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Icon(
                    icon,
                    size: 90,
                    color: themeColor.withOpacity(0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1), // Tinted circle
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: themeColor,
                        size: 26,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B), // Darker Text
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueGrey.shade400,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}