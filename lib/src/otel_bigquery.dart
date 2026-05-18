// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_bigquery_suppression.dart';

const _tracerName = 'dartastic_otel_libs_bigquery';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

const _maxStatementLength = 1024;
String _truncate(String s) =>
    s.length <= _maxStatementLength ? s : s.substring(0, _maxStatementLength);

/// Pair returned from `tracedBigqueryQuery` callback.
class BigqueryQueryResult<T> {
  const BigqueryQueryResult({
    required this.value,
    this.jobId,
    this.totalBytesProcessed,
    this.totalRows,
    this.cacheHit,
  });
  final T value;
  final String? jobId;
  final int? totalBytesProcessed;
  final int? totalRows;
  final bool? cacheHit;
}

/// Wraps a BigQuery SQL query in a CLIENT span using OTel db.*
/// semconv (db.system=bigquery). Records job id, total bytes
/// processed, total rows, and cache_hit.
Future<T> tracedBigqueryQuery<T>({
  required String statement,
  required String project,
  required Future<BigqueryQueryResult<T>> Function() invoke,
  String? location,
  String? dataset,
}) async {
  if (bigqueryInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': 'bigquery',
    'db.operation': _operationFromStatement(statement) ?? 'query',
    'db.statement': _truncate(statement),
    'gcp.project_id': project,
  };
  if (dataset != null) m['bigquery.dataset'] = dataset;
  if (location != null) m['bigquery.location'] = location;

  final span = _tracer().startSpan(
    'bigquery ${m['db.operation']}',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    final extras = <Attribute<Object>>[];
    if (r.jobId != null) {
      extras.add(OTel.attributeString('bigquery.job.id', r.jobId!));
    }
    if (r.totalBytesProcessed != null) {
      extras.add(OTel.attributeInt(
        'bigquery.total_bytes_processed',
        r.totalBytesProcessed!,
      ));
    }
    if (r.totalRows != null) {
      extras.add(OTel.attributeInt('db.row_count', r.totalRows!));
    }
    if (r.cacheHit != null) {
      extras.add(OTel.attributeBool('bigquery.cache_hit', r.cacheHit!));
    }
    if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

String? _operationFromStatement(String statement) {
  final trimmed = statement.trimLeft();
  if (trimmed.isEmpty) return null;
  final first = trimmed.split(RegExp(r'\s+')).first.toUpperCase();
  const known = {
    'SELECT',
    'INSERT',
    'UPDATE',
    'DELETE',
    'CREATE',
    'ALTER',
    'DROP',
    'TRUNCATE',
    'COPY',
    'MERGE',
    'WITH',
    'CALL',
    'EXPORT',
    'BEGIN',
  };
  return known.contains(first) ? first : null;
}
