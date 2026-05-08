class PlacePredictionModel {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePredictionModel({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePredictionModel.fromJson(Map<String, dynamic> json) {
    return PlacePredictionModel(
      placeId: json['placeId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mainText: json['mainText']?.toString() ?? '',
      secondaryText: json['secondaryText']?.toString() ?? '',
    );
  }
}
