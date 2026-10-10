import 'dart:math';

import 'proof_image.dart';
import 'geo.dart';

const categories = [
  'All',
  'Purchase',
  'Delivery',
  'Printing',
  'Document Submission',
  'Pickup',
  'Queueing',
  'Food',
  'School Supplies',
  'Others',
];
const travelMethods = [
  'On foot',
  'Bicycle',
  'Motorcycle',
  'Car',
  'Public transport',
  'Courier / Shipping',
];
const progressLabels = [
  'Accepted',
  'Going to Pickup / Store',
  'At Pickup / Store',
  'Item Purchased / Picked Up',
  'On the Way',
  'Arrived',
  'Waiting for Confirmation',
  'Completed',
];
String money(num v) => (v - v.roundToDouble()).abs() < .000001
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(2);
String timeLabel(DateTime d) =>
    '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
String distanceLabel(double meters) =>
    meters >= 1000 ? '${money(meters / 1000)} km' : '${money(meters)} m';
String deadlineLabel(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day
      ? timeLabel(date)
      : '${date.month}/${date.day} · ${timeLabel(date)}';
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '09171234567',
    this.bio =
        'A little help goes a long way. Happy to help with everyday errands!',
    this.location = 'Nasugbu, Batangas',
    this.rating = 4.9,
    this.completed = 47,
    this.verified = true,
    this.password = 'demo123',
  });
  final String id;
  String name, email, phone, bio, password, location;
  double rating;
  int completed;
  bool verified;
  bool emailVerified = false,
      phoneVerified = false,
      idVerified = false,
      locationAllowed = false,
      photo = false;
  String phonePrivacy = 'Private', emailPrivacy = 'Private';
  String get firstName => name.split(' ').first;
  String get initials => name.split(' ').take(2).map((n) => n[0]).join();
}

enum ErrandStatus {
  posted,
  accepted,
  ongoing,
  waiting,
  completed,
  cancelled,
  expired,
}

class Errand {
  Errand({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.category,
    required this.description,
    required this.pickup,
    required this.destination,
    required this.budget,
    required this.fee,
    required this.distance,
    required this.deadline,
    this.pesoPurchase = true,
    this.urgent = false,
    this.area = 'Nasugbu, Batangas',
    this.transport = 'On foot',
    this.instructions = 'Please message me when you arrive. Thank you!',
    this.pickupPoint,
    this.destinationPoint,
    this.distanceSource = 'manual',
    this.routeSeconds,
    DateTime? postedAt,
  }) : postedAt = postedAt ?? DateTime.now();
  final String id,
      ownerId,
      title,
      category,
      description,
      pickup,
      destination,
      instructions,
      area,
      transport;
  final double budget, fee, distance;
  final GeoPoint? pickupPoint, destinationPoint;
  final String distanceSource;
  final double? routeSeconds;
  final DateTime deadline, postedAt;
  final bool urgent;
  final bool pesoPurchase;
  double get serviceFee => 5;

  /// Coins secured; peso purchase funds are paid separately.
  double get total => (pesoPurchase ? 0 : budget) + fee + serviceFee;
  ErrandStatus status = ErrandStatus.posted;
  String? runnerId;
  int progress = -1;
  final Map<int, DateTime> history = {};
  double? actualCost;
  bool receipt = false, itemPhoto = false, handoffVerified = false;
  final List<ProofImage> proofFiles = [];
  ProofImage? proof(String kind) {
    for (final file in proofFiles) {
      if (file.kind == kind) return file;
    }
    return null;
  }

  String? pin, cancellationReason;
  int pinAttempts = 0;
  DateTime? pinResetAt;
  String? cancelRequestedBy;
  double? cancelRefundCoins, cancelRefundPurchase, cancelRunnerPayment;
  bool get cancellationPending => cancelRequestedBy != null && !terminal;
  bool get needsCancellationReview =>
      progress >= 3 || receipt || itemPhoto || (actualCost ?? 0) > 0;
  bool get available =>
      status == ErrandStatus.posted && deadline.isAfter(DateTime.now());
  bool get terminal => [
    ErrandStatus.completed,
    ErrandStatus.cancelled,
    ErrandStatus.expired,
  ].contains(status);
  double get refund => budget - (actualCost ?? budget);
  String purchaseAmount(num value) =>
      pesoPurchase ? '₱${money(value)}' : '${money(value)} CY';
  String get label => status.name.toUpperCase();
  void makePin() =>
      pin ??= (100000 + Random.secure().nextInt(900000)).toString();
}

class Wallet {
  Wallet(this.available, {this.totalEarnings = 0});
  double available, totalEarnings;
  double refunds = 0;
}

class WalletEntry {
  static int _localReference = 0;
  WalletEntry(
    this.userId,
    this.type,
    this.amount,
    this.note, {
    this.status = 'Completed',
    this.currency = 'CY',
    String? id,
    this.errandId,
    this.pesoAmount,
    DateTime? date,
  }) : date = date ?? DateTime.now(),
       id =
           id ??
           'LOCAL-${DateTime.now().microsecondsSinceEpoch}-${_localReference++}';
  final String id;
  final String? errandId;
  final double? pesoAmount;
  final String userId, type, note, status, currency;
  final double amount;
  final DateTime date;
}

class Notice {
  Notice(
    this.userId,
    this.type,
    this.text, {
    this.errandId,
    this.id,
    DateTime? date,
  }) : date = date ?? DateTime.now();
  final String? id;
  final String userId, type, text;
  final String? errandId;
  final DateTime date;
  bool read = false;
}

class ChatMessage {
  ChatMessage(
    this.errandId,
    this.senderId,
    this.text, {
    DateTime? date,
    this.recipientId,
  }) : date = date ?? DateTime.now();
  final String errandId, senderId, text;
  final String? recipientId;
  final DateTime date;
}

class Review {
  Review(
    this.errandId,
    this.fromId,
    this.toId,
    this.stars,
    this.text,
    this.scores,
  );
  final String errandId, fromId, toId, text;
  final int stars;
  final Map<String, int> scores;
}

class Report {
  Report(
    this.userId,
    this.reason,
    this.description, {
    this.errandId,
    this.evidence = false,
    this.id,
  });
  final String? id;
  final String userId, reason, description;
  final String? errandId;
  final bool evidence;
  String status = 'Submitted';
}
