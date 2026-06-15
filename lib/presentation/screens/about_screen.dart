import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/constants/astra_colors.dart';
import '../../core/constants/astra_spacing.dart';
import '../../core/constants/astra_typography.dart';
import '../widgets/secondary_screen_shell.dart';

/// About destination — app identity and version (Story 10.8).
class AboutScreen extends StatelessWidget {
  const AboutScreen({
    this.packageInfoFuture,
    super.key,
  });

  /// Injectable for tests; production uses [PackageInfo.fromPlatform].
  final Future<PackageInfo>? packageInfoFuture;

  @override
  Widget build(BuildContext context) {
    return SecondaryScreenShell(
      title: 'About',
      child: _AboutBody(
        packageInfoFuture: packageInfoFuture ?? PackageInfo.fromPlatform(),
      ),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.packageInfoFuture});

  final Future<PackageInfo> packageInfoFuture;

  static const _kIconSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.astraColors;
    final horizontalPadding = AstraSpacing.kScreenHorizontalPadding;
    final bottomScrollPadding =
        AstraSpacing.kBottomNavBottomOffset +
        AstraSpacing.kBottomNavBarHeight +
        AstraSpacing.kSpaceMd;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AstraSpacing.kSpaceLg,
        horizontalPadding,
        bottomScrollPadding,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _kIconSize,
              height: _kIconSize,
              decoration: BoxDecoration(
                color: colors.bgElevated,
                borderRadius: BorderRadius.circular(AstraSpacing.kRadiusMd),
              ),
              child: Icon(
                PhosphorIconsRegular.footprints,
                size: 36,
                color: colors.accentPrimary,
              ),
            ),
            const SizedBox(height: AstraSpacing.kSpaceMd),
            Text(
              'Astra Health',
              style: AstraTypography.screenTitleFor(colors),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AstraSpacing.kSpaceSm),
            FutureBuilder<PackageInfo>(
              future: packageInfoFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                return Text(
                  'Version: ${snapshot.data!.version}',
                  style: AstraTypography.bodyFor(colors).copyWith(
                    color: colors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
