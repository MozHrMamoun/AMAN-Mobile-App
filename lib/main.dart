import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://qhdatsjtgbbiwpinrtmr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoZGF0c2p0Z2JiaXdwaW5ydG1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzMTA5MzQsImV4cCI6MjA4NTg4NjkzNH0.yyEr6k1-9sZUV0TdFEov7PP__37nikzdku6RI67stKI',
  );
  runApp(const AmanApp());
}
