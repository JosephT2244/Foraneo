import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

List<Map<String, dynamic>> _decodeCookbook(String json) =>
    (jsonDecode(json) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

/// Offline, deterministic cookbook search. This service never calls an API or LLM.
/// Keep aliases, scoring and fixtures aligned with src/offline-recipes.js.
class OfflineRecipes {
  static Future<List<Map<String, dynamic>>>? _loading;
  static List<Map<String, dynamic>>? _indexedRecipes;
  static List<_RecipeIndex> _index = [];
  static const _aliases = <String, List<String>>{
    'aceite de oliva': ['aceite de oliva'],
    'leche de avena': [
      'leche de avena',
      'bebida de avena',
      'bebida vegetal de avena',
    ],
    'leche de coco': ['leche de coco', 'bebida de coco'],
    'crema de cacahuate': [
      'crema de cacahuate',
      'mantequilla de cacahuate',
      'crema de mani',
    ],
    'concentrado de tomate': [
      'concentrado de tomate',
      'pasta de tomate',
      'pure concentrado de tomate',
    ],
    'caldo de verduras': ['caldo de verduras', 'caldo vegetal'],
    'salsa de soya': [
      'salsa de soya',
      'salsa de soja',
      'salsa soya',
      'salsa soja',
      'tamari',
    ],
    'queso parmesano': ['queso parmesano', 'parmesano', 'parmigiano'],
    'semilla de calabaza': [
      'semillas de calabaza',
      'semilla de calabaza',
      'pepitas',
    ],
    'tortilla de harina': ['tortillas de harina', 'tortilla de harina'],
    'tortilla de maiz': ['tortillas de maiz', 'tortilla de maiz'],
    'tostada de maiz': ['tostadas de maiz', 'tostada de maiz', 'tostadas'],
    'fecula de maiz': ['fecula de maiz', 'almidon de maiz', 'maicena'],
    'frijol blanco': ['frijoles blancos', 'frijol blanco', 'alubias', 'alubia'],
    'yogur natural': [
      'yogur natural',
      'yogurt natural',
      'yoghurt natural',
      'yogur griego natural',
    ],
    'pan integral': ['pan integral'],
    'pasta': [
      'pasta',
      'fusilli',
      'espagueti',
      'espaguetis',
      'spaghetti',
      'macarrones',
      'penne',
    ],
    'fideo': ['fideos', 'fideo', 'noodles'],
    'tomate': ['tomates', 'tomate', 'jitomates', 'jitomate'],
    'calabacita': [
      'calabacitas',
      'calabacita',
      'calabacin',
      'calabacines',
      'zucchini',
    ],
    'brocoli': ['brocoli', 'brocolis'],
    'champinon': ['champinones', 'champinon'],
    'pimiento': ['pimientos', 'pimiento', 'pimenton rojo fresco'],
    'zanahoria': ['zanahorias', 'zanahoria'],
    'garbanzo': ['garbanzos', 'garbanzo'],
    'lenteja': ['lentejas', 'lenteja'],
    'pollo': ['pollo', 'pechuga de pollo'],
    'tofu': ['tofu'],
    'arroz': ['arroz'],
    'quinoa': ['quinoa', 'quinua'],
    'cuscus': ['cuscus', 'couscous'],
    'avena': ['avena'],
    'huevo': ['huevos', 'huevo'],
    'papa': ['papas', 'papa', 'patatas', 'patata'],
    'cebollin': ['cebollin', 'cebolleta'],
    'cebolla': ['cebollas', 'cebolla'],
    'ajo': ['ajos', 'ajo'],
    'aguacate': ['aguacates', 'aguacate', 'palta'],
    'lechuga': ['lechugas', 'lechuga'],
    'espinaca': ['espinacas', 'espinaca'],
    'limon': ['limones', 'limon'],
    'platano': ['platanos', 'platano', 'banana', 'banano'],
    'manzana': ['manzanas', 'manzana'],
    'fresa': ['fresas', 'fresa', 'frutillas', 'frutilla'],
    'mango': ['mangos', 'mango'],
    'nuez': ['nueces', 'nuez'],
    'chia': ['chia'],
    'canela': ['canela'],
    'albahaca': ['albahaca'],
    'perejil': ['perejil'],
    'cilantro': ['cilantro'],
    'oregano': ['oregano'],
    'comino': ['comino'],
    'pimenton': ['pimenton', 'paprika'],
    'chipotle': ['chipotle'],
    'jengibre': ['jengibre'],
    'curry': ['curry'],
    'tahini': ['tahini', 'tahin', 'pasta de ajonjoli'],
    'ajonjoli': ['ajonjoli', 'sesamo'],
    'miel': ['miel'],
    'sal': ['sal'],
    'agua': ['agua'],
  };
  static final _phrases =
      _aliases.entries
          .expand((entry) => entry.value.map((word) => (word, entry.key)))
          .toList()
        ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
  static final _stopWords =
      'a al algo con como cocinar cocina compra de del el en la las lo los me mi mis para por que quiero receta recetas recomienda recomiendame rica rico ricas ricos tengo una unas uno unos un y sin g gr gramos kg kilogramo kilogramos ml l litro litros taza tazas cucharada cucharadas cucharadita cucharaditas pieza piezas paquete paquetes fresco fresca frescos frescas natural naturales integral mediano mediana medianos medianas aproximadamente sin azucar de forma'
          .split(' ')
          .toSet();

  static String _fold(Object? value) {
    var text = '$value'.toLowerCase();
    const accented = 'áéíóúüñàèìòùâêîôûäëïö';
    const plain = 'aeiouunaeiouaeiouaeio';
    for (var i = 0; i < accented.length; i++) {
      text = text.replaceAll(accented[i], plain[i]);
    }
    return text
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String normalizeIngredient(String value) {
    final text = _fold(
      value,
    ).replaceAll(RegExp(r'\b(?:sin|no contiene) huevos?\b'), '');
    if (text.isEmpty) return '';
    for (final phrase in _phrases) {
      if (' $text '.contains(' ${phrase.$1} ')) return phrase.$2;
    }
    return text
        .split(' ')
        .where(
          (word) =>
              word.isNotEmpty &&
              !RegExp(r'^\d+$').hasMatch(word) &&
              !_stopWords.contains(word),
        )
        .join(' ');
  }

  static bool ingredientMatches(String ingredient, String product) {
    final a = normalizeIngredient(ingredient), b = normalizeIngredient(product);
    return a.isNotEmpty && b.isNotEmpty && a == b;
  }

  static List<String> _strings(Object? value) =>
      value is List ? value.map((item) => '$item').toList() : [];
  static List<String> missingIngredients(
    Map<String, dynamic> recipe,
    List<String> pantry,
  ) {
    final available = pantry.map(normalizeIngredient).toSet()..add('agua');
    final seen = <String>{};
    final ingredients = _strings(recipe['ingredients']),
        keys = _strings(recipe['ingredientKeys']);
    return ingredients.indexed
        .where((entry) {
          final key = normalizeIngredient(
            keys.length > entry.$1 && keys[entry.$1].isNotEmpty
                ? keys[entry.$1]
                : entry.$2,
          );
          if (key.isEmpty || available.contains(key) || seen.contains(key)) {
            return false;
          }
          seen.add(key);
          return true;
        })
        .map((entry) => entry.$2)
        .toList();
  }

  static String? recipeRestrictionReason(Map<String, dynamic> recipe) {
    // Mirrors web: every recipe is allowed, including eggs, meats and rice.
    return null;
  }

  static bool isRecipeAllowed(Map<String, dynamic> recipe) =>
      recipeRestrictionReason(recipe) == null;

  static Future<List<Map<String, dynamic>>> load() => _loading ??= _load();
  static Future<List<Map<String, dynamic>>> _load() async {
    try {
      final json = await rootBundle.loadString('assets/recipes/catalog.json');
      final recipes = await compute(_decodeCookbook, json);
      return recipes;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  static List<String> _queryWords(String query) {
    var text = ' ${_fold(query)} ';
    for (final phrase in _phrases) {
      text = text.replaceAll(' ${phrase.$1} ', ' ${phrase.$2} ');
    }
    const synonyms = {
      'cenar': 'cena',
      'desayunar': 'desayuno',
      'almuerzo': 'comida',
      'italiana': 'mediterranea',
      'italiano': 'mediterranea',
      'asiatico': 'asiatica',
      'chino': 'china',
      'oriental': 'asiatica',
    };
    return text
        .trim()
        .split(' ')
        .where(
          (word) =>
              word.isNotEmpty &&
              !_stopWords.contains(word) &&
              !RegExp(r'^\d+$').hasMatch(word),
        )
        .map((word) => synonyms[word] ?? word)
        .toSet()
        .toList();
  }

  static List<Map<String, dynamic>> recommend({
    required List<Map<String, dynamic>> recipes,
    String query = '',
    List<String> pantry = const [],
    int limit = 12,
    int offset = 0,
    List<String> exclude = const [],
  }) {
    if (!identical(_indexedRecipes, recipes)) {
      _indexedRecipes = recipes;
      _index = recipes.indexed.where((entry) => isRecipeAllowed(entry.$2)).map((
        entry,
      ) {
        final recipe = entry.$2;
        final keys = _strings(recipe['ingredientKeys'] ?? recipe['ingredients'])
            .map(normalizeIngredient)
            .where((key) => key.isNotEmpty && key != 'agua')
            .toSet()
            .toList();
        final searchable = _queryWords(
          '${recipe['title']} ${recipe['category']} ${recipe['cuisine']} ${recipe['tag']} ${keys.join(' ')}',
        ).toSet();
        return _RecipeIndex(recipe, entry.$1, keys, searchable);
      }).toList();
    }
    final parsedQuery = _parseRecipeQuery(query);
    final queryTokens = parsedQuery.$1;
    final excludedIngredients = parsedQuery.$2;
    if (query.trim().isNotEmpty &&
        queryTokens.isEmpty &&
        excludedIngredients.isEmpty) {
      return [];
    }
    final available = pantry
        .map(normalizeIngredient)
        .where((key) => key.isNotEmpty)
        .toSet();
    final excluded = exclude.toSet();
    final ranked =
        _index
            .where(
              (entry) =>
                  !excluded.contains(entry.recipe['id']) &&
                  !excluded.contains(entry.recipe['title']) &&
                  !entry.keys.any(excludedIngredients.contains),
            )
            .map((entry) {
              final hits = queryTokens.where(entry.searchable.contains).length;
              final owned = entry.keys.where(available.contains).length;
              final score =
                  hits * 10000 +
                  (owned / (entry.keys.isEmpty ? 1 : entry.keys.length) * 1000)
                      .round() +
                  owned * 10;
              return _Ranked(entry, hits, score);
            })
            .where((entry) => queryTokens.isEmpty || entry.hits > 0)
            .toList()
          ..sort(_compare);
    final groups = <String, List<_Ranked>>{};
    for (final entry in ranked) {
      final key =
          '${entry.hits}:${entry.index.recipe['baseId'] ?? entry.index.recipe['id']}';
      (groups[key] ??= []).add(entry);
    }
    final diversified = <Map<String, dynamic>>[];
    final tiers = ranked.map((entry) => entry.hits).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    for (final tier in tiers) {
      final queues = groups.values
          .where((group) => group.first.hits == tier)
          .toList();
      for (
        var round = 0;
        queues.any((group) => group.length > round);
        round++
      ) {
        final candidates =
            queues
                .where((group) => group.length > round)
                .map((group) => group[round])
                .toList()
              ..sort(_compare);
        diversified.addAll(candidates.map((entry) => entry.index.recipe));
      }
    }
    return diversified
        .skip(offset.clamp(0, diversified.length))
        .take(limit.clamp(0, 200))
        .toList();
  }

  static int _compare(_Ranked a, _Ranked b) => a.score == b.score
      ? a.index.position.compareTo(b.index.position)
      : b.score.compareTo(a.score);

  // Explicit ingredient exclusions, not a general dietary-language model.
  static (List<String>, Set<String>) _parseRecipeQuery(String query) {
    final excludedIngredients = <String>{};
    final text = _fold(query.replaceAll(RegExp(r'[,;]'), ' ni '));
    final positive = text.replaceAllMapped(
      RegExp(
        r'\b(?:sin|no quiero|evita|evitar|excluye)\s+(.+?)(?=\s+(?:con|para|sin|no quiero|evita|evitar|excluye)\b|$)',
      ),
      (match) {
        for (final ingredient
            in match.group(1)!.split(RegExp(r'\s+(?:ni|y|o)\s+'))) {
          final key = normalizeIngredient(ingredient);
          if (key.isNotEmpty) excludedIngredients.add(key);
        }
        return ' ';
      },
    );
    return (_queryWords(positive), excludedIngredients);
  }
}

class _RecipeIndex {
  const _RecipeIndex(this.recipe, this.position, this.keys, this.searchable);
  final Map<String, dynamic> recipe;
  final int position;
  final List<String> keys;
  final Set<String> searchable;
}

class _Ranked {
  const _Ranked(this.index, this.hits, this.score);
  final _RecipeIndex index;
  final int hits, score;
}
