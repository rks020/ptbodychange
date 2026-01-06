class Measurement {
  final String? id;
  final String memberId;
  final DateTime date;
  
  // Basic Measurements
  final double weight; // in kg
  final double height; // in cm
  final int? age;
  final double? bodyFatPercentage;
  final double? boneMass; // kg
  final double? waterPercentage; // %
  final int? metabolicAge;
  final double? visceralFatRating;
  final int? basalMetabolicRate; // kcal
  
  // Circumference Measurements (in cm)
  final double? chest;
  final double? waist;
  final double? hips;
  final double? leftArm;
  final double? rightArm;
  final double? leftThigh;
  final double? rightThigh;
  final double? shoulders;
  final double? neck;
  
  // Photos (Supabase Storage URLs)
  final String? frontPhotoUrl;
  final String? sidePhotoUrl;
  final String? backPhotoUrl;
  
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  Measurement({
    this.id,
    required this.memberId,
    required this.date,
    required this.weight,
    required this.height,
    this.age,
    this.bodyFatPercentage,
    this.boneMass,
    this.waterPercentage,
    this.metabolicAge,
    this.visceralFatRating,
    this.basalMetabolicRate,
    this.chest,
    this.waist,
    this.hips,
    this.leftArm,
    this.rightArm,
    this.leftThigh,
    this.rightThigh,
    this.shoulders,
    this.neck,
    this.frontPhotoUrl,
    this.sidePhotoUrl,
    this.backPhotoUrl,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });
  
  // For Supabase (snake_case)
  Map<String, dynamic> toSupabaseMap() {
    return {
      if (id != null) 'id': id,
      'member_id': memberId,
      'measurement_date': date.toIso8601String(),
      'weight': weight,
      'height': height,
      'age': age,
      'body_fat_percentage': bodyFatPercentage,
      'bone_mass': boneMass,
      'water_percentage': waterPercentage,
      'metabolic_age': metabolicAge,
      'visceral_fat_rating': visceralFatRating,
      'basal_metabolic_rate': basalMetabolicRate,
      'chest_cm': chest,
      'waist_cm': waist,
      'hips_cm': hips,
      'left_arm_cm': leftArm,
      'right_arm_cm': rightArm,
      'left_thigh_cm': leftThigh,
      'right_thigh_cm': rightThigh,
      'front_photo_url': frontPhotoUrl,
      'side_photo_url': sidePhotoUrl,
      'back_photo_url': backPhotoUrl,
      'notes': notes,
    };
  }
  
  factory Measurement.fromSupabaseMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'] as String?,
      memberId: map['member_id'] as String,
      date: DateTime.parse(map['measurement_date'] as String),
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      age: map['age'] != null ? (map['age'] as num).toInt() : null,
      bodyFatPercentage: map['body_fat_percentage'] != null 
          ? (map['body_fat_percentage'] as num).toDouble() 
          : null,
      boneMass: map['bone_mass'] != null ? (map['bone_mass'] as num).toDouble() : null,
      waterPercentage: map['water_percentage'] != null ? (map['water_percentage'] as num).toDouble() : null,
      metabolicAge: map['metabolic_age'] != null ? (map['metabolic_age'] as num).toInt() : null,
      visceralFatRating: map['visceral_fat_rating'] != null ? (map['visceral_fat_rating'] as num).toDouble() : null,
      basalMetabolicRate: map['basal_metabolic_rate'] != null ? (map['basal_metabolic_rate'] as num).toInt() : null,
      chest: map['chest_cm'] != null ? (map['chest_cm'] as num).toDouble() : null,
      waist: map['waist_cm'] != null ? (map['waist_cm'] as num).toDouble() : null,
      hips: map['hips_cm'] != null ? (map['hips_cm'] as num).toDouble() : null,
      leftArm: map['left_arm_cm'] != null ? (map['left_arm_cm'] as num).toDouble() : null,
      rightArm: map['right_arm_cm'] != null ? (map['right_arm_cm'] as num).toDouble() : null,
      leftThigh: map['left_thigh_cm'] != null ? (map['left_thigh_cm'] as num).toDouble() : null,
      rightThigh: map['right_thigh_cm'] != null ? (map['right_thigh_cm'] as num).toDouble() : null,
      shoulders: null, // Not in new schema
      neck: null, // Not in new schema
      frontPhotoUrl: map['front_photo_url'] as String?,
      sidePhotoUrl: map['side_photo_url'] as String?,
      backPhotoUrl: map['back_photo_url'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : null,
    );
  }
  
  // Calculate BMI
  double get bmi => weight / ((height / 100) * (height / 100));
  
  // Calculate percentage change from another measurement
  double calculateWeightChange(Measurement other) {
    return ((weight - other.weight) / other.weight) * 100;
  }
  
  double? calculateCircumferenceChange(String measurement, Measurement other) {
    double? current;
    double? previous;
    
    switch (measurement) {
      case 'chest':
        current = chest;
        previous = other.chest;
        break;
      case 'waist':
        current = waist;
        previous = other.waist;
        break;
      case 'hips':
        current = hips;
        previous = other.hips;
        break;
      case 'leftArm':
        current = leftArm;
        previous = other.leftArm;
        break;
      case 'rightArm':
        current = rightArm;
        previous = other.rightArm;
        break;
      case 'leftThigh':
        current = leftThigh;
        previous = other.leftThigh;
        break;
      case 'rightThigh':
        current = rightThigh;
        previous = other.rightThigh;
        break;
    }
    
    if (current != null && previous != null && previous != 0) {
      return ((current - previous) / previous) * 100;
    }
    return null;
  }
}
