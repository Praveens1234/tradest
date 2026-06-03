class BacktestRun {
  final int runId;
  final int? eaId;
  final String status;
  final Map<String, dynamic> parameters;
  final String? startedAt;
  final String? finishedAt;
  final String? eaName;

  const BacktestRun({
    required this.runId,
    this.eaId,
    required this.status,
    required this.parameters,
    this.startedAt,
    this.finishedAt,
    this.eaName,
  });

  factory BacktestRun.fromJson(Map<String, dynamic> json) {
    return BacktestRun(
      runId: json['run_id'] as int? ?? json['runId'] as int? ?? 0,
      eaId: json['ea_id'] as int? ?? json['eaId'] as int?,
      status: json['status'] as String? ?? 'unknown',
      parameters: Map<String, dynamic>.from(
        json['parameters'] as Map? ?? {},
      ),
      startedAt: json['started_at'] as String? ?? json['startedAt'] as String?,
      finishedAt: json['finished_at'] as String? ?? json['finishedAt'] as String?,
      eaName: json['ea_name'] as String? ?? json['eaName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'run_id': runId,
      'ea_id': eaId,
      'status': status,
      'parameters': parameters,
      'started_at': startedAt,
      'finished_at': finishedAt,
      'ea_name': eaName,
    };
  }
}

class BacktestResult {
  final int runId;
  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> trades;
  final String? htmlPath;
  final String? xmlPath;
  final String? csvPath;

  const BacktestResult({
    required this.runId,
    required this.metrics,
    required this.trades,
    this.htmlPath,
    this.xmlPath,
    this.csvPath,
  });

  factory BacktestResult.fromJson(Map<String, dynamic> json) {
    final rawTrades = json['trades'] as List?;
    final trades = rawTrades
            ?.map((t) => Map<String, dynamic>.from(t as Map))
            .toList() ??
        [];

    return BacktestResult(
      runId: json['run_id'] as int? ?? json['runId'] as int? ?? 0,
      metrics: Map<String, dynamic>.from(json['metrics'] as Map? ?? {}),
      trades: trades,
      htmlPath: json['html_path'] as String? ?? json['htmlPath'] as String?,
      xmlPath: json['xml_path'] as String? ?? json['xmlPath'] as String?,
      csvPath: json['csv_path'] as String? ?? json['csvPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'run_id': runId,
      'metrics': metrics,
      'trades': trades,
      'html_path': htmlPath,
      'xml_path': xmlPath,
      'csv_path': csvPath,
    };
  }
}
