import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../models/lesson_block_type.dart';
import '../../models/lesson_page.dart';

bool isComposerLessonPage(LessonPage page) =>
    LessonBlockType.fromSectionType(page.sectionType) != null;

/// Stable label for the guided viewer footer and outline. Paragraphs and
/// optional-label callouts may deliberately have an empty stored title.
String lessonPageNavigationLabel(LessonPage page) {
  final String title = page.title.trim();
  if (title.isNotEmpty) return title;
  return LessonBlockType.fromSectionType(page.sectionType)?.label ??
      'Lesson note';
}

/// The shared visual renderer for teacher-composed lesson blocks.
///
/// Student lesson pages and Teacher Preview both use this widget so the
/// authoring preview cannot drift into a separate presentation system.
class LessonContentBlockView extends StatelessWidget {
  const LessonContentBlockView({
    super.key,
    required this.page,
    this.compact = false,
    this.imageBytes,
  });

  final LessonPage page;
  final bool compact;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final LessonBlockType type =
        LessonBlockType.fromSectionType(page.sectionType) ??
        LessonBlockType.paragraph;

    return switch (type) {
      LessonBlockType.heading => _HeadingBlock(page: page, compact: compact),
      LessonBlockType.paragraph => _ParagraphBlock(
        page: page,
        compact: compact,
      ),
      LessonBlockType.image => _ImageBlock(
        page: page,
        compact: compact,
        imageBytes: imageBytes,
      ),
      LessonBlockType.keyIdea => _CalloutBlock(
        page: page,
        compact: compact,
        icon: Icons.lightbulb_rounded,
        color: const Color(0xFF246B58),
        background: const Color(0xFFE7F4EF),
        eyebrow: 'KEY IDEA',
      ),
      LessonBlockType.workedExample => _CalloutBlock(
        page: page,
        compact: compact,
        icon: Icons.calculate_rounded,
        color: const Color(0xFF8A5A12),
        background: const Color(0xFFFFF3DC),
        eyebrow: 'WORKED EXAMPLE',
      ),
      LessonBlockType.link => _LinkBlock(page: page, compact: compact),
    };
  }
}

class _HeadingBlock extends StatelessWidget {
  const _HeadingBlock({required this.page, required this.compact});

  final LessonPage page;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 46,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            page.title,
            style: GoogleFonts.lexend(
              color: AppColors.textPrimary,
              fontSize: compact ? 25 : 30,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
          ),
          if (page.body.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              page.body,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: compact ? 14 : 15,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({required this.page, required this.compact});

  final LessonPage page;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (page.title.trim().isNotEmpty) ...<Widget>[
          Text(
            page.title,
            style: GoogleFonts.lexend(
              color: AppColors.textPrimary,
              fontSize: compact ? 18 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        SelectableText(
          page.body,
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w400,
            height: compact ? 1.5 : 1.62,
          ),
        ),
      ],
    );
  }
}

class _CalloutBlock extends StatelessWidget {
  const _CalloutBlock({
    required this.page,
    required this.compact,
    required this.icon,
    required this.color,
    required this.background,
    required this.eyebrow,
  });

  final LessonPage page;
  final bool compact;
  final IconData icon;
  final Color color;
  final Color background;
  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: compact ? 22 : 25),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  eyebrow,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                if (page.title.trim().isNotEmpty) ...<Widget>[
                  Text(
                    page.title,
                    style: GoogleFonts.lexend(
                      color: AppColors.textPrimary,
                      fontSize: compact ? 17 : 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                SelectableText(
                  page.body,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({
    required this.page,
    required this.compact,
    required this.imageBytes,
  });

  final LessonPage page;
  final bool compact;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: colors.surfaceContainerHighest,
              child:
                  imageBytes != null
                      ? Image.memory(
                        imageBytes!,
                        fit: BoxFit.contain,
                        semanticLabel: page.title,
                      )
                      : Image.network(
                        page.body,
                        fit: BoxFit.contain,
                        semanticLabel: page.title,
                        loadingBuilder: (
                          BuildContext context,
                          Widget child,
                          ImageChunkEvent? progress,
                        ) {
                          if (progress == null) return child;
                          final int? expected = progress.expectedTotalBytes;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  expected == null
                                      ? null
                                      : progress.cumulativeBytesLoaded /
                                          expected,
                            ),
                          );
                        },
                        errorBuilder:
                            (_, _, _) => _ImageError(color: colors.primary),
                      ),
            ),
          ),
        ),
        if (page.title.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            page.title,
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, color: color, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This lesson image could not be loaded.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkBlock extends StatelessWidget {
  const _LinkBlock({required this.page, required this.compact});

  final LessonPage page;
  final bool compact;

  Future<void> _openLink(BuildContext context) async {
    final Uri? uri = Uri.tryParse(page.body);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this lesson link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openLink(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: EdgeInsets.all(compact ? 14 : AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.link_rounded, color: colors.onPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      page.title.trim().isEmpty ? 'Open resource' : page.title,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      page.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.open_in_new_rounded, color: colors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
