import 'package:flutter/material.dart';
import 'package:report_flutter/report_flutter.dart';

import 'print_data.dart';
import 'print_job.dart';

/// "Templates and print" section: the report_flutter print center on the
/// shop library kept on MGWS, with the shop data. Labels requested from the
/// products list arrive through [pendingPrintJob].
class PrintCenterPage extends StatelessWidget {
  const PrintCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrintCenter(
      library: printLibrary,
      dataProvider: const ShopPrintDataProvider(),
      pendingJob: pendingPrintJob,
    );
  }
}
