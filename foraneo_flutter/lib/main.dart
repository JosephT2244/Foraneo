import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ForaneoApp());
}

class ForaneoApp extends StatelessWidget {
  const ForaneoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xffbd5d38),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Foráneo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfffff9f4),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xfffff9f4),
          foregroundColor: Color(0xff3b2b25),
          elevation: 0,
        ),
      ),
      home: const ForaneoHome(),
    );
  }
}

enum StockState { enough, low, empty }

class AppProduct {
  AppProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.unit,
    required this.stock,
    required this.lowAt,
    required this.referencePrice,
    this.photo,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String unit;
  int stock;
  final int lowAt;
  final double referencePrice;
  final Uint8List? photo;

  StockState get stockState {
    if (stock <= 0) return StockState.empty;
    if (stock <= lowAt) return StockState.low;
    return StockState.enough;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'unit': unit,
      'stock': stock,
      'lowAt': lowAt,
      'referencePrice': referencePrice,
      'photo': photo == null ? null : base64Encode(photo!),
    };
  }

  factory AppProduct.fromJson(Map<String, dynamic> json) {
    Uint8List? bytes;
    final photo = json['photo'];
    if (photo is String && photo.isNotEmpty) {
      try {
        bytes = base64Decode(photo);
      } catch (_) {
        bytes = null;
      }
    }
    return AppProduct(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Producto',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Hogar',
      unit: json['unit']?.toString() ?? 'pza',
      stock: (json['stock'] as num?)?.round() ?? 0,
      lowAt: (json['lowAt'] as num?)?.round() ?? 1,
      referencePrice: (json['referencePrice'] as num?)?.toDouble() ?? 0,
      photo: bytes,
    );
  }
}

class TodoEntry {
  TodoEntry({
    required this.id,
    required this.title,
    required this.when,
    this.done = false,
  });

  final String id;
  final String title;
  final String when;
  bool done;

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'when': when, 'done': done};
  }

  factory TodoEntry.fromJson(Map<String, dynamic> json) {
    return TodoEntry(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Pendiente',
      when: json['when']?.toString() ?? 'Hoy',
      done: json['done'] == true,
    );
  }
}

class Recipe {
  Recipe({
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.minutes,
    required this.servings,
    required this.tag,
    this.videoUrl = '',
  });

  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final String minutes;
  final String servings;
  final String tag;
  final String videoUrl;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'steps': steps,
      'time': minutes,
      'servings': servings,
      'tag': tag,
      'videoUrl': videoUrl,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<String> asStrings(Object? value) {
      if (value is! List) return const [];
      return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }

    return Recipe(
      title: json['title']?.toString() ?? 'Receta de Foráneo',
      description: json['description']?.toString() ?? '',
      ingredients: asStrings(json['ingredients']),
      steps: asStrings(json['steps']),
      minutes: json['time']?.toString() ?? '25 min',
      servings: json['servings']?.toString() ?? '2 porciones',
      tag: json['tag']?.toString() ?? 'Casera',
      videoUrl: json['videoUrl']?.toString() ?? '',
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

  final String title;
  final String message;
  final Color color;
  final IconData symbol;
}

PriceDecision decidePrice(double usualPrice, double offeredPrice) {
  if (usualPrice <= 0 || offeredPrice < 0) {
    return const PriceDecision(
      title: 'Agrega ambos precios',
      message: 'Necesitamos una referencia para comparar.',
      color: Color(0xff80716c),
      symbol: Icons.info_outline,
    );
  }

  final percent = (offeredPrice - usualPrice) / usualPrice;
  double upper;
  double lower;
  if (usualPrice <= 40) {
    lower = -0.15;
    upper = 0.10;
  } else if (usualPrice <= 100) {
    lower = -0.15;
    upper = 0.08;
  } else if (usualPrice <= 200) {
    lower = -0.15;
    upper = 0.04;
  } else if (usualPrice <= 500) {
    lower = -0.10;
    upper = 0.03;
  } else if (usualPrice <= 1000) {
    lower = -0.10;
    upper = 0.02;
  } else {
    lower = -0.10;
    upper = 0.01;
  }

  final difference = (percent * 100).abs().toStringAsFixed(1);
  if (percent >= upper) {
    return PriceDecision(
      title: 'No lo compres',
      message: 'Está $difference% arriba de tu margen.',
      color: const Color(0xffb42318),
      symbol: Icons.block,
    );
  }
  if (percent <= lower) {
    return PriceDecision(
      title: '¡Cómpralo!',
      message: 'Está $difference% más barato: es una gran oportunidad.',
      color: const Color(0xff157347),
      symbol: Icons.favorite,
    );
  }
  return PriceDecision(
    title: 'Compra autorizada',
    message: percent == 0
        ? 'Está al precio habitual.'
        : 'Está dentro del margen seguro ($difference% de diferencia).',
    color: const Color(0xff16803c),
    symbol: Icons.verified,
  );
}

class RecipeApi {
  const RecipeApi();

