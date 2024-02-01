import 'package:acter/features/bug_report/pages/bug_report_page.dart';
import 'package:acter/features/home/data/keys.dart';
import 'package:acter/features/home/pages/home_shell.dart';
import 'package:acter/features/search/model/keys.dart';
import 'package:convenient_test_dev/convenient_test_dev.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../support/login.dart';
import '../support/setup.dart';
import '../support/util.dart';

const rageshakeListUrl = String.fromEnvironment(
  'RAGESHAKE_LISTING_URL',
  defaultValue: '',
);

RegExp hrefRegExp = RegExp(r'href="(.*?)"');

Future<List<String>> latestReported() async {
  final DateTime now = DateTime.now();
  final DateFormat formatter = DateFormat('yyyy-MM-dd');
  final String formatted = formatter.format(now);
  final fullBaseUrl = '$rageshakeListUrl/$formatted';
  final url = Uri.parse(fullBaseUrl);
  debugPrint('Reading from $url');

  var response = await http.get(url);
  debugPrint('Response status: ${response.statusCode}');
  if (response.statusCode == 404) {
    return [];
  }

  return hrefRegExp.allMatches(response.body).map((e) {
    final inner = e[1];
    return '$inner';
  }).toList();
}

Future<List<String>> inspectReport(String reportName) async {
  debugPrint('fetching report $reportName');
  final DateTime now = DateTime.now();
  final DateFormat formatter = DateFormat('yyyy-MM-dd');
  final String formatted = formatter.format(now);
  final fullBaseUrl = '$rageshakeListUrl/$formatted/$reportName/';
  final url = Uri.parse(fullBaseUrl);
  debugPrint('Reading from $url');

  var response = await http.get(url);
  debugPrint('Response status: ${response.statusCode}');
  if (response.statusCode == 404) {
    throw 'report not found at $fullBaseUrl';
  }

  return hrefRegExp.allMatches(response.body).map((e) {
    final inner = e[1];
    return '$inner';
  }).toList();
}

void bugReporterTests() {
  acterTestWidget('Can report bug', (t) async {
    if (rageshakeListUrl.isEmpty) {
      throw const Skip('Provide RAGESHAKE_LISTING_URL to run this test');
    }
    final prevReports = await latestReported();
    final page = find.byKey(BugReportPage.pageKey);
    // totally clean
    await t.freshAccount();
    await t.navigateTo([
      MainNavKeys.quickJump,
      QuickJumpKeys.bugReport,
    ]);

    await page.should(findsOne);
    await t.fillForm({
      BugReportPage.titleField: 'My first bug report',
    });
    final btn = find.byKey(BugReportPage.submitBtn);
    await btn.tap();
    // disappears when submission was successful
    await page.should(findsNothing);

    final latestReports = await latestReported();

    // successfully submitted
    assert(prevReports.length < latestReports.length);

    // ensure the title was reset.
    await t.navigateTo([
      MainNavKeys.quickJump,
      QuickJumpKeys.bugReport,
    ]);

    await page.should(findsOne);
    final title = find.byKey(BugReportPage.titleField).evaluate().first.widget
        as TextFormField;
    assert(title.controller!.text == '', "title field wasn't reset");

    final reportedFiles = await inspectReport(latestReports.last);
    assert(
      reportedFiles.any((element) => element.startsWith('details')),
      'No app details founds in files: $reportedFiles',
    );
    assert(
      reportedFiles.length == 1,
      'Not only details were sent: $reportedFiles',
    );
  });

  acterTestWidget('Can report bug with logs', (t) async {
    if (rageshakeListUrl.isEmpty) {
      throw const Skip('Provide RAGESHAKE_LISTING_URL to run this test');
    }
    final prevReports = await latestReported();
    final page = find.byKey(BugReportPage.pageKey);
    // totally clean
    await t.freshAccount();
    await t.navigateTo([
      MainNavKeys.quickJump,
      QuickJumpKeys.bugReport,
    ]);

    await page.should(findsOne);
    await t.fillForm({
      BugReportPage.titleField: 'My first bug report',
    });
    // turn on the log
    final withLog = find.byKey(BugReportPage.includeLog);
    await withLog.tap();

    final btn = find.byKey(BugReportPage.submitBtn);
    await btn.tap();
    // disappears when submission was successful
    await page.should(findsNothing);

    final latestReports = await latestReported();

    // successfully submitted
    assert(prevReports.length < latestReports.length);
    // we expect to be thrown to the news screen and see our latest item first:

    await btn.should(findsNothing);

    // ensure the title was reset.
    await t.navigateTo([
      MainNavKeys.quickJump,
      QuickJumpKeys.bugReport,
    ]);

    await page.should(findsOne);
    final title = find.byKey(BugReportPage.titleField).evaluate().first.widget
        as TextFormField;
    assert(title.controller!.text == '', "title field wasn't reset");

    final reportedFiles = await inspectReport(latestReports.last);
    assert(
      reportedFiles.any((element) => element.startsWith('details')),
      'No app details founds in files: $reportedFiles',
    );
    assert(
      reportedFiles.any((element) => element.startsWith('app_')),
      'No log found in files: $reportedFiles',
    );
    assert(
      reportedFiles.length == 2,
      'Not only details and log were sent: $reportedFiles',
    );
  });

  acterTestWidget('Can report bug with screenshot', (t) async {
    if (rageshakeListUrl.isEmpty) {
      throw const Skip('Provide RAGESHAKE_LISTING_URL to run this test');
    }
    final page = find.byKey(BugReportPage.pageKey);
    final prevReports = await latestReported();
    // totally clean
    await t.freshAccount();
    final HomeShellState home = t.tester.state(find.byKey(homeShellKey));
    // as if we shaked
    home.handleBugReport();

    await page.should(findsOne);

    final screenshot = find.byKey(BugReportPage.includeScreenshot);
    await screenshot.tap();

    // screenshot is shown
    await find.byKey(BugReportPage.screenshot).should(findsOneWidget);

    await t.fillForm({
      BugReportPage.titleField: 'bug report with screenshot',
    });

    final btn = find.byKey(BugReportPage.submitBtn);
    await btn.tap();
    // disappears when it was submitted.
    await page.should(findsNothing);

    final latestReports = await latestReported();

    // successfully submitted
    assert(prevReports.length < latestReports.length);
    // we expect to be thrown to the news screen and see our latest item first:

    final reportedFiles = await inspectReport(latestReports.last);
    assert(
      reportedFiles.any((element) => element.startsWith('screenshot')),
      'No screenshot founds in files: $reportedFiles',
    );
    assert(reportedFiles.length == 2,
        'Not only details and screenshot were sent: $reportedFiles');
  });
}
