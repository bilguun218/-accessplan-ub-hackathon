class OrganizationReview {
  final String author;
  final double rating;
  final String text;
  final String date;

  const OrganizationReview({
    required this.author,
    required this.rating,
    required this.text,
    required this.date,
  });
}

class Organization {
  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final bool openNow;
  final String price;
  final String address;
  final String phone;
  final String hours;
  final List<String> tags;
  final List<String> accessibility;
  final List<OrganizationReview> reviews;
  final double latitude;
  final double longitude;
  final int priority;

  const Organization({
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.openNow,
    required this.price,
    required this.address,
    required this.phone,
    required this.hours,
    required this.tags,
    required this.accessibility,
    required this.reviews,
    required this.latitude,
    required this.longitude,
    this.priority = 0,
  });
}
