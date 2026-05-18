import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../auth/domain/auth_notifier.dart';
import 'package:go_router/go_router.dart';
import '../../data/gallery_repository.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
    final albumsAsync = ref.watch(albumsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return DsScreenShell(
      title: 'Photo Gallery',
      subtitle: 'Society albums & event memories',
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(albumsProvider),
        ),
      ],
      onRefresh: () async => ref.invalidate(albumsProvider),
      extraBottomPadding: isExec ? dsSpace16 : 0,
      floatingActionButton: isExec
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(dsRadiusXl),
                boxShadow: dsShadowBrand,
              ),
              child: FloatingActionButton.extended(
                backgroundColor: dsColorIndigo600,
                foregroundColor: Colors.white,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                icon: Icon(Icons.create_new_folder_outlined,
                    size: context.si(20)),
                label: Text(
                  'New Album',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(14),
                  ),
                ),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _CreateAlbumModal(
                    onCreated: () => ref.invalidate(albumsProvider),
                  ),
                ),
              ),
            )
          : null,
      slivers: [
        albumsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load albums',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(albumsProvider),
          ),
          data: (albums) {
            if (albums.isEmpty) {
              return const DsEmptyPlaceholder(
                icon: Icons.photo_library_outlined,
                title: 'No albums yet',
                message: 'Society event photos will appear here.',
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  dsSpace4, dsSpace3, dsSpace4, 0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: dsSpace3,
                  mainAxisSpacing: dsSpace3,
                  childAspectRatio: 0.82,
                ),
                itemCount: albums.length,
                itemBuilder: (context, i) => DSFadeSlide(
                  delay: Duration(milliseconds: i * 40),
                  child: _AlbumCard(album: albums[i], isDark: isDark),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Album card
// ---------------------------------------------------------------------------

class _AlbumCard extends ConsumerWidget {
  final GalleryAlbum album;
  final bool isDark;

  const _AlbumCard({required this.album, required this.isDark});

  // Accent palette — cycles by album ID hash
  static const List<(Color bg, Color icon)> _palette = [
    (dsColorIndigo100, dsColorIndigo600),
    (dsColorEmerald100, dsColorEmerald700),
    (dsColorAmber100, dsColorAmber700),
    (dsColorViolet100, dsColorViolet600),
    (dsColorTerra100, dsColorTerra600),
    (dsColorTeal100, dsColorTeal700),
  ];

  static const List<(Color bg, Color icon)> _darkPalette = [
    (Color(0xFF1E2E5A), dsColorIndigo300),
    (Color(0xFF0C3829), dsColorEmerald400),
    (Color(0xFF3D2E0C), dsColorAmber300),
    (Color(0xFF2D1A50), dsColorViolet500),
    (Color(0xFF3D1A0C), dsColorTerra400),
    (Color(0xFF0C3030), dsColorTeal500),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = album.id.hashCode.abs() % _palette.length;
    final (placeholderBg, iconColor) =
        isDark ? _darkPalette[idx] : _palette[idx];

    final coverUrlAsync = album.coverKey != null
        ? ref.watch(albumCoverUrlProvider(album.coverKey!))
        : null;

    return DSScalePress(
      onTap: () => context.push('/gallery/album', extra: album),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowMd,
          border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dsRadiusCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover / placeholder
              SizedBox(
                height: 110,
                width: double.infinity,
                child: coverUrlAsync?.valueOrNull != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrlAsync!.valueOrNull!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _PlaceholderCover(
                          bg: placeholderBg,
                          iconColor: iconColor,
                        ),
                        errorWidget: (_, __, ___) => _PlaceholderCover(
                          bg: placeholderBg,
                          iconColor: iconColor,
                        ),
                      )
                    : _PlaceholderCover(
                        bg: placeholderBg,
                        iconColor: iconColor,
                      ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(dsSpace3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        album.title,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(13),
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? dsDarkTextPrimary
                              : dsTextPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Photo count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? placeholderBg : placeholderBg,
                          borderRadius:
                              BorderRadius.circular(dsRadiusFull),
                        ),
                        child: Text(
                          '${album.photoCount} photo${album.photoCount == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(10),
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                      if (album.eventDate != null) ...[
                        const SizedBox(height: dsSpace1),
                        Row(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: context.si(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                            const SizedBox(width: dsSpace1),
                            Text(
                              DateFormat('d MMM y')
                                  .format(album.eventDate!),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(11),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final Color bg;
  final Color iconColor;

  const _PlaceholderCover({required this.bg, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: Center(
        child: Icon(
          Icons.photo_library_outlined,
          size: context.si(40),
          color: iconColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create album modal (exec-only)
// ---------------------------------------------------------------------------

class _CreateAlbumModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateAlbumModal({required this.onCreated});

  @override
  ConsumerState<_CreateAlbumModal> createState() =>
      _CreateAlbumModalState();
}

class _CreateAlbumModalState
    extends ConsumerState<_CreateAlbumModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _eventDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _eventDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(galleryRepositoryProvider).createAlbum(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            eventDate: _eventDate,
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Album created',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: dsColorRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(effectiveDarkProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final textPrimary =
        isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary =
        isDark ? dsDarkTextSecondary : dsTextSecondary;
    final borderColor =
        isDark ? dsDarkBorderLight : dsBorderLight;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(dsRadiusXxl)),
        ),
        padding: const EdgeInsets.fromLTRB(
            dsSpace5, dsSpace4, dsSpace5, dsSpace8),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: dsSpace4),
              Text(
                'Create Album',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(17),
                  fontWeight: FontWeight.w700,
                  color: dsColorIndigo600,
                ),
              ),
              const SizedBox(height: dsSpace4),

              // Title
              _ModalField(
                controller: _titleCtrl,
                label: 'Album Title *',
                isDark: isDark,
                maxLength: 255,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => InputValidators.shortText(v, label: 'Album title', max: 255),
              ),
              const SizedBox(height: dsSpace3),

              // Description
              _ModalField(
                controller: _descCtrl,
                label: 'Description (optional)',
                isDark: isDark,
                maxLines: 2,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => InputValidators.optionalText(v, max: 500),
              ),
              const SizedBox(height: dsSpace3),

              // Event date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4, vertical: dsSpace3),
                  decoration: BoxDecoration(
                    color:
                        isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
                    borderRadius: BorderRadius.circular(dsRadiusMd),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: context.si(18),
                        color: textSecondary,
                      ),
                      const SizedBox(width: dsSpace2),
                      Expanded(
                        child: Text(
                          _eventDate != null
                              ? DateFormat('d MMM yyyy')
                                  .format(_eventDate!)
                              : 'Event Date (optional)',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            color: _eventDate != null
                                ? textPrimary
                                : textSecondary,
                          ),
                        ),
                      ),
                      if (_eventDate != null)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _eventDate = null),
                          child: Icon(Icons.close_rounded,
                              size: context.si(16),
                              color: textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: dsSpace5),

              // Submit button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(dsRadiusButton),
                  boxShadow: dsShadowBrand,
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dsColorIndigo600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        vertical: dsSpace4),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(dsRadiusButton),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create Album',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: context.sp(15),
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
}

class _ModalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _ModalField({
    required this.controller,
    required this.label,
    required this.isDark,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(
        fontSize: context.sp(14),
        color: textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: context.sp(13),
          color: textSecondary,
        ),
        filled: true,
        fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide:
              const BorderSide(color: dsColorIndigo600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: const BorderSide(color: dsColorRed600),
        ),
      ),
      validator: validator,
    );
  }
}
