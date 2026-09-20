import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'services/offline_recipes.dart';

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String normalized(String value) {
  var text = value.toLowerCase();
  const accented = 'áéíóúüñ';
  const plain = 'aeiouun';
  for (var i = 0; i < accented.length; i++) {
    text = text.replaceAll(accented[i], plain[i]);
  }
  return text
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool ingredientMatches(String ingredient, String product) {
  return OfflineRecipes.ingredientMatches(ingredient, product);
}

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
String shortDate(DateTime date) =>
    '${const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'][date.weekday - 1]} ${date.day}/${date.month}';
String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
int notificationId(String id) =>
    id.codeUnits.fold(17, (value, char) => ((value * 31) + char) & 0x3fffffff);
double number(Object? value, [double fallback = 0]) =>
    (value is num ? value.toDouble() : double.tryParse('$value'))?.isFinite ==
        true
    ? (value is num ? value.toDouble() : double.parse('$value'))
    : fallback;

enum StockState { enough, low, empty }

class AppProduct {
  AppProduct({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'Comida',
    this.unit = 'pieza',
    this.amount = 1,
    this.stock = 1,
    this.lowAt = 1,
    this.referencePrice = 0,
    this.photo,
  });
  final String id, name, description, category, unit;
  final double amount, referencePrice;
  int stock;
  final int lowAt;
  final Uint8List? photo;
  StockState get stockState => stock <= 0
      ? StockState.empty
      : stock <= lowAt
      ? StockState.low
      : StockState.enough;
  String get presentation =>
      '${amount == amount.roundToDouble() ? amount.toInt() : amount} $unit';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'unit': unit,
    'amount': amount,
    'stock': stock,
    'lowAt': lowAt,
    'referencePrice': referencePrice,
    'photo': photo == null ? null : base64Encode(photo!),
  };
  factory AppProduct.fromJson(Map<String, dynamic> json) {
    Uint8List? photo;
    try {
      if (json['photo'] is String) photo = base64Decode(json['photo']);
    } catch (_) {
      /* A damaged image must not hide the product. */
    }
    return AppProduct(
      id: '${json['id'] ?? newId()}',
      name: '${json['name'] ?? 'Producto'}',
      description: '${json['description'] ?? ''}',
      category: '${json['category'] ?? 'Hogar'}',
      unit: '${json['unit'] ?? 'pieza'}',
      amount: number(json['amount'], 1).clamp(0.001, 1000000).toDouble(),
      stock: number(json['stock']).round().clamp(0, 99999),
      lowAt: number(json['lowAt'], 1).round().clamp(0, 99999),
      referencePrice: number(
        json['referencePrice'],
      ).clamp(0, 100000000).toDouble(),
      photo: photo,
    );
  }
}

class ShoppingEntry {
  ShoppingEntry({
    required this.id,
    required this.name,
    this.note = '',
    this.urgent = false,
    this.quantity = 1,
  });
  final String id, name, note;
  final bool urgent;
  final int quantity;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'urgent': urgent,
    'quantity': quantity,
  };
  factory ShoppingEntry.fromJson(Map<String, dynamic> json) => ShoppingEntry(
    id: '${json['id'] ?? newId()}',
    name: '${json['name'] ?? ''}',
    note: '${json['note'] ?? ''}',
    urgent: json['urgent'] == true,
    quantity: number(json['quantity'], 1).round().clamp(1, 99999),
  );
}