  static const endpoint = String.fromEnvironment(
    'RECIPES_API_URL',
    defaultValue: 'http://localhost:8787/api/recipes',
  );

  Future<List<Recipe>> ask({
    required List<AppProduct> products,
    required String note,
  }) async {
    final pantry = products.where((product) => product.stock > 0).toList();
    final ingredient = note.trim().isEmpty
        ? (pantry.isEmpty ? 'ingredientes disponibles' : pantry.first.name)
        : note.trim();
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'ingredient': ingredient,
            'description': note.trim(),
            'pantry': pantry.map((product) => product.name).toList(),
            'count': 6,
            'offset': 0,
            'previousTitles': const [],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('El servicio respondió con código ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['recipes'] is! List) {
      throw Exception('La respuesta de recetas no tiene el formato esperado.');
    }
    return (decoded['recipes'] as List)
        .whereType<Map>()
        .map((item) => Recipe.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}

class ForaneoHome extends StatefulWidget {
  const ForaneoHome({super.key});

  @override
  State<ForaneoHome> createState() => _ForaneoHomeState();
}

class _ForaneoHomeState extends State<ForaneoHome> {
  static const _storageKey = 'foraneo_flutter_state_v1';

  int _page = 0;
  bool _loadingRecipes = false;
  String? _recipeError;
  final _recipeNote = TextEditingController();
  final _usualPrice = TextEditingController(text: '20');
  final _offeredPrice = TextEditingController(text: '20');

  List<AppProduct> _products = _starterProducts();
  List<TodoEntry> _todos = _starterTodos();
  List<Recipe> _recipes = _starterRecipes();

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  @override
  void dispose() {
    _recipeNote.dispose();
    _usualPrice.dispose();
    _offeredPrice.dispose();
    super.dispose();
  }

  static List<AppProduct> _starterProducts() {
    return [
      AppProduct(
        id: 'pasta',
        name: 'Pasta',
        description: 'Pasta seca para una comida rápida.',
        category: 'Comida',
        unit: 'paquete de 250 g',
        stock: 2,
        lowAt: 1,
        referencePrice: 20,
      ),
      AppProduct(
        id: 'jabon',
        name: 'Jabón para manos',
        description: 'Jabón líquido del baño.',
        category: 'Baño',
        unit: 'botella',
        stock: 1,
        lowAt: 1,
        referencePrice: 48,
      ),
      AppProduct(
        id: 'detergente',
        name: 'Detergente',
        description: 'Para ropa de color.',
        category: 'Lavar',
        unit: 'bolsa',
        stock: 0,
        lowAt: 1,
        referencePrice: 125,
      ),
      AppProduct(
        id: 'cafe',
        name: 'Café',
        description: 'Café molido.',
        category: 'Cocina',
        unit: 'bolsa',
        stock: 1,
        lowAt: 1,
        referencePrice: 180,
      ),
    ];
  }

  static List<TodoEntry> _starterTodos() {
    return [
      TodoEntry(id: 't1', title: 'Revisar despensa', when: 'Hoy'),
      TodoEntry(id: 't2', title: 'Planear comidas de la semana', when: 'Esta semana'),
    ];
  }

  static List<Recipe> _starterRecipes() {
    return [
      Recipe(
        title: 'Pasta al ajo y hierbas',
        description: 'Una cena sencilla para aprovechar la pasta disponible.',
        ingredients: const ['Pasta', 'Ajo', 'Aceite de oliva', 'Hierbas secas'],
        steps: const [
          'Hierve la pasta hasta que quede al dente.',
          'Dora ligeramente el ajo en aceite.',
          'Mezcla con la pasta y termina con hierbas.',
        ],
        minutes: '20 min',
        servings: '2 porciones',
        tag: 'Rápida',
      ),
    ];
  }

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_storageKey);
      if (saved == null) return;
      final decoded = jsonDecode(saved);
      if (decoded is! Map) return;
      final products = (decoded['products'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => AppProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final todos = (decoded['todos'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => TodoEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final recipes = (decoded['recipes'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Recipe.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        if (products.isNotEmpty) _products = products;
        if (todos.isNotEmpty) _todos = todos;
        if (recipes.isNotEmpty) _recipes = recipes;
      });
    } catch (_) {
      // A damaged local cache must never keep the app from opening.
    }
  }

  Future<void> _store() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode({
          'products': _products.map((product) => product.toJson()).toList(),
          'todos': _todos.map((todo) => todo.toJson()).toList(),
          'recipes': _recipes.map((recipe) => recipe.toJson()).toList(),
        }),
      );
    } catch (_) {
      // Storage is a convenience; the current session remains usable.
    }
  }

