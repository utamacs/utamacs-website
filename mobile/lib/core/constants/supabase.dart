import 'package:flutter_dotenv/flutter_dotenv.dart';

final supabaseUrl = dotenv.env['SUPABASE_URL']!;
final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
final societyId = dotenv.env['SOCIETY_ID'] ?? '00000000-0000-0000-0000-000000000001';
