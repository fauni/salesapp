part of 'series_bloc.dart';

sealed class SeriesEvent extends Equatable {
  const SeriesEvent();
  @override
  List<Object?> get props => [];
}

class SeriesLoadRequested extends SeriesEvent {
  const SeriesLoadRequested();
}