  void _persist() {
    unawaited(_store());
  }

  void _setPage(int page) {
    setState(() => _page = page);
  }

  void _changeStock(AppProduct product, int change) {
    setState(() {
      product.stock = (product.stock + change).clamp(0, 999).toInt();
    });
    _persist();
  }

  Future<void> _addProduct() async {
    final product = await showDialog<AppProduct>(
      context: context,
      builder: (context) => const _ProductEditor(),
    );
    if (product == null || !mounted) return;
    setState(() => _products.add(product));
    _persist();
  }

  Future<void> _addTodo() async {
    final controller = TextEditingController();
    String when = 'Hoy';
    final entry = await showDialog<TodoEntry>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo pendiente'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '¿Qué necesitas hacer?'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: when,
                    decoration: const InputDecoration(labelText: 'Cuándo'),
                    items: const [
                      DropdownMenuItem(value: 'Hoy', child: Text('Hoy')),
                      DropdownMenuItem(value: 'Esta semana', child: Text('Esta semana')),
                    ],
                    onChanged: (value) => setDialogState(() => when = value ?? 'Hoy'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = controller.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(
                      dialogContext,
                      TodoEntry(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        title: title,
                        when: when,
                      ),
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    if (entry == null || !mounted) return;
    setState(() => _todos.add(entry));
    _persist();
  }

  Future<void> _askForRecipes() async {
    setState(() {
      _loadingRecipes = true;
      _recipeError = null;
    });
    try {
      final results = await const RecipeApi().ask(
        products: _products,
        note: _recipeNote.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _recipes = [...results, ..._recipes];
      });
      _persist();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recipeError =
            'No pudimos contactar a la IA. Inicia el servidor de Foráneo y configura RECIPES_API_URL.';
      });
    } finally {
      if (mounted) setState(() => _loadingRecipes = false);
    }
  }