class TodoEntry {
  TodoEntry({
    required this.id,
    required this.title,
    required this.date,
    this.notes = '',
    this.done = false,
    this.remind = true,
  });
  final String id, title, notes;
  final DateTime date;
  bool done;
  final bool remind;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'notes': notes,
    'done': done,
    'remind': remind,
  };
  factory TodoEntry.fromJson(Map<String, dynamic> json) => TodoEntry(
    id: '${json['id'] ?? newId()}',
    title: '${json['title'] ?? 'Pendiente'}',
    date:
        DateTime.tryParse('${json['date']}') ??
        dayOnly(
          DateTime.now(),
        ).add(Duration(days: json['when'] == 'Esta semana' ? 1 : 0, hours: 10)),
    notes: '${json['notes'] ?? ''}',
    done: json['done'] == true,
    remind: json['remind'] != false,
  );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    this.ingredientKeys = const [],
    this.minutes = '25 min',
    this.servings = '2',
    this.tag = 'Casera',
    this.videoUrl = '',
    this.image = '',
    this.equipment = const [],
    this.allergens = const [],
    this.notes = const [],
    this.cuisine = '',
    this.source = '',
    this.sourceUrl = '',
    this.imageCaption = '',
  });
  final String id,
      title,
      description,
      minutes,
      servings,
      tag,
      videoUrl,
      image,
      cuisine,
      source,
      sourceUrl,
      imageCaption;
  final List<String> ingredients,
      ingredientKeys,
      steps,
      equipment,
      allergens,
      notes;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'ingredients': ingredients,
    'ingredientKeys': ingredientKeys,
    'steps': steps,
    'minutes': minutes,
    'servings': servings,
    'tag': tag,
    'videoUrl': videoUrl,
    'image': image,
    'equipment': equipment,
    'allergens': allergens,
    'notes': notes,
    'cuisine': cuisine,
    'source': source,
    'sourceUrl': sourceUrl,
    'imageCaption': imageCaption,
  };
  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList()
        : [];
    return Recipe(
      id: '${json['id'] ?? json['title'] ?? newId()}',
      title: '${json['title'] ?? 'Receta casera'}',
      description: '${json['description'] ?? ''}',
      ingredients: strings(json['ingredients']),
      ingredientKeys: strings(json['ingredientKeys']),
      steps: strings(json['steps']),
      minutes: '${json['minutes'] ?? '${json['time'] ?? 25} min'}',
      servings: '${json['servings'] ?? 2}',
      tag: '${json['tag'] ?? json['category'] ?? 'Casera'}',
      videoUrl: '${json['videoUrl'] ?? ''}',
      image: '${json['image'] ?? ''}',
      equipment: strings(json['equipment']),
      allergens: strings(json['allergens']),
      notes: strings(json['notes']),
      cuisine: '${json['cuisine'] ?? ''}',
      source: '${json['source'] ?? ''}',
      sourceUrl: '${json['sourceUrl'] ?? ''}',
      imageCaption: '${json['imageCaption'] ?? ''}',
    );
  }
  bool get allowed {
    return OfflineRecipes.isRecipeAllowed(toJson());
  }

  List<String> missing(List<AppProduct> products) {
    return OfflineRecipes.missingIngredients(
      toJson(),
      products
          .where((p) => p.stock > 0 && p.category == 'Comida')
          .map((p) => p.name)
          .toList(),
    );
  }
}

class PriceDecision {
  const PriceDecision({
    required this.title,
    required this.message,
    required this.color,
    required this.symbol,
  });
  final String title, message;
  final Color color;
  final IconData symbol;
}

PriceDecision decidePrice(double usualPrice, double offeredPrice) {
  if (!usualPrice.isFinite ||
      !offeredPrice.isFinite ||
      usualPrice <= 0 ||
      offeredPrice < 0) {
    return const PriceDecision(
      title: 'Agrega ambos precios',
      message:
          'La referencia debe ser mayor que cero y el precio no puede ser negativo.',
      color: Color(0xff80716c),
      symbol: Icons.info_outline,
    );
  }
  final percent = (offeredPrice - usualPrice) / usualPrice;
  final upper = usualPrice <= 40
      ? .10
      : usualPrice <= 100
      ? .08
      : usualPrice <= 200
      ? .04
      : usualPrice <= 500
      ? .03
      : usualPrice <= 1000
      ? .02
      : .01;
  final lower = usualPrice <= 200 ? -.15 : -.10;
  final difference = (percent * 100).abs().toStringAsFixed(1);
  if (percent + 1e-10 >= upper) {
    return PriceDecision(
      title: 'No lo compres',
      message:
          '$difference% más caro que tu referencia. Supera tu margen de ${(upper * 100).round()}%.',
      color: const Color(0xffb42318),
      symbol: Icons.block,
    );
  }
  if (percent <= lower + 1e-10) {
    return PriceDecision(
      title: '¡Cómpralo!',
      message:
          '¡Por favor, aprovecha! Está $difference% más barato que tu referencia.',
      color: const Color(0xff157347),
      symbol: Icons.favorite,
    );
  }
  return PriceDecision(
    title: 'Compra autorizada',
    message: percent.abs() < 1e-10
        ? 'Está al precio habitual.'
        : '$difference% ${percent > 0 ? 'más caro' : 'más barato'}. Está dentro de tu margen.',
    color: const Color(0xff16803c),
    symbol: Icons.verified,
  );
}

double? comparablePrice({
  required double referenceAmount,
  required String referenceUnit,
  required double offeredAmount,
  required String offeredUnit,
  required double offeredPrice,
}) {
  const units = {
    'g': ('mass', 1.0),
    'kg': ('mass', 1000.0),
    'ml': ('volume', 1.0),
    'L': ('volume', 1000.0),
    'pieza': ('piece', 1.0),
    'rollo': ('roll', 1.0),
  };
  if (referenceAmount <= 0 ||
      offeredAmount <= 0 ||
      !referenceAmount.isFinite ||
      !offeredAmount.isFinite ||
      !offeredPrice.isFinite ||
      offeredPrice < 0) {
    return null;
  }
  final a = units[referenceUnit] ?? (referenceUnit, 1.0),
      b = units[offeredUnit] ?? (offeredUnit, 1.0);
  if (a.$1 != b.$1) return null;
  return offeredPrice * referenceAmount * a.$2 / (offeredAmount * b.$2);
}
