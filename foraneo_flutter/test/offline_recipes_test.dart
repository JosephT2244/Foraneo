import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foraneo/services/offline_recipes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixtures =
      jsonDecode(File('../tests/recipe-fixtures.json').readAsStringSync())
          as Map<String, dynamic>;
  test('ingredient names and restrictions agree with the web fixtures', () {
    for (final row in fixtures['normalization'] as List) {
      expect(
        OfflineRecipes.normalizeIngredient(row[0] as String),
        row[1],
        reason: '${row[0]}',
      );
    }
    for (final row in fixtures['matching'] as List) {
      expect(
        OfflineRecipes.ingredientMatches(row[0] as String, row[1] as String),
        row[2],
        reason: '${row[0]} / ${row[1]}',
      );
    }
    for (final row in fixtures['restrictions'] as List) {
      expect(
        OfflineRecipes.isRecipeAllowed(
          Map<String, dynamic>.from(row[0] as Map),
        ),
        row[1],
        reason: '${row[0]}',
      );
    }
  });
  test(
    'native asset includes the complete cookbook and shared ranking',
    () async {
      final recipes = await OfflineRecipes.load();
      expect(recipes.length, 1225);
      expect(recipes.map((recipe) => recipe['baseId']).toSet().length, 54);
      for (final row in fixtures['queries'] as List) {
        final result = OfflineRecipes.recommend(
          recipes: recipes,
          query: row['query'] as String,
          pantry: (row['pantry'] as List).cast<String>(),
          limit: row['limit'] as int,
        );
        expect(
          result.map((recipe) => recipe['id']).toList(),
          row['ids'],
          reason: '${row['query']}',
        );
      }
      final best = OfflineRecipes.recommend(
        recipes: recipes,
        query: 'pasta',
        pantry: [
          'pasta',
          'tofu',
          'brócoli',
          'tomate',
          'ajo',
          'orégano',
          'cebolla',
          'sal',
          'aceite de oliva',
        ],
        limit: 1,
      ).first;
      expect(best['id'], 'local-pasta-tomate-tofu-brocoli');
      expect(
        OfflineRecipes.missingIngredients(
          best,
          (best['ingredientKeys'] as List).cast<String>(),
        ),
        isEmpty,
      );
      expect(
        OfflineRecipes.missingIngredients(
          best,
          [],
        ).any((item) => RegExp(r'^\d+ ml de agua').hasMatch(item)),
        isFalse,
      );
      final first = OfflineRecipes.recommend(
        recipes: recipes,
        query: 'pasta',
        limit: 8,
      );
      final next = OfflineRecipes.recommend(
        recipes: recipes,
        query: 'pasta',
        limit: 8,
        offset: 8,
      );
      expect(
        [...first, ...next].map((recipe) => recipe['id']).toSet().length,
        16,
      );
      for (final query in [
        'sin pollo',
        'sin pollo ni tofu',
        'pasta sin pollo, tofu',
        'sin pollo con pasta',
      ]) {
        final without = OfflineRecipes.recommend(
          recipes: recipes,
          query: query,
          limit: 200,
        );
        expect(without, isNotEmpty, reason: query);
        expect(
          without.every(
            (recipe) => !(recipe['ingredientKeys'] as List).contains('pollo'),
          ),
          isTrue,
          reason: query,
        );
        if (query.contains('tofu')) {
          expect(
            without.every(
              (recipe) => !(recipe['ingredientKeys'] as List).contains('tofu'),
            ),
            isTrue,
            reason: query,
          );
        }
      }
    },
  );
}
