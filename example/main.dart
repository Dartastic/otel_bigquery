// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_bigquery/otel_bigquery.dart';

/// Traces Bigquery calls with OpenTelemetry.
///
/// `otel_bigquery` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Bigquery call in
/// [tracedBigqueryQuery]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'bigquery-example');

  // Wraps a BigQuery SQL query in a CLIENT span using OTel db.* semconv (db.system=bigquery).
  final bigqueryQueryId = await tracedBigqueryQuery<String>(
    statement: 'active',
    project: 'example',
    location: 'example',
    dataset: 'example',
    invoke: () async {
      // Make the Bigquery call here, then report what it returned.
      const id = 'bigquery_8f3a2c';
      return const BigqueryQueryResult(
          value: id,
          jobId: 'job_8f3a2c',
          totalBytesProcessed: 512,
          totalRows: 1,
          cacheHit: true);
    },
  );
  OTelLog.info('tracedBigqueryQuery returned $bigqueryQueryId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutBigqueryInstrumentationAsync.
  await runWithoutBigqueryInstrumentationAsync(
    () => tracedBigqueryQuery<String>(
      statement: 'active',
      project: 'example',
      location: 'example',
      dataset: 'example',
      invoke: () async {
        const id = 'bigquery_8f3a2c';
        return const BigqueryQueryResult(
            value: id,
            jobId: 'job_8f3a2c',
            totalBytesProcessed: 512,
            totalRows: 1,
            cacheHit: true);
      },
    ),
  );

  await OTel.shutdown();
}
