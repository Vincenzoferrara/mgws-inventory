import 'dart:io' show ProcessInfo;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Resident memory of the app in MB, for performance logs.
///
/// Null on the web build: browsers expose no process memory and
/// `ProcessInfo.currentRss` throws there, which would abort the code that
/// only wanted to log it.
int? residentMemoryMb() =>
    kIsWeb ? null : (ProcessInfo.currentRss / (1024 * 1024)).round();
