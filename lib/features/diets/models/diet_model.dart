
class Diet {
  final String id;
  final String memberId;
  final String trainerId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final List<DietItem> items;
  final DateTime createdAt;

  Diet({
    required this.id,
    required this.memberId,
    required this.trainerId,
    required this.startDate,
    this.endDate,
    this.items = const [],
    this.notes,
    required this.createdAt,
  });

  factory Diet.fromJson(Map<String, dynamic> json) {
    return Diet(
      id: json['id'],
      memberId: json['member_id'],
      trainerId: json['trainer_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      items: json['diet_items'] != null
          ? (json['diet_items'] as List).map((i) => DietItem.fromJson(i)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'member_id': memberId,
      'trainer_id': trainerId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'notes': notes,
    };
  }

  int get totalCalories {
    return items.fold(0, (sum, item) => sum + (item.calories ?? 0));
  }
}

class DietItem {
  final String? id;
  final String? dietId;
  final String mealName; // e.g., 'Breakfast'
  final String content;
  final int? calories;
  final int orderIndex;

  DietItem({
    this.id,
    this.dietId,
    required this.mealName,
    required this.content,
    this.calories,
    required this.orderIndex,
  });

  factory DietItem.fromJson(Map<String, dynamic> json) {
    return DietItem(
      id: json['id'],
      dietId: json['diet_id'],
      mealName: json['meal_name'],
      content: json['content'],
      calories: json['calories'],
      orderIndex: json['order_index'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (dietId != null) 'diet_id': dietId,
      'meal_name': mealName,
      'content': content,
      'calories': calories,
      'order_index': orderIndex,
    };
  }
}
