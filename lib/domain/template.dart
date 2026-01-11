import 'package:cloud_firestore/cloud_firestore.dart';

enum EntryTypeEnum { income, expense }

class TemplateItem {
  final String id;
  final String title;
  final EntryTypeEnum type;
  final int amount;
  final String? categoryId;
  final int? dayOfMonth;
  final String? note;
  final int order;

  TemplateItem({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    this.categoryId,
    this.dayOfMonth,
    this.note,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type == EntryTypeEnum.income ? 'income' : 'expense',
        'amount': amount,
        'categoryId': categoryId,
        'dayOfMonth': dayOfMonth,
        'note': note,
        'order': order,
      };

  factory TemplateItem.fromJson(Map<String, dynamic> json) => TemplateItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        type: (json['type']?.toString() ?? 'expense') == 'income' ? EntryTypeEnum.income : EntryTypeEnum.expense,
        amount: (json['amount'] is int) ? json['amount'] as int : int.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        categoryId: json['categoryId']?.toString(),
        dayOfMonth: json['dayOfMonth'] is int ? json['dayOfMonth'] as int : int.tryParse(json['dayOfMonth']?.toString() ?? '') ,
        note: json['note']?.toString(),
        order: json['order'] is int ? json['order'] as int : int.tryParse(json['order']?.toString() ?? '0') ?? 0,
      );
}

class Template {
  final String id;
  final String name;
  final String? description;
  final List<TemplateItem> items;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String createdBy;
  final Timestamp? lastAppliedAt;

  Template({
    required this.id,
    required this.name,
    this.description,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.lastAppliedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'createdBy': createdBy,
        'lastAppliedAt': lastAppliedAt,
      };

  factory Template.fromJson(Map<String, dynamic> json) => Template(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        items: (json['items'] as List<dynamic>?)?.map((e) => TemplateItem.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? [],
        createdAt: json['createdAt'] is Timestamp ? json['createdAt'] as Timestamp : Timestamp.now(),
        updatedAt: json['updatedAt'] is Timestamp ? json['updatedAt'] as Timestamp : Timestamp.now(),
        createdBy: json['createdBy']?.toString() ?? '',
        lastAppliedAt: json['lastAppliedAt'] is Timestamp ? json['lastAppliedAt'] as Timestamp : null,
      );
}

class ApplyOptions {
  final String duplicatePolicy; // 'skip'|'overwrite'|'allow'
  final bool autoCreateCategory;

  ApplyOptions({this.duplicatePolicy = 'skip', this.autoCreateCategory = true});
}

class ApplyResult {
  final int createdCount;
  final int skippedCount;
  final List<String> createdEntryIds;
  final List<String> errors;

  ApplyResult({required this.createdCount, required this.skippedCount, required this.createdEntryIds, required this.errors});
}