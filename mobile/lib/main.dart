import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/supabase.dart' as env;
import 'core/security/certificate_pinning.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Install SPKI cert pinning before any HTTP traffic (skipped in debug mode
  // and when no pins are injected via --dart-define=SUPABASE_CERT_PIN_1=...).
  installCertificatePinning();

  await dotenv.load();

  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
  );

  // Pre-load Inter and Poppins before first frame to avoid visible font swap.
  await GoogleFonts.pendingFonts([
    GoogleFonts.inter(),
    GoogleFonts.poppins(),
  ]);

  runApp(const ProviderScope(child: UtamacsApp()));
}
