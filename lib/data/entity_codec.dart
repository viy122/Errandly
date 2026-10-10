import '../models/entities.dart';
import '../models/proof_image.dart';
import '../models/geo.dart';

Map<String, dynamic> profileJson(UserProfile u) => {
  'id': u.id,
  'name': u.name,
  'email': u.email,
  'phone': u.phone,
  'location': u.location,
  'bio': u.bio,
  'photo': u.photo,
  'emailVerified': u.emailVerified,
  'phoneVerified': u.phoneVerified,
  'idVerified': u.idVerified,
  'locationAllowed': u.locationAllowed,
  'phonePrivacy': u.phonePrivacy,
  'emailPrivacy': u.emailPrivacy,
};

Map<String, dynamic> errandJson(Errand e) => {
  'id': e.id,
  'title': e.title,
  'category': e.category,
  'description': e.description,
  'pickup': e.pickup,
  'destination': e.destination,
  'area': e.area,
  'transport': e.transport,
  'instructions': e.instructions,
  'budget': e.budget,
  'fee': e.fee,
  'distance': e.distance,
  'pickupPoint': e.pickupPoint?.toJson(),
  'destinationPoint': e.destinationPoint?.toJson(),
  'distanceSource': e.distanceSource,
  'routeSeconds': e.routeSeconds,
  'deadline': e.deadline.toUtc().toIso8601String(),
  'urgent': e.urgent,
};

UserProfile profileFromJson(Map<String, dynamic> j) =>
    UserProfile(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        phone: j['phone'],
        location: j['location'],
        bio: j['bio'],
        password: '',
        rating: (j['rating'] as num).toDouble(),
        completed: j['completed'],
        verified: j['verified'],
      )
      ..photo = j['photo']
      ..emailVerified = j['emailVerified']
      ..phoneVerified = j['phoneVerified']
      ..idVerified = j['idVerified']
      ..locationAllowed = j['locationAllowed']
      ..phonePrivacy = j['phonePrivacy']
      ..emailPrivacy = j['emailPrivacy'];

Errand errandFromJson(Map<String, dynamic> j, {Errand? existing}) {
  // Preserve references held by an open task/chat dialog.
  final e =
      existing ??
      Errand(
        id: j['id'],
        ownerId: j['ownerId'],
        title: j['title'],
        category: j['category'],
        description: j['description'],
        pickup: j['pickup'],
        destination: j['destination'],
        area: j['area'],
        transport: j['transport'],
        instructions: j['instructions'],
        budget: (j['budget'] as num).toDouble(),
        fee: (j['fee'] as num).toDouble(),
        distance: (j['distance'] as num).toDouble(),
        pickupPoint: GeoPoint.parse(j['pickupPoint']),
        destinationPoint: GeoPoint.parse(j['destinationPoint']),
        distanceSource: j['distanceSource'] as String? ?? 'manual',
        routeSeconds: (j['routeSeconds'] as num?)?.toDouble(),
        deadline: DateTime.parse(j['deadline']).toLocal(),
        postedAt: DateTime.parse(j['postedAt']).toLocal(),
        urgent: j['urgent'],
        pesoPurchase: j['budgetCurrency'] == 'PHP',
      );
  e
    ..status = ErrandStatus.values.byName(j['status'])
    ..runnerId = j['runnerId']
    ..progress = j['progress']
    ..actualCost = (j['actualCost'] as num?)?.toDouble()
    ..receipt = j['receipt']
    ..itemPhoto = j['itemPhoto']
    ..handoffVerified = j['handoffVerified']
    ..pin = j['pin']
    ..cancellationReason = j['cancellationReason']
    ..pinAttempts = (j['pinAttempts'] as num?)?.toInt() ?? 0
    ..pinResetAt = j['pinResetAt'] == null
        ? null
        : DateTime.parse(j['pinResetAt']).toLocal()
    ..cancelRequestedBy = j['cancelRequestedBy']
    ..cancelRefundCoins = (j['cancelRefundCoins'] as num?)?.toDouble()
    ..cancelRefundPurchase = (j['cancelRefundPurchase'] as num?)?.toDouble()
    ..cancelRunnerPayment = (j['cancelRunnerPayment'] as num?)?.toDouble();
  e.history.clear();
  e.proofFiles
    ..clear()
    ..addAll(
      (j['proofFiles'] as List? ?? []).map(
        (f) => ProofImage.fromJson(Map<String, dynamic>.from(f)),
      ),
    );
  for (final h in (j['history'] as Map<String, dynamic>).entries) {
    e.history[int.parse(h.key)] = DateTime.parse(h.value).toLocal();
  }
  return e;
}