  void _sendMissingToShopping(Recipe recipe) {
    final existing = _products.map((item) => item.name.toLowerCase()).toSet();
    final missing = recipe.ingredients
        .where((ingredient) => !existing.contains(ingredient.toLowerCase()))
        .toList();
    if (missing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos los ingredientes ya están registrados.')),
      );
      return;
    }
    setState(() {
      for (final ingredient in missing) {
        _products.add(
          AppProduct(
            id: '${DateTime.now().microsecondsSinceEpoch}$ingredient',
            name: ingredient,
            description: 'Ingrediente pendiente de la receta ${recipe.title}',
            category: 'Cocina',
            unit: 'unidad',
            stock: 0,
            lowAt: 1,
            referencePrice: 0,
          ),
        );
      }
      _page = 2;
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${missing.length} ingrediente(s) enviado(s) a compras urgentes.')),
    );
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Resumen'),
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
      NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'Compras'),
      NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Cocina IA'),
      NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Agenda'),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final content = SafeArea(child: _buildPage());

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _page,
              onDestinationSelected: _setPage,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(12, 20, 12, 16),
                child: _BrandMark(),
              ),
              destinations: destinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: _setPage,
        destinations: destinations,
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case 0:
        return _dashboard();
      case 1:
        return _inventory();
      case 2:
        return _shopping();
      case 3:
        return _kitchen();
      case 4:
        return _agenda();
      default:
        return _dashboard();
    }
  }

  Widget _dashboard() {
    final empty = _products.where((product) => product.stockState == StockState.empty).length;
    final low = _products.where((product) => product.stockState == StockState.low).length;
    final undone = _todos.where((todo) => !todo.done).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageHeading(
          eyebrow: 'TU HOGAR, EN ORDEN',
          title: 'Hola, foráneo',
          subtitle: 'Tu despensa, tus compras y tu semana en un mismo lugar.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              icon: Icons.priority_high,
              label: 'Urgentes',
              value: empty.toString(),
              color: const Color(0xffb42318),
            ),
            _MetricCard(
              icon: Icons.shopping_cart_outlined,
              label: 'Por comprar',
              value: low.toString(),
              color: const Color(0xffc76a13),
            ),
            _MetricCard(
              icon: Icons.task_alt,
              label: 'Pendientes',
              value: undone.toString(),
              color: const Color(0xff3d7c55),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeading(title: 'Alertas del hogar'),
        const SizedBox(height: 8),
        if (empty + low == 0)
          const _EmptyHint(
            icon: Icons.sentiment_satisfied_alt,
            text: 'Todo está bajo control. No tienes faltantes por ahora.',
          )
        else
          ..._products
              .where((product) => product.stockState != StockState.enough)
              .map(
                (product) => _StockAlert(
                  product: product,
                  onTap: () => _setPage(2),
                ),
              ),
        const SizedBox(height: 24),
        const _SectionHeading(title: 'Hoy en tu agenda'),
        const SizedBox(height: 8),
        ..._todos
            .where((todo) => todo.when == 'Hoy' && !todo.done)
            .map((todo) => _TodoRow(todo: todo, onChanged: (value) {
                  setState(() => todo.done = value ?? false);
                  _persist();
                })),
        if (_todos.where((todo) => todo.when == 'Hoy' && !todo.done).isEmpty)
          const _EmptyHint(icon: Icons.event_available, text: 'No hay pendientes para hoy.'),
      ],
    );
  }

  Widget _inventory() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PageHeading(
          eyebrow: 'INVENTARIO',
          title: 'Lo que tienes',
          subtitle: 'Agrega foto, cantidad y el precio que pagas normalmente.',
          action: FilledButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Agregar producto'),
          ),
        ),
        const SizedBox(height: 18),
        ..._products.map(
          (product) => _ProductCard(
            product: product,
            onDecrease: () => _changeStock(product, -1),
            onIncrease: () => _changeStock(product, 1),
          ),
        ),
      ],
    );
  }

  Widget _shopping() {
    final urgent = _products.where((product) => product.stockState == StockState.empty).toList();
    final normal = _products.where((product) => product.stockState == StockState.low).toList();
    final usual = double.tryParse(_usualPrice.text.replaceAll(',', '.')) ?? 0;
    final offer = double.tryParse(_offeredPrice.text.replaceAll(',', '.')) ?? 0;
    final decision = decidePrice(usual, offer);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageHeading(
          eyebrow: 'COMPRAS INTELIGENTES',
          title: 'Compra sin pagar de más',
          subtitle: 'Foráneo aplica tu margen automáticamente según el costo habitual.',
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comparador de precio', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usualPrice,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixText: r'$ ',
                          labelText: 'Precio habitual',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _offeredPrice,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixText: r'$ ',
                          labelText: 'Precio de hoy',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: decision.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: decision.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(decision.symbol, color: decision.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              decision.title,
                              style: TextStyle(color: decision.color, fontWeight: FontWeight.bold),
                            ),
                            Text(decision.message),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeading(title: 'Compra urgente'),
        const SizedBox(height: 8),
        if (urgent.isEmpty)
          const _EmptyHint(icon: Icons.check_circle_outline, text: 'Nada agotado por ahora.')
        else
          ...urgent.map((product) => _ShoppingProduct(
                product: product,
                urgent: true,
                onCompare: () {
                  _usualPrice.text = product.referencePrice.toStringAsFixed(2);
                  _offeredPrice.text = product.referencePrice.toStringAsFixed(2);
                  setState(() {});
                },
              )),
        const SizedBox(height: 20),
        const _SectionHeading(title: 'Por comprar pronto'),
        const SizedBox(height: 8),
        if (normal.isEmpty)
          const _EmptyHint(icon: Icons.inventory_outlined, text: 'No hay productos por terminarse.')
        else
          ...normal.map((product) => _ShoppingProduct(
                product: product,
                urgent: false,
                onCompare: () {
                  _usualPrice.text = product.referencePrice.toStringAsFixed(2);
                  _offeredPrice.text = product.referencePrice.toStringAsFixed(2);
                  setState(() {});
                },
              )),
      ],
    );
  }

  Widget _kitchen() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageHeading(
          eyebrow: 'COCINA IA',
          title: '¿Qué cocinamos hoy?',
          subtitle: 'La IA considera lo que tienes y omite huevo revuelto y arroz tradicional.',
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _recipeNote,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Antojo o ingredientes extra',
                    hintText: 'Ej. algo rápido con pasta y verduras',
                    prefixIcon: Icon(Icons.auto_awesome),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loadingRecipes ? null : _askForRecipes,
                    icon: _loadingRecipes
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_loadingRecipes ? 'Buscando recetas...' : 'Pedir recetas a la IA'),
                  ),
                ),
                if (_recipeError != null) ...[
                  const SizedBox(height: 10),
                  Text(_recipeError!, style: const TextStyle(color: Color(0xffb42318))),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _SectionHeading(title: 'Tus recetas'),
        const SizedBox(height: 8),
        ..._recipes.map(
          (recipe) => _RecipeCard(
            recipe: recipe,
            onSendMissing: () => _sendMissingToShopping(recipe),
            onVideo: recipe.videoUrl.isEmpty ? null : () => _openVideo(recipe.videoUrl),
          ),
        ),
      ],
    );
  }

  Widget _agenda() {
    final today = _todos.where((todo) => todo.when == 'Hoy').toList();
    final week = _todos.where((todo) => todo.when != 'Hoy').toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PageHeading(
          eyebrow: 'AGENDA',
          title: 'Tu semana, a tu ritmo',
          subtitle: 'Marca lo terminado y deja espacio mental para lo importante.',
          action: FilledButton.icon(
            onPressed: _addTodo,
            icon: const Icon(Icons.add_task),
            label: const Text('Nuevo pendiente'),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeading(title: 'Hoy'),
        const SizedBox(height: 8),
        if (today.isEmpty)
          const _EmptyHint(icon: Icons.event_available, text: 'Tu día está libre.')
        else
          ...today.map((todo) => _TodoRow(todo: todo, onChanged: (value) {
                setState(() => todo.done = value ?? false);
                _persist();
              })),
        const SizedBox(height: 20),
        const _SectionHeading(title: 'Esta semana'),
        const SizedBox(height: 8),
        if (week.isEmpty)
          const _EmptyHint(icon: Icons.calendar_month, text: 'No hay pendientes semanales.')
        else
          ...week.map((todo) => _TodoRow(todo: todo, onChanged: (value) {
                setState(() => todo.done = value ?? false);
                _persist();
              })),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.home_rounded, color: Color(0xffbd5d38), size: 30),
        SizedBox(height: 3),
        Text('Foráneo', style: TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 530,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xffbd5d38),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        if (action != null) ...[action!],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.13), child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.headlineSmall),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [Icon(icon, color: const Color(0xff62806e)), const SizedBox(width: 10), Expanded(child: Text(text))]),
      ),
    );
  }
}

