part of 'staff_screen.dart';

// ─── Shared Sheet Helpers ─────────────────────────────────────────────────────

Widget sheetFieldLabel(
    String text, bool isDark, BuildContext context) {
  return Text(
    text,
    style: GoogleFonts.inter(
      fontSize: context.sp(12),
      fontWeight: FontWeight.w600,
      color: isDark ? dsDarkTextSecondary : dsTextSecondary,
    ),
  );
}

Widget _textField(
  TextEditingController ctrl,
  String hint,
  bool isDark,
  Color borderColor,
  BuildContext context, {
  int maxLines = 1,
}) {
  return TextField(
    controller: ctrl,
    maxLines: maxLines,
    textCapitalization: TextCapitalization.sentences,
    style: GoogleFonts.inter(
      fontSize: context.sp(14),
      color: isDark ? dsDarkTextPrimary : dsTextPrimary,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: context.sp(13),
        color: isDark ? dsDarkTextSecondary : dsTextSecondary,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide:
            const BorderSide(color: dsColorIndigo600, width: 1.5),
      ),
      filled: isDark,
      fillColor:
          isDark ? dsDarkSurfaceMuted : Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: dsSpace3, vertical: dsSpace3),
    ),
  );
}

InputDecoration _dropdownDec(
    bool isDark, Color borderColor, Color surface) {
  return InputDecoration(
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dsRadiusInput),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dsRadiusInput),
      borderSide:
          const BorderSide(color: dsColorIndigo600, width: 1.5),
    ),
    filled: isDark,
    fillColor: isDark ? dsDarkSurfaceMuted : Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(
        horizontal: dsSpace3, vertical: dsSpace3),
  );
}

Widget _datePickerBox(
    String label, bool isDark, Color borderColor, BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: dsSpace3, vertical: 11),
    decoration: BoxDecoration(
      color:
          isDark ? dsDarkSurfaceMuted : Colors.transparent,
      borderRadius: BorderRadius.circular(dsRadiusInput),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      children: [
        Icon(Icons.schedule_outlined,
            size: context.si(13),
            color: isDark
                ? dsDarkTextSecondary
                : dsTextSecondary),
        const SizedBox(width: dsSpace2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: context.sp(13),
            color: isDark ? dsDarkTextPrimary : dsTextPrimary,
          ),
        ),
      ],
    ),
  );
}

Widget _submitButton(String label, bool saving,
    VoidCallback onPressed, BuildContext context) {
  return SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: dsColorIndigo600,
        padding:
            const EdgeInsets.symmetric(vertical: dsSpace4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusButton),
        ),
      ),
      child: saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: context.sp(14),
              ),
            ),
    ),
  );
}
