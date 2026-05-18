import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/supabase.dart' as env;

const _sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.tracesSampleRate = 0.2;
      // Strip personal data before sending to comply with DPDPA 2023.
      options.beforeSend = (event, hint) => event.copyWith(user: null);
    },
    appRunner: () => runApp(const ProviderScope(child: UtamacsApp())),
  );
}
