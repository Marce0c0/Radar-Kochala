
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: 'env.txt');
  final supabase = SupabaseClient(
    dotenv.env['SUPABASE_URL']!,
    dotenv.env['SUPABASE_ANON_KEY']!,
  );
  try {
    // Attempting to read using anon key will be restricted by RLS
    print('Attempting to read policies directly... cannot do without service role.');
  } catch(e) {
    print('ERROR: ');
  }
}
