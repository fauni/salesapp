part of 'series_bloc.dart';

enum SeriesStatus { loading, success, failure }

class SeriesState extends Equatable {
  final SeriesStatus status;
  final List<SalesSeries> series;
  final String? error;

  const SeriesState({
    this.status = SeriesStatus.loading,
    this.series = const [],
    this.error,
  });

  SeriesState copyWith({
    SeriesStatus? status,
    List<SalesSeries>? series,
    String? error,
  }) {
    return SeriesState(
      status: status ?? this.status,
      series: series ?? this.series,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, series, error];
}
