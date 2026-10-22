// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_bigquery/otel_bigquery.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_bigquery-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('SELECT records CLIENT span', () async {
    await tracedBigqueryQuery<String>(
      statement: 'SELECT 1',
      project: 'my-proj',
      dataset: 'analytics',
      location: 'US',
      invoke: () async => const BigqueryQueryResult(
        value: 'rows',
        jobId: 'job-1',
        totalBytesProcessed: 1024,
        totalRows: 1,
        cacheHit: false,
      ),
    );
    final a = attrsOf(spans.findSpanByName('bigquery SELECT')!);
    expect(a['db.system'], 'bigquery');
    expect(a['db.operation'], 'SELECT');
    expect(a['gcp.project_id'], 'my-proj');
    expect(a['bigquery.dataset'], 'analytics');
    expect(a['bigquery.location'], 'US');
    expect(a['bigquery.job.id'], 'job-1');
    expect(a['bigquery.total_bytes_processed'], 1024);
    expect(a['db.row_count'], 1);
    expect(a['bigquery.cache_hit'], false);
  });

  test('suppression skips spans', () async {
    await runWithoutBigqueryInstrumentationAsync(() async {
      await tracedBigqueryQuery<String>(
        statement: 'SELECT 1',
        project: 'p',
        invoke: () async => const BigqueryQueryResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('bigquery '), isEmpty);
  });
}