class _StockAlert extends StatelessWidget {
  const _StockAlert({required this.product, required this.onTap});

  final AppProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = product.stockState == StockState.empty;
    final color = urgent ? const Color(0xffb42318) : const Color(0xffc76a13);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: _ProductImage(product: product),
        title: Text(product.name),
        subtitle: Text(urgent ? 'Se acabó: pásalo a compra urgente.' : 'Quedan pocas existencias.'),
        trailing: Icon(Icons.arrow_forward_ios, color: color, size: 18),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onDecrease,
    required this.onIncrease,
  });

  final AppProduct product;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final state = product.stockState;
    final color = switch (state) {
      StockState.enough => const Color(0xff16803c),
      StockState.low => const Color(0xffc76a13),
      StockState.empty => const Color(0xffb42318),
    };
    final label = switch (state) {
      StockState.enough => 'En casa',
      StockState.low => 'Por terminarse',
      StockState.empty => 'Agotado',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ProductImage(product: product, size: 60),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                      _StatePill(label: label, color: color),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${product.category} · ${product.description}'),
                  const SizedBox(height: 5),
                  Text(
                    '${product.stock} ${product.unit} · habitual \$${product.referencePrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(onPressed: onIncrease, icon: const Icon(Icons.add_circle_outline), tooltip: 'Agregar una unidad'),
                IconButton(onPressed: onDecrease, icon: const Icon(Icons.remove_circle_outline), tooltip: 'Consumir una unidad'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product, this.size = 48});

  final AppProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (product.photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(product.photo!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xffffe8db),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(_iconForCategory(product.category), color: const Color(0xffbd5d38)),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'comida':
      case 'cocina':
        return Icons.restaurant;
      case 'baño':
      case 'higiene':
        return Icons.bathroom_outlined;
      case 'lavar':
        return Icons.local_laundry_service_outlined;
      case 'tecnología':
        return Icons.devices_other_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _ShoppingProduct extends StatelessWidget {
  const _ShoppingProduct({
    required this.product,
    required this.urgent,
    required this.onCompare,
  });

  final AppProduct product;
  final bool urgent;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final color = urgent ? const Color(0xffb42318) : const Color(0xffc76a13);
    return Card(
      child: ListTile(
        leading: Icon(urgent ? Icons.priority_high : Icons.shopping_cart_outlined, color: color),
        title: Text(product.name),
        subtitle: Text(product.referencePrice > 0 ? 'Referencia: \$${product.referencePrice.toStringAsFixed(2)}' : 'Añade un precio de referencia'),
        trailing: TextButton(onPressed: onCompare, child: const Text('Comparar')),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onSendMissing,
    this.onVideo,
  });

  final Recipe recipe;
  final VoidCallback onSendMissing;
  final VoidCallback? onVideo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.restaurant_menu)),
        title: Text(recipe.title),
        subtitle: Text('${recipe.tag} · ${recipe.minutes} · ${recipe.servings}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(recipe.description)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Ingredientes', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recipe.ingredients.map((ingredient) => Chip(label: Text(ingredient))).toList(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Instrucciones', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 5),
          ...recipe.steps.indexed.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('${item.$1 + 1}. ${item.$2}'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onSendMissing,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Enviar faltantes a compras'),
              ),
              if (onVideo != null)
                TextButton.icon(
                  onPressed: onVideo,
                  icon: const Icon(Icons.ondemand_video_outlined),
                  label: const Text('Ver video'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo, required this.onChanged});

  final TodoEntry todo;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        value: todo.done,
        onChanged: onChanged,
        title: Text(
          todo.title,
          style: TextStyle(decoration: todo.done ? TextDecoration.lineThrough : null),
        ),
        subtitle: Text(todo.when),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor();

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _unit = TextEditingController(text: 'pieza');
  final _amount = TextEditingController(text: '1');
  final _lowAt = TextEditingController(text: '1');
  final _price = TextEditingController(text: '0');
  String _category = 'Comida';
  Uint8List? _photo;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _unit.dispose();
    _amount.dispose();
    _lowAt.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final selection = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (!mounted || selection == null || selection.files.isEmpty) return;
    setState(() => _photo = selection.files.single.bytes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar producto'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _choosePhoto,
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xffffe8db),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: _photo == null
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined),
                            SizedBox(height: 4),
                            Text('Cargar foto del producto'),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(_photo!, width: double.infinity, height: 100, fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 8),
              TextField(controller: _description, decoration: const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: const ['Comida', 'Higiene', 'Cocina', 'Baño', 'Lavar', 'Tecnología', 'Hogar']
                    .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value ?? 'Hogar'),
              ),
              const SizedBox(height: 8),
              TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Presentación, ej. 250 g')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad actual'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lowAt,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Avisar al quedar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: r'$ ', labelText: 'Precio habitual'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              AppProduct(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                name: name,
                description: _description.text.trim(),
                category: _category,
                unit: _unit.text.trim().isEmpty ? 'pieza' : _unit.text.trim(),
                stock: int.tryParse(_amount.text) ?? 0,
                lowAt: int.tryParse(_lowAt.text) ?? 1,
                referencePrice: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
                photo: _photo,
              ),
            );
          },
          child: const Text('Guardar producto'),
        ),
      ],
    );
  }
}
