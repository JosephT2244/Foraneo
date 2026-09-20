import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth.dart';
import 'editors.dart';
import 'models.dart';
import 'services/local_vault.dart';
import 'services/native_services.dart';
import 'services/offline_recipes.dart';
export 'models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ForaneoApp());
}

class ForaneoApp extends StatefulWidget {
  const ForaneoApp({super.key});
  @override
  State<ForaneoApp> createState() => _ForaneoAppState();
}

class _ForaneoAppState extends State<ForaneoApp> {
  ThemeMode mode = ThemeMode.system;
  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff174d3d),
      brightness: brightness,
      surface: dark ? const Color(0xff13231d) : const Color(0xfffffdf6),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xff0d1a15)
          : const Color(0xfff4f1e9),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark
            ? const Color(0xff13231d)
            : const Color(0xfffffdf6),
        indicatorColor: dark
            ? const Color(0xff2c5944)
            : const Color(0xffdbe9ce),
        height: 76,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Foráneo',
    debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    themeMode: mode,
    locale: const Locale('es', 'MX'),
    supportedLocales: const [Locale('es', 'MX')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: ForaneoHome(
      onTheme: (value) {
        if (mounted && value != mode) setState(() => mode = value);
      },
    ),
  );
}

class ForaneoHome extends StatefulWidget {
  const ForaneoHome({super.key, required this.onTheme});
  final ValueChanged<ThemeMode> onTheme;
  @override
  State<ForaneoHome> createState() => _ForaneoHomeState();
}

class _ForaneoHomeState extends State<ForaneoHome> with WidgetsBindingObserver {
  LocalVault? vault;
  bool loading = true,
      authenticated = false,
      notifications = false,
      widgetSharing = false,
      loadFailed = false;
  String mode = 'system',
      inventoryQuery = '',
      category = 'Todo',
      recipeQuery = '';
  int section = 0, recipePage = 0;
  bool settings = false, pantryOnly = false, favoritesOnly = false;
  DateTime agendaDay = dayOnly(DateTime.now()),
      mealWeek = monday(DateTime.now());
  List<AppProduct> products = [];
  List<TodoEntry> todos = [];
  List<Recipe> customRecipes = [];
  List<Map<String, dynamic>> catalog = [];
  Map<String, String> meals = {};
  Set<String> favorites = {};
  Future<void> saveQueue = Future.value();
  final searchController = TextEditingController();
  static DateTime monday(DateTime date) =>
      dayOnly(date).subtract(Duration(days: date.weekday - 1));
  static const names = ['Inicio', 'Despensa', 'Compras', 'Cocina', 'Agenda'];
  static const icons = [
    Icons.cottage_outlined,
    Icons.kitchen_outlined,
    Icons.shopping_bag_outlined,
    Icons.restaurant_menu,
    Icons.calendar_month_outlined,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(boot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && authenticated) {
      unawaited(launchSection());
    }
  }

  Future<void> boot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      vault = LocalVault(prefs);
      catalog = await OfflineRecipes.load();
      if (!vault!.hasProfile && (prefs.getBool('foraneo_guest_v2') ?? false)) {
        await restore();
        authenticated = true;
      }
    } catch (_) {
      loadFailed = true;
    }
    if (mounted) setState(() => loading = false);
    if (authenticated) {
      unawaited(launchSection());
      unawaited(restoreReminders());
    }
  }

  Map<String, dynamic> snapshot() => {
    'version': 2,
    'products': products.map((p) => p.toJson()).toList(),
    'todos': todos.map((t) => t.toJson()).toList(),
    'recipes': customRecipes.map((r) => r.toJson()).toList(),
    'meals': meals,
    'favorites': favorites.toList(),
    'settings': {
      'theme': mode,
      'notifications': notifications,
      'widgetSharing': widgetSharing,
    },
  };
  Future<void> restore() async {
    final data = await vault!.read();
    if (data == null) {
      products = [
        AppProduct(
          id: 'pasta',
          name: 'Pasta',
          description: 'Ejemplo · edítalo con tu compra real',
          amount: 250,
          unit: 'g',
          stock: 2,
          lowAt: 1,
          referencePrice: 20,
        ),
        AppProduct(
          id: 'avena',
          name: 'Avena',
          amount: 500,
          unit: 'g',
          stock: 1,
          lowAt: 1,
          referencePrice: 32,
        ),
        AppProduct(
          id: 'jabon',
          name: 'Jabón de manos',
          category: 'Higiene',
          amount: 250,
          unit: 'ml',
          stock: 0,
          lowAt: 1,
          referencePrice: 35,
        ),
      ];
      todos = [];
      customRecipes = [];
      meals = {};
      favorites = {};
      return;
    }
    List<Map<String, dynamic>> entries(String key) => data[key] is List
        ? (data[key] as List)
              .whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v))
              .toList()
        : [];
    // Empty saved collections are intentional: never resurrect starter data.
    products = entries('products').map(AppProduct.fromJson).toList();
    todos = entries('todos').map(TodoEntry.fromJson).toList();
    customRecipes = entries(
      'recipes',
    ).map(Recipe.fromJson).where((r) => r.allowed).toList();
    meals = data['meals'] is Map
        ? (data['meals'] as Map).map((key, value) => MapEntry('$key', '$value'))
        : {};
    favorites = data['favorites'] is List
        ? (data['favorites'] as List).map((v) => '$v').toSet()
        : {};
    final preferences = data['settings'] is Map ? data['settings'] as Map : {};
    mode = ['light', 'dark', 'system'].contains(preferences['theme'])
        ? '${preferences['theme']}'
        : 'system';
    notifications = preferences['notifications'] == true;
    widgetSharing = preferences['widgetSharing'] == true;
    widget.onTheme(ThemeMode.values.firstWhere((v) => v.name == mode));
  }

  Future<void> enter({bool guest = false}) async {
    try {
      if (guest) await vault!.preferences.setBool('foraneo_guest_v2', true);
      await restore();
      if (!mounted) return;
      setState(() => authenticated = true);
      await store();
      await restoreReminders();
      await launchSection();
    } catch (_) {
      snack('No se pudieron abrir tus datos. No se han sobrescrito.');
    }
  }

  Future<void> store() {
    final data = jsonDecode(jsonEncode(snapshot())) as Map<String, dynamic>;
    saveQueue = saveQueue.then((_) async {
      try {
        await vault!.save(data);
      } catch (_) {
        snack(
          'No se guardaron los cambios. Revisa el espacio disponible y exporta un respaldo.',
        );
      }
    });
    unawaited(updateWidgets());
    return saveQueue;
  }

  void changed() {
    setState(() {});
    unawaited(store());
  }

  void snack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;
  List<AppProduct> get shopping =>
      products.where((p) => p.stockState != StockState.enough).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));
  List<AppProduct> get urgent =>
      products.where((p) => p.stockState == StockState.empty).toList();
  List<String> get pantry => products
      .where((p) => p.stock > 0 && p.category == 'Comida')
      .map((p) => p.name)
      .toList();
  List<Map<String, dynamic>> get allRecipes => [
    ...customRecipes.map((r) => r.toJson()),
    ...catalog,
  ];
  Recipe? recipeById(String? id) {
    if (id == null) return null;
    for (final r in customRecipes) {
      if (r.id == id) return r;
    }
    for (final r in catalog) {
      if ('${r['id']}' == id) return Recipe.fromJson(r);
    }
    return null;
  }

  Future<void> launchSection() async {
    final target = await NativeServices.takeLaunchSection();
    final index = {
      'summary': 0,
      'home': 0,
      'shopping': 2,
      'compras': 2,
      'kitchen': 3,
      'cocina': 3,
      'agenda': 4,
    }[target];
    if (mounted && index != null) {
      setState(() {
        section = index;
        settings = false;
      });
    }
  }

  Future<void> updateWidgets() async {
    final today = dateKey(DateTime.now());
    final todayTasks = todos
        .where((t) => !t.done && dateKey(t.date) == today)
        .map((t) => '${timeLabel(t.date)} ${t.title}')
        .take(5)
        .join('\n');
    final todayMeals = ['Desayuno', 'Comida', 'Cena']
        .map((slot) {
          final r = recipeById(meals['$today:$slot']);
          return r == null ? '' : '$slot: ${r.title}';
        })
        .where((v) => v.isNotEmpty)
        .join('\n');
    final taskDays = <String, String>{}, mealDays = <String, String>{};
    if (widgetSharing) {
      for (final task
          in (todos.where((t) => !t.done).toList()
            ..sort((a, b) => a.date.compareTo(b.date)))) {
        final key = dateKey(task.date),
            line = '${timeLabel(task.date)} ${task.title}';
        taskDays[key] = taskDays[key] == null
            ? line
            : '${taskDays[key]}\n$line';
      }
      for (final entry in meals.entries) {
        final split = entry.key.split(':');
        if (split.length != 2) continue;
        final recipe = recipeById(entry.value);
        if (recipe == null) continue;
        final line = '${split[1]}: ${recipe.title}';
        mealDays[split[0]] = mealDays[split[0]] == null
            ? line
            : '${mealDays[split[0]]}\n$line';
      }
    }
    await NativeServices.updateWidget(
      shopping: widgetSharing
          ? shopping.map((p) => p.name).take(6).join('\n')
          : 'Activa compartir en Ajustes',
      urgent: widgetSharing ? urgent.map((p) => p.name).take(5).join('\n') : '',
      tasks: widgetSharing ? todayTasks : 'Contenido privado',
      meal: widgetSharing ? todayMeals : 'Contenido privado',
      taskDays: taskDays,
      mealDays: mealDays,
    );
  }

  Future<void> restoreReminders() async {
    if (notifications && await NativeServices.requestNotifications()) {
      for (final task in todos) {
        if (task.done || !task.remind) {
          await NativeServices.cancel(notificationId(task.id));
        } else if (task.date.isAfter(DateTime.now())) {
          await scheduleTask(task);
        }
        // Preserve overdue Android alarms: Doze may deliver them a little late.
      }
    }
    await updateWidgets();
  }

  Future<void> scheduleTask(TodoEntry task) async {
    final id = notificationId(task.id);
    await NativeServices.cancel(id);
    if (notifications &&
        !task.done &&
        task.remind &&
        task.date.isAfter(DateTime.now())) {
      await NativeServices.schedule(
        id: id,
        title: 'Foráneo · ${task.title}',
        body: task.notes.isEmpty ? 'Es momento de tu pendiente.' : task.notes,
        date: task.date,
      );
    }
  }

  void stockNotification(AppProduct product, StockState? previous) {
    if (!notifications ||
        product.stockState == previous ||
        product.stockState == StockState.enough) {
      return;
    }
    unawaited(
      NativeServices.notify(
        id: notificationId(product.id),
        title: product.stockState == StockState.empty
            ? 'Compra urgente · ${product.name}'
            : 'Se está acabando · ${product.name}',
        body: product.stockState == StockState.empty
            ? 'Ya no tienes. Lo agregamos a compra urgente.'
            : 'Te quedan ${product.stock}. Está en tu lista de compras.',
      ),
    );
  }

  Future<void> editProduct([AppProduct? product, String name = '']) async {
    final result = await showDialog<AppProduct>(
      context: context,
      builder: (_) => ProductEditor(
        product: product,
        name: name,
        forShopping: section == 2,
      ),
    );
    if (result == null || !mounted) return;
    final previous = product?.stockState,
        index = products.indexWhere((p) => p.id == result.id);
    if (index < 0) {
      products.add(result);
    } else {
      products[index] = result;
    }
    changed();
    stockNotification(result, previous);
    if (result.category == 'Comida') {
      snack('Guardado. En Cocina puedes buscar recetas con ${result.name}.');
    }
  }

  Future<void> deleteProduct(AppProduct product) async {
    if (!await confirm(
      '¿Eliminar ${product.name}?',
      'Se quitará de la despensa y de compras. No se puede deshacer.',
    )) {
      return;
    }
    products.removeWhere((p) => p.id == product.id);
    changed();
  }

  void changeStock(AppProduct product, int delta) {
    final previous = product.stockState;
    product.stock = (product.stock + delta).clamp(0, 99999);
    changed();
    stockNotification(product, previous);
  }

  Future<void> restock(AppProduct product) async {
    final quantity = TextEditingController(text: '${product.lowAt + 1}'),
        price = TextEditingController(text: '${product.referencePrice}'),
        form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => EditorShell(
        title: 'Compré ${product.name}',
        saveLabel: 'Guardar compra',
        onSave: () {
          if (form.currentState!.validate()) Navigator.pop(context, true);
        },
        child: Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: quantity,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    positiveNumber(v, allowZero: false, integer: true),
                decoration: const InputDecoration(
                  labelText: 'Paquetes comprados',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => positiveNumber(v),
                decoration: const InputDecoration(
                  labelText: 'Nuevo precio habitual por paquete',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Se suman a tu despensa y este precio queda como nueva referencia. Usa Comparar antes de comprar.',
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      final index = products.indexWhere((p) => p.id == product.id);
      if (index >= 0) {
        products[index] = AppProduct.fromJson({
          ...product.toJson(),
          'stock': (product.stock + parseWholeNumber(quantity.text)).clamp(
            0,
            99999,
          ),
          'referencePrice': double.parse(price.text.replaceAll(',', '.')),
        });
      }
      changed();
    }
    quantity.dispose();
    price.dispose();
  }

  Future<void> addMissing(Recipe recipe) async {
    final missing = OfflineRecipes.missingIngredients(recipe.toJson(), pantry);
    var added = 0;
    for (final ingredient in missing) {
      final index = recipe.ingredients.indexOf(ingredient);
      final key = index >= 0 && index < recipe.ingredientKeys.length
          ? recipe.ingredientKeys[index]
          : OfflineRecipes.normalizeIngredient(ingredient);
      if (products.any((p) => OfflineRecipes.ingredientMatches(key, p.name))) {
        continue;
      }
      products.add(
        AppProduct(
          id: '${newId()}-$added',
          name: key.isEmpty
              ? ingredient
              : '${key[0].toUpperCase()}${key.substring(1)}',
          description: 'Para ${recipe.title}: $ingredient',
          stock: 0,
          category: 'Comida',
        ),
      );
      added++;
    }
    changed();
    snack(
      added == 0
          ? 'Los faltantes ya están en tus productos. Revisa sus cantidades.'
          : '$added ingredientes agregados a compra urgente. Revisa las cantidades antes de comprar.',
    );
  }

  Future<void> editTask([TodoEntry? task]) async {
    final result = await showDialog<TodoEntry>(
      context: context,
      builder: (_) => TodoEditor(todo: task, day: agendaDay),
    );
    if (result == null || !mounted) return;
    final index = todos.indexWhere((t) => t.id == result.id);
    if (index < 0) {
      todos.add(result);
    } else {
      todos[index] = result;
    }
    changed();
    await scheduleTask(result);
    if (result.remind && !notifications) {
      snack('Activa Notificaciones en Ajustes para recibir el recordatorio.');
    }
  }

  Future<void> deleteTask(TodoEntry task) async {
    if (!await confirm('¿Eliminar pendiente?', task.title)) return;
    todos.removeWhere((t) => t.id == task.id);
    changed();
    await NativeServices.cancel(notificationId(task.id));
  }

  Future<void> external(Uri uri) async {
    if (uri.scheme != 'https') {
      snack('Este enlace no es seguro.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        snack('No se pudo abrir el navegador.');
      }
    } catch (_) {
      snack('No se pudo abrir el enlace.');
    }
  }

  void googleCalendar(TodoEntry task) {
    String stamp(DateTime date) =>
        '${date.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z';
    unawaited(
      external(
        Uri.https('calendar.google.com', '/calendar/render', {
          'action': 'TEMPLATE',
          'text': task.title,
          'details': task.notes,
          'dates':
              '${stamp(task.date)}/${stamp(task.date.add(const Duration(hours: 1)))}',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (loadFailed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'No pudimos abrir el almacenamiento o el recetario. Tus datos no se han sobrescrito.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      loadFailed = false;
                      loading = true;
                    });
                    unawaited(boot());
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!authenticated) {
      return AuthScreen(
        vault: vault!,
        onGuest: () => enter(guest: true),
        onUnlocked: () => enter(),
        onCreate: (username, password, pin) async {
          await restore();
          await vault!.createProfile(username, password, snapshot());
          if (pin.isNotEmpty) await vault!.setPin(pin);
          await enter();
        },
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.asset('assets/logo.png', width: 38, height: 38),
            ),
            const SizedBox(width: 10),
            const Text(
              'Foráneo',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => setState(() => settings = !settings),
            icon: Icon(settings ? Icons.close : Icons.tune),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: settings ? null : section,
                onDestinationSelected: (i) => setState(() {
                  section = i;
                  settings = false;
                }),
                labelType: NavigationRailLabelType.all,
                destinations: List.generate(
                  names.length,
                  (i) => NavigationRailDestination(
                    icon: Icon(icons[i]),
                    label: Text(names[i]),
                  ),
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: SingleChildScrollView(
                    key: ValueKey(settings ? 'settings' : section),
                    padding: EdgeInsets.fromLTRB(
                      wide ? 30 : 18,
                      12,
                      wide ? 30 : 18,
                      32,
                    ),
                    child: settings
                        ? settingsPage()
                        : [
                            homePage,
                            pantryPage,
                            shoppingPage,
                            kitchenPage,
                            agendaPage,
                          ][section](),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: section,
              onDestinationSelected: (i) => setState(() {
                section = i;
                settings = false;
              }),
              destinations: List.generate(
                names.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i], size: 23),
                  label: names[i],
                ),
              ),
            ),
    );
  }

  Widget heading(
    String eyebrow,
    String title,
    String subtitle, {
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action),
      ],
    ),
  );
  Widget panel(Widget child, {EdgeInsets? padding}) => Card(
    child: Padding(padding: padding ?? const EdgeInsets.all(20), child: child),
  );
  Widget empty(
    IconData icon,
    String title,
    String description, {
    Widget? action,
  }) => panel(
    Column(
      children: [
        const SizedBox(height: 12),
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 14), child: action),
        const SizedBox(height: 12),
      ],
    ),
  );
  Widget sectionTitle(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
  Widget badge(String text, {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }

  Widget responsiveCards(List<Widget> children, {double minimum = 290}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / minimum).floor().clamp(1, 3);
          final width = (constraints.maxWidth - (count - 1) * 14) / count;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: children
                .map((child) => SizedBox(width: width, child: child))
                .toList(),
          );
        },
      );
  Widget homePage() {
    final todayTasks =
        todos
            .where(
              (task) =>
                  dateKey(task.date) == dateKey(DateTime.now()) && !task.done,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final picks = OfflineRecipes.recommend(
      recipes: allRecipes,
      pantry: pantry,
      limit: 2,
    ).map(Recipe.fromJson).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          shortDate(DateTime.now()),
          'Hola, foráneo',
          'Un poquito de orden. Mucho más hogar.',
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xff0b3a31)),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  top: -40,
                  child: Opacity(
                    opacity: .32,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/photos/ensalada.jpg',
                        width: 265,
                        height: 265,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TU CASA, CONTIGO',
                        style: TextStyle(
                          color: Color(0xffa9dac0),
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SizedBox(
                        width: 310,
                        child: Text(
                          'Vivir por tu cuenta,\nsentirte en casa.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SizedBox(
                        width: 280,
                        child: Text(
                          'Tu despensa y tus planes en un lugar. Incluso sin internet.',
                          style: TextStyle(color: Color(0xffe3eee7)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffd9efb9),
                          foregroundColor: const Color(0xff163d30),
                        ),
                        onPressed: () => setState(() => section = 3),
                        icon: const Icon(Icons.restaurant_menu, size: 18),
                        label: const Text('¿Qué cocinamos hoy?'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        responsiveCards([
          metric(
            'En casa',
            '${products.length}',
            'productos registrados',
            Icons.kitchen_outlined,
          ),
          metric(
            'Urgentes',
            '${urgent.length}',
            'productos agotados',
            Icons.shopping_bag_outlined,
            alert: urgent.isNotEmpty,
          ),
          metric(
            'Para hoy',
            '${todayTasks.length}',
            'pendientes por completar',
            Icons.task_alt,
          ),
        ], minimum: 155),
        sectionTitle(
          'Lo que necesita tu hogar',
          action: TextButton(
            onPressed: () => setState(() => section = 2),
            child: const Text('Ver compras'),
          ),
        ),
        if (shopping.isEmpty)
          empty(
            Icons.check_circle_outline,
            'Todo en orden',
            'Tu despensa está por encima de los mínimos que configuraste.',
          )
        else
          ...shopping
              .take(3)
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: panel(
                    Row(
                      children: [
                        Icon(
                          p.stock == 0
                              ? Icons.error_outline
                              : Icons.inventory_2_outlined,
                          color: const Color(0xffbf4337),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                p.stock == 0
                                    ? 'Agotado · compra urgente'
                                    : 'Quedan ${p.stock} · toca reponer',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Registrar compra',
                          onPressed: () => restock(p),
                          icon: const Icon(Icons.add_shopping_cart),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        sectionTitle(
          'Algo rico, sin complicarte',
          action: TextButton(
            onPressed: () => setState(() => section = 3),
            child: const Text('Explorar'),
          ),
        ),
        responsiveCards(picks.map(recipeCard).toList()),
        sectionTitle('Tu día, a tu ritmo'),
        if (todayTasks.isEmpty)
          empty(
            Icons.wb_sunny_outlined,
            'Un espacio para ti',
            'No hay pendientes para hoy.',
            action: OutlinedButton(
              onPressed: () {
                agendaDay = dayOnly(DateTime.now());
                editTask();
              },
              child: const Text('Añadir pendiente'),
            ),
          )
        else
          ...todayTasks.take(3).map(taskCard),
      ],
    );
  }

  Widget metric(
    String title,
    String value,
    String subtitle,
    IconData icon, {
    bool alert = false,
  }) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: alert
              ? const Color(0xffbf4337)
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: alert ? const Color(0xffbf4337) : null,
          ),
        ),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.all(18),
  );
  Widget pantryPage() {
    final filtered = products
        .where(
          (p) =>
              (category == 'Todo' || p.category == category) &&
              normalized(
                '${p.name} ${p.description}',
              ).contains(normalized(inventoryQuery)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Tu despensa',
          'Lo bueno de estar en casa.',
          'Alimentos, higiene, limpieza y todo lo que hace funcionar tu hogar.',
          action: FilledButton.icon(
            onPressed: () => editProduct(),
            icon: const Icon(Icons.add),
            label: const Text('Añadir producto'),
          ),
        ),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Buscar producto o marca',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => inventoryQuery = v),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Todo', ...productCategories]
                .map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(v),
                      selected: category == v,
                      onSelected: (_) => setState(() => category = v),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${filtered.length} productos · toca editar para cambiar foto, precio o características',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          empty(
            Icons.inventory_2_outlined,
            'Tu despensa empieza aquí',
            'Añade una compra o cambia los filtros para ver tus productos.',
          )
        else
          responsiveCards(filtered.map((p) => productCard(p)).toList()),
      ],
    );
  }

  IconData categoryIcon(String value) => switch (value) {
    'Comida' => Icons.restaurant_outlined,
    'Higiene' => Icons.sanitizer_outlined,
    'Lavar' => Icons.local_laundry_service_outlined,
    'Baño' => Icons.bathtub_outlined,
    'Tecnología' => Icons.devices_outlined,
    'Cocina' => Icons.kitchen_outlined,
    _ => Icons.cottage_outlined,
  };
  Widget productCard(AppProduct p, {bool buy = false}) {
    final color = p.stockState == StockState.enough
        ? Theme.of(context).colorScheme.primary
        : const Color(0xffbf4337);
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 72,
                  height: 72,
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: .65),
                  child: p.photo != null
                      ? Image.memory(
                          p.photo!,
                          fit: BoxFit.cover,
                          cacheWidth: 216,
                          errorBuilder: (_, error, stack) =>
                              Icon(categoryIcon(p.category), size: 34),
                        )
                      : Icon(categoryIcon(p.category), size: 34),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.presentation} · ${p.category}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '\$${p.referencePrice.toStringAsFixed(2)} MXN',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones de ${p.name}',
                onSelected: (v) {
                  if (v == 'edit') editProduct(p);
                  if (v == 'delete') deleteProduct(p);
                  if (v == 'compare') compare(p);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'compare',
                    child: Text('Comparar precio'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          if (p.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                p.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          badge(
            p.stockState == StockState.empty
                ? 'Agotado · compra urgente'
                : p.stockState == StockState.low
                ? 'Queda poco · por comprar'
                : 'En casa · suficiente',
            color: color,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p.stock} paquetes en casa',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Consumir uno de ${p.name}',
                onPressed: p.stock == 0 ? null : () => changeStock(p, -1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: 'Sumar uno de ${p.name}',
                onPressed: () => changeStock(p, 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (buy)
                FilledButton.icon(
                  onPressed: () => restock(p),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Ya lo compré'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => editProduct(p),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              TextButton(
                onPressed: () => compare(p),
                child: const Text('Comparar precio'),
              ),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
    );
  }

  Widget shoppingPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Compras con cabeza',
        'Lo que hace falta.',
        'Los productos con pocas existencias aparecen aquí automáticamente.',
        action: FilledButton.icon(
          onPressed: () => editProduct(),
          icon: const Icon(Icons.add),
          label: const Text('Añadir a compras'),
        ),
      ),
      panel(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.savings_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu precio, en perspectiva',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Compara por el mismo contenido, aunque cambie el tamaño del paquete. Precio rojo: no comprar. Verde: autorizado. Una gran bajada merece aprovecharse.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      sectionTitle('Compra urgente · ${urgent.length}'),
      if (urgent.isEmpty)
        empty(
          Icons.verified_outlined,
          'Sin urgencias',
          'No tienes productos agotados.',
        )
      else
        responsiveCards(urgent.map((p) => productCard(p, buy: true)).toList()),
      sectionTitle('Por comprar · ${shopping.length - urgent.length}'),
      if (shopping.length == urgent.length)
        empty(
          Icons.shopping_basket_outlined,
          'Un pendiente menos',
          'Aquí verás los productos que todavía tienes, pero ya se están acabando.',
        )
      else
        responsiveCards(
          shopping
              .where((p) => p.stock > 0)
              .map((p) => productCard(p, buy: true))
              .toList(),
        ),
      const SizedBox(height: 16),
      const Text(
        'Eliminar un producto en Compras también lo elimina de Despensa. Para conservarlo, registra una reposición. El margen superior para precios mayores de \$1,000 es 1%.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
  Future<void> compare(AppProduct p) async {
    final offered = TextEditingController(),
        amount = TextEditingController(text: '${p.amount}');
    var unit = p.unit;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final price = double.tryParse(offered.text.replaceAll(',', '.')),
              quantity = double.tryParse(amount.text.replaceAll(',', '.'));
          final equivalent = price == null || quantity == null
              ? null
              : comparablePrice(
                  referenceAmount: p.amount,
                  referenceUnit: p.unit,
                  offeredAmount: quantity,
                  offeredUnit: unit,
                  offeredPrice: price,
                );
          final decision = equivalent == null
              ? null
              : decidePrice(p.referencePrice, equivalent);
          return EditorShell(
            title: '¿Conviene comprar?',
            saveLabel: 'Listo',
            onSave: () => Navigator.pop(dialogContext),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Referencia: \$${p.referencePrice.toStringAsFixed(2)} por ${p.presentation}',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: offered,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => update(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Precio que ves hoy',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => update(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Contenido ofrecido',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: unit,
                        isExpanded: true,
                        items: {...productUnits, unit}
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => update(() => unit = v!),
                        decoration: const InputDecoration(labelText: 'Unidad'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (decision != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: decision.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(decision.symbol, color: decision.color, size: 34),
                        const SizedBox(height: 10),
                        Text(
                          decision.title,
                          style: TextStyle(
                            color: decision.color,
                            fontWeight: FontWeight.w800,
                            fontSize: 23,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(decision.message),
                        const SizedBox(height: 10),
                        Text(
                          'Equivale a \$${equivalent!.toStringAsFixed(2)} por ${p.presentation}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Escribe un precio válido y un contenido mayor que cero. Las unidades deben ser compatibles.',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Esta comparación no modifica tu precio habitual.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
    offered.dispose();
    amount.dispose();
  }

  String recipeImage(Recipe recipe) {
    final name = recipe.image.split('/').last;
    if ([
      'pasta.jpg',
      'avena.jpg',
      'tacos.jpg',
      'arroz.jpg',
      'ensalada.jpg',
    ].contains(name)) {
      return 'assets/photos/$name';
    }
    final title = normalized(recipe.title);
    return 'assets/photos/${title.contains('pasta')
        ? 'pasta'
        : title.contains('avena')
        ? 'avena'
        : title.contains('taco')
        ? 'tacos'
        : title.contains('arroz')
        ? 'arroz'
        : 'ensalada'}.jpg';
  }

  Widget recipeCard(Recipe recipe) {
    final missing = recipe.missing(products);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showRecipe(recipe),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.asset(
                  recipeImage(recipe),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 700,
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: IconButton.filledTonal(
                    tooltip: favorites.contains(recipe.id)
                        ? 'Quitar de favoritos'
                        : 'Guardar favorito',
                    onPressed: () {
                      favorites.contains(recipe.id)
                          ? favorites.remove(recipe.id)
                          : favorites.add(recipe.id);
                      changed();
                    },
                    icon: Icon(
                      favorites.contains(recipe.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xfff7f7ef),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      recipe.minutes,
                      style: const TextStyle(
                        color: Color(0xff173d30),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${recipe.servings} porciones · ${recipe.ingredients.length} ingredientes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  badge(
                    missing.isEmpty
                        ? 'Tienes los ingredientes*'
                        : 'Faltan ${missing.length} ingredientes',
                    color: missing.isEmpty ? null : const Color(0xffa05c14),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ver paso a paso',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget kitchenPage() {
    final source = allRecipes
        .where(
          (r) =>
              (!favoritesOnly || favorites.contains('${r['id']}')) &&
              (!pantryOnly ||
                  OfflineRecipes.missingIngredients(r, pantry).isEmpty),
        )
        .toList();
    final results = OfflineRecipes.recommend(
      recipes: source,
      query: recipeQuery,
      pantry: pantry,
      limit: 13,
      offset: recipePage * 12,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Cocina local',
          'Hoy se come rico.',
          '${catalog.length} variantes detalladas, listas sin internet. Tu despensa nos ayuda a ordenarlas.',
          action: OutlinedButton.icon(
            onPressed: createRecipe,
            icon: const Icon(Icons.add),
            label: const Text('Agregar mi receta'),
          ),
        ),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '¿Qué se te antoja?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('recipe-query'),
                decoration: const InputDecoration(
                  hintText: 'Ej. pasta con tomate, cena, avena…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() {
                  recipeQuery = value;
                  recipePage = 0;
                }),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Con lo que tengo'),
                    selected: pantryOnly,
                    onSelected: (v) => setState(() {
                      pantryOnly = v;
                      recipePage = 0;
                    }),
                  ),
                  FilterChip(
                    label: const Text('Mis favoritos'),
                    selected: favoritesOnly,
                    onSelected: (v) => setState(() {
                      favoritesOnly = v;
                      recipePage = 0;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Encuentra recetas por ingredientes, cocina o antojo. Cada ficha incluye cantidades, pasos y lista de faltantes para tu compra.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        mealPlanner(),
        sectionTitle(
          recipeQuery.isEmpty
              ? 'Inspiración para tu mesa'
              : 'Ideas para “$recipeQuery”',
        ),
        if (results.isEmpty)
          empty(
            Icons.manage_search,
            'Busquemos otro antojo',
            pantryOnly
                ? 'No encontramos recetas con todos los ingredientes en tu despensa. Desactiva el filtro para ver faltantes.'
                : 'Prueba un ingrediente diferente o agrega tu propia receta.',
          )
        else
          responsiveCards(
            results.take(12).map(Recipe.fromJson).map(recipeCard).toList(),
          ),
        if (recipePage > 0 || results.length > 12)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              children: [
                Text('Página ${recipePage + 1}', textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: recipePage == 0
                            ? null
                            : () => setState(() => recipePage--),
                        child: const Text('Anterior'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: results.length <= 12
                            ? null
                            : () => setState(() => recipePage++),
                        child: const Text('Más ideas'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> createRecipe() async {
    final recipe = await showDialog<Recipe>(
      context: context,
      builder: (_) => const RecipeEditor(),
    );
    if (recipe == null || !mounted) return;
    customRecipes.add(recipe);
    favorites.add(recipe.id);
    changed();
    showRecipe(recipe);
  }

  Future<void> showRecipe(Recipe recipe) async {
    final checkedIngredients = <int>{}, checkedSteps = <int>{};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final missing = recipe.missing(products);
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 20,
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'A cocinar, paso a paso',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar receta',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              recipeImage(recipe),
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            recipe.imageCaption.isEmpty
                                ? 'Fotografía ilustrativa; el resultado puede variar.'
                                : recipe.imageCaption,
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            recipe.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(recipe.description),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              badge(recipe.minutes),
                              badge('${recipe.servings} porciones'),
                              badge(recipe.tag),
                            ],
                          ),
                          if (recipe.allergens.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                'Alérgenos indicados: ${recipe.allergens.join(', ')}. Revisa también las etiquetas y posibles trazas.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (recipe.equipment.isNotEmpty) ...[
                            sectionTitle('Antes de empezar'),
                            Text('Utensilios: ${recipe.equipment.join(', ')}.'),
                          ],
                          sectionTitle('Todos los ingredientes'),
                          const Text(
                            'Las cantidades son para las porciones indicadas. La despensa comprueba presencia, no cantidad restante.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          ...recipe.ingredients.indexed.map(
                            (entry) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: checkedIngredients.contains(entry.$1),
                              onChanged: (value) => update(() {
                                value == true
                                    ? checkedIngredients.add(entry.$1)
                                    : checkedIngredients.remove(entry.$1);
                              }),
                              title: Text(
                                entry.$2,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: missing.contains(entry.$2)
                                  ? const Text(
                                      'Falta en despensa',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xffbf4337),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          if (missing.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await addMissing(recipe);
                                  update(() {});
                                },
                                icon: const Icon(Icons.add_shopping_cart),
                                label: Text(
                                  'A compras · ${missing.length} faltantes',
                                ),
                              ),
                            ),
                          sectionTitle('Preparación detallada'),
                          Text(
                            '${checkedSteps.length} de ${recipe.steps.length} pasos completados',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          ...recipe.steps.indexed.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: checkedSteps.contains(entry.$1),
                                      onChanged: (value) => update(() {
                                        value == true
                                            ? checkedSteps.add(entry.$1)
                                            : checkedSteps.remove(entry.$1);
                                      }),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PASO ${entry.$1 + 1}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            entry.$2,
                                            style: TextStyle(
                                              height: 1.55,
                                              decoration:
                                                  checkedSteps.contains(
                                                    entry.$1,
                                                  )
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (recipe.notes.isNotEmpty) ...[
                            sectionTitle('Consejos y conservación'),
                            ...recipe.notes.map(
                              (note) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text('• $note'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  favorites.contains(recipe.id)
                                      ? favorites.remove(recipe.id)
                                      : favorites.add(recipe.id);
                                  changed();
                                  update(() {});
                                },
                                icon: Icon(
                                  favorites.contains(recipe.id)
                                      ? Icons.favorite
                                      : Icons.favorite_outline,
                                ),
                                label: Text(
                                  favorites.contains(recipe.id)
                                      ? 'Guardada'
                                      : 'Guardar favorita',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => planRecipe(recipe),
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: const Text('Planear comida'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => external(
                                  recipe.videoUrl.isNotEmpty
                                      ? Uri.parse(recipe.videoUrl)
                                      : Uri.https('www.youtube.com', '/results', {
                                          'search_query':
                                              '${recipe.title} receta paso a paso',
                                        }),
                                ),
                                icon: const Icon(Icons.play_circle_outline),
                                label: Text(
                                  recipe.videoUrl.isNotEmpty
                                      ? 'Abrir video'
                                      : 'Buscar en YouTube',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'YouTube requiere internet. Los resultados de búsqueda no están verificados y pueden usar otros ingredientes.',
                            style: TextStyle(fontSize: 11),
                          ),
                          if (recipe.source.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                recipe.source,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          if (customRecipes.any((r) => r.id == recipe.id))
                            TextButton.icon(
                              onPressed: () async {
                                if (!await confirm(
                                  '¿Eliminar tu receta?',
                                  'También se quitará de favoritos y del plan semanal.',
                                )) {
                                  return;
                                }
                                customRecipes.removeWhere(
                                  (r) => r.id == recipe.id,
                                );
                                favorites.remove(recipe.id);
                                meals.removeWhere(
                                  (key, value) => value == recipe.id,
                                );
                                changed();
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar mi receta'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget mealPlanner() => Card(
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      title: const Text(
        'Tu menú de la semana',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('Desayuno, comida y cena · tú eliges'),
      leading: const Icon(Icons.calendar_view_week),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Semana anterior de cocina',
              onPressed: () => setState(
                () => mealWeek = mealWeek.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${shortDate(mealWeek)} — ${shortDate(mealWeek.add(const Duration(days: 6)))}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Semana siguiente de cocina',
              onPressed: () => setState(
                () => mealWeek = mealWeek.add(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        ...List.generate(7, (index) {
          final date = mealWeek.add(Duration(days: index));
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortDate(date),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...['Desayuno', 'Comida', 'Cena'].map((slot) {
                    final recipe = recipeById(meals['${dateKey(date)}:$slot']);
                    return Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            slot,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            onPressed: () => chooseMeal(date, slot),
                            child: Text(
                              recipe?.title ?? '+ Elegir receta',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        if (recipe != null)
                          IconButton(
                            tooltip: 'Abrir receta de $slot',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => showRecipe(recipe),
                            icon: const Icon(Icons.open_in_new, size: 17),
                          ),
                      ],
                    );
                  }),
                ],
              ),
              padding: const EdgeInsets.all(12),
            ),
          );
        }),
      ],
    ),
  );
  Future<void> chooseMeal(DateTime date, String slot) async {
    var query = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final options = OfflineRecipes.recommend(
            recipes: allRecipes,
            query: query,
            pantry: pantry,
            limit: 40,
          );
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$slot · ${shortDate(date)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar selector',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar una receta',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => update(() => query = value),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: options
                            .map(
                              (r) => ListTile(
                                title: Text('${r['title']}'),
                                subtitle: Text('${r['minutes']}'),
                                onTap: () =>
                                    Navigator.pop(dialogContext, '${r['id']}'),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    if (options.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Sin coincidencias. Prueba otro ingrediente.',
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, '#remove'),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Dejar esta comida sin plan'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final key = '${dateKey(date)}:$slot';
    if (result == '#remove') {
      meals.remove(key);
    } else {
      meals[key] = result;
    }
    changed();
  }

  Future<void> planRecipe(Recipe recipe) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final slot = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('¿En qué momento?'),
        children: ['Desayuno', 'Comida', 'Cena']
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, s),
                child: Text(s),
              ),
            )
            .toList(),
      ),
    );
    if (slot == null || !mounted) return;
    meals['${dateKey(date)}:$slot'] = recipe.id;
    changed();
    snack('${recipe.title} se agregó a $slot del ${shortDate(date)}.');
  }

  Widget taskCard(TodoEntry task) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: panel(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.done,
            onChanged: (value) {
              task.done = value == true;
              changed();
              unawaited(scheduleTask(task));
            },
          ),
          Expanded(
            child: InkWell(
              onTap: () => editTask(task),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${shortDate(task.date)} · ${timeLabel(task.date)}${task.remind ? ' · recordatorio' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: !task.done && task.date.isBefore(DateTime.now())
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (task.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          task.notes,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones de ${task.title}',
            onSelected: (action) {
              if (action == 'edit') editTask(task);
              if (action == 'delete') deleteTask(task);
              if (action == 'calendar') googleCalendar(task);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar pendiente')),
              PopupMenuItem(
                value: 'calendar',
                child: Text('Agregar a Google Calendar'),
              ),
              PopupMenuItem(value: 'delete', child: Text('Eliminar pendiente')),
            ],
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
  );
  Widget agendaPage() {
    final selectedTasks =
        todos.where((task) => dateKey(task.date) == dateKey(agendaDay)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final start = monday(agendaDay);
    final pending =
        todos
            .where((t) => !t.done && t.date.isBefore(dayOnly(DateTime.now())))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Tu tiempo también es hogar',
          'Un día a la vez.',
          'Recordatorios, pequeños planes y cosas importantes.',
          action: FilledButton.icon(
            onPressed: () => editTask(),
            icon: const Icon(Icons.add),
            label: const Text('Añadir pendiente'),
          ),
        ),
        calendar(),
        const SizedBox(height: 8),
        sectionTitle('El ${shortDate(agendaDay)}'),
        if (selectedTasks.isEmpty)
          empty(
            Icons.event_available_outlined,
            'Este día tiene espacio',
            'Agrega un pendiente para esta fecha y elige si quieres recibir un recordatorio.',
          )
        else
          ...selectedTasks.map(taskCard),
        sectionTitle('Plan de la semana'),
        ...List.generate(7, (index) {
          final date = start.add(Duration(days: index));
          final items =
              todos.where((t) => dateKey(t.date) == dateKey(date)).toList()
                ..sort((a, b) => a.date.compareTo(b.date));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                initiallyExpanded: dateKey(date) == dateKey(agendaDay),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                title: Text(
                  shortDate(date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${items.where((t) => !t.done).length} por completar · ${items.where((t) => t.done).length} hechos',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                children: [
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Sin pendientes para este día.'),
                    ),
                  ...items.map(taskCard),
                  TextButton.icon(
                    onPressed: () {
                      agendaDay = date;
                      editTask();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar a este día'),
                  ),
                ],
              ),
            ),
          );
        }),
        if (pending.isNotEmpty) ...[
          sectionTitle('Pendientes de días anteriores'),
          ...pending.take(12).map(taskCard),
        ],
        const SizedBox(height: 16),
        panel(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu agenda y Google Calendar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8),
              Text(
                'En las opciones de un pendiente elige “Agregar a Google Calendar”. Se abre un evento con su título, hora y notas para que confirmes guardarlo. Es una exportación de una sola vía: no lee ni sincroniza tu calendario. Evita guardarlo dos veces.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget calendar() {
    const monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final first = DateTime(agendaDay.year, agendaDay.month, 1),
        days = DateTime(agendaDay.year, agendaDay.month + 1, 0).day,
        offset = first.weekday - 1;
    final cells = ((offset + days) / 7).ceil() * 7;
    return panel(
      Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => setState(
                  () => agendaDay = DateTime(
                    agendaDay.year,
                    agendaDay.month - 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${monthNames[agendaDay.month - 1]} ${agendaDay.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => setState(
                  () => agendaDay = DateTime(
                    agendaDay.year,
                    agendaDay.month + 1,
                    1,
                  ),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                .map(
                  (s) => Expanded(
                    child: Text(
                      s,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
              childAspectRatio: .92,
            ),
            itemBuilder: (context, index) {
              final number = index - offset + 1;
              if (number < 1 || number > days) return const SizedBox.shrink();
              final date = DateTime(agendaDay.year, agendaDay.month, number),
                  selected = number == agendaDay.day;
              final hasTasks = todos.any(
                (t) => dateKey(t.date) == dateKey(date) && !t.done,
              );
              return Semantics(
                label:
                    '${shortDate(date)}${hasTasks ? ', con pendientes' : ''}',
                selected: selected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => agendaDay = date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: dateKey(date) == dateKey(DateTime.now())
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.normal,
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasTasks
                                ? (selected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  setState(() => agendaDay = dayOnly(DateTime.now())),
              child: const Text('Ir a hoy'),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
    );
  }

  Future<void> setNotifications(bool value) async {
    if (value && !await NativeServices.requestNotifications()) {
      snack('No se concedió permiso. Actívalo en los ajustes del sistema.');
      return;
    }
    if (!mounted) return;
    notifications = value;
    changed();
    if (value) {
      for (final task in todos) {
        if (task.date.isAfter(DateTime.now())) await scheduleTask(task);
      }
    } else {
      for (final task in todos) {
        await NativeServices.cancel(notificationId(task.id));
      }
      for (final p in products) {
        await NativeServices.cancel(notificationId(p.id));
      }
    }
  }

  Future<void> pinHomeWidget(String type) async {
    await updateWidgets();
    final accepted = await NativeServices.pinWidget(type: type);
    if (!accepted) {
      snack(
        'Tu launcher no permite fijarlo directamente. Mantén pulsada la pantalla de inicio y busca Foráneo en Widgets.',
      );
    } else {
      snack('Confirma la colocación del widget en tu pantalla de inicio.');
    }
  }

  Future<void> lockProfile() async {
    await saveQueue;
    if (!mounted) return;
    vault!.lock();
    setState(() {
      authenticated = false;
      settings = false;
      products = [];
      todos = [];
      customRecipes = [];
      favorites = {};
      meals = {};
    });
  }

  Future<void> configurePin() async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(vault!.hasPin ? 'Cambiar PIN' : 'Crear PIN de acceso'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'PIN de 6 dígitos',
              helperText:
                  'Solo sirve para este dispositivo; conserva tu contraseña.',
            ),
            validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                ? null
                : 'Usa exactamente 6 dígitos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              await vault!.setPin(controller.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Guardar PIN'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == true && mounted) snack('PIN de acceso actualizado.');
  }

  Future<void> configureBiometrics() async {
    final enabled = await vault!.enableBiometrics();
    if (!mounted) return;
    snack(
      enabled
          ? 'Biometría activada para este perfil y dispositivo.'
          : 'No fue posible activar la biometría. Verifica el bloqueo seguro del dispositivo.',
    );
    setState(() {});
  }

  Future<void> exportBackup() async {
    if (!await confirm(
      'Exportar respaldo sin cifrar',
      'El archivo JSON contendrá tus productos, fotografías, recetas y agenda en texto legible. No incluye tu contraseña. Guárdalo en un lugar privado y no lo compartas públicamente.',
    )) {
      return;
    }
    try {
      await saveQueue;
      final bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'foraneo-native-backup',
            'version': 2,
            'createdAt': DateTime.now().toIso8601String(),
            'data': snapshot(),
          }),
        ),
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar respaldo de Foráneo',
        fileName: 'foraneo-respaldo-${dateKey(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (path != null) {
        snack('Respaldo exportado. Consérvalo en un lugar privado.');
      }
    } catch (_) {
      snack(
        'No se pudo exportar el respaldo. Revisa el espacio disponible y los permisos.',
      );
    }
  }

  Future<void> importBackup() async {
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (selection == null) return;
      final bytes = selection.files.single.bytes;
      if (bytes == null || bytes.length > 40 * 1024 * 1024) {
        throw const FormatException('Archivo inválido o mayor a 40 MB.');
      }
      final envelope = jsonDecode(utf8.decode(bytes));
      if (envelope is! Map ||
          envelope['format'] != 'foraneo-native-backup' ||
          envelope['version'] != 2 ||
          envelope['data'] is! Map) {
        throw const FormatException('No es un respaldo compatible.');
      }
      final data = Map<String, dynamic>.from(envelope['data'] as Map);
      for (final key in ['products', 'todos', 'recipes']) {
        if (data[key] is! List ||
            (data[key] as List).length > 10000 ||
            (data[key] as List).any((item) => item is! Map)) {
          throw const FormatException('Datos inválidos.');
        }
      }
      if (data['meals'] is! Map || data['favorites'] is! List) {
        throw const FormatException('Datos inválidos.');
      }
      // Validate conversion before replacing any persisted state.
      final checkedProducts = (data['products'] as List)
          .map((p) => AppProduct.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
      final checkedTodos = (data['todos'] as List)
          .map((t) => TodoEntry.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      final checkedRecipes = (data['recipes'] as List)
          .map((r) => Recipe.fromJson(Map<String, dynamic>.from(r as Map)))
          .where((r) => r.allowed)
          .toList();
      data['products'] = checkedProducts.map((p) => p.toJson()).toList();
      data['todos'] = checkedTodos.map((t) => t.toJson()).toList();
      data['recipes'] = checkedRecipes.map((r) => r.toJson()).toList();
      // Permissions and home-screen sharing never transfer silently from a file.
      data['settings'] = {
        'theme': mode,
        'notifications': notifications,
        'widgetSharing': widgetSharing,
      };
      if (!await confirm(
        '¿Restaurar este respaldo?',
        'Reemplazará tus ${products.length} productos y ${todos.length} pendientes actuales por ${checkedProducts.length} productos y ${checkedTodos.length} pendientes. Exporta antes si deseas conservarlos. Tu perfil y contraseña no cambian.',
      )) {
        return;
      }
      await saveQueue;
      await vault!.save(data);
      for (final task in todos) {
        await NativeServices.cancel(notificationId(task.id));
      }
      await restore();
      if (!mounted) return;
      changed();
      await restoreReminders();
      snack('Respaldo restaurado correctamente.');
    } catch (_) {
      snack(
        'No se pudo importar: usa un respaldo JSON de Foráneo nativo de menos de 40 MB. No se reemplazaron tus datos si el archivo era inválido.',
      );
    }
  }

  Widget settingsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Así te gusta vivir',
        'Ajustes de tu hogar.',
        'Personaliza Foráneo y mantén el control de tus datos.',
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Elige la luz con la que se siente mejor tu hogar.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'light',
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                      label: Text('Claro'),
                    ),
                    ButtonSegment(
                      value: 'dark',
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                      label: Text('Oscuro'),
                    ),
                    ButtonSegment(
                      value: 'system',
                      icon: Icon(Icons.settings_brightness_outlined, size: 16),
                      label: Text('Auto'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) {
                    mode = value.first;
                    widget.onTheme(
                      ThemeMode.values.firstWhere((v) => v.name == mode),
                    );
                    changed();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      sectionTitle('Avisos que sí ayudan'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: notifications,
              onChanged: setNotifications,
              title: const Text('Notificaciones'),
              subtitle: const Text(
                'Avisos al consumir productos y recordatorios de agenda.',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              NativeServices.isAndroid
                  ? 'Android guarda los recordatorios localmente y puede mostrarlos con la app cerrada o tras reiniciar. Ahorro de batería y modo No molestar pueden retrasarlos. Los avisos de despensa dependen de que registres el consumo.'
                  : 'En computadora los recordatorios requieren Foráneo abierto. El navegador y otras plataformas pueden limitar las notificaciones. Los avisos de despensa dependen de que registres el consumo.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: notifications
                      ? () async {
                          await NativeServices.notify(
                            id: 2147480000,
                            title: 'Foráneo está listo',
                            body:
                                'Así recibirás tus avisos de despensa y agenda.',
                          );
                          snack('Aviso de prueba solicitado al sistema.');
                        }
                      : null,
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                  ),
                  label: const Text('Probar aviso'),
                ),
                if (NativeServices.isAndroid)
                  TextButton(
                    onPressed: NativeServices.openNotificationSettings,
                    child: const Text('Permisos del sistema'),
                  ),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('Tu hogar en la pantalla de inicio'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: widgetSharing,
              onChanged: (value) async {
                if (value &&
                    !await confirm(
                      'Compartir contenido con widgets',
                      'Los nombres de tus compras, pendientes y comidas se guardarán fuera del perfil cifrado para mostrarse en la pantalla de inicio, incluso con el perfil bloqueado. Puedes desactivarlo cuando quieras.',
                    )) {
                  return;
                }
                if (!mounted) return;
                widgetSharing = value;
                changed();
              },
              title: const Text('Compartir con mis widgets'),
              subtitle: const Text(
                'Una elección independiente del perfil privado.',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              NativeServices.isAndroid
                  ? 'Widgets nativos de Android. El launcher decide el tamaño y solicita confirmar dónde colocarlos. Se actualizan al guardar y al cambiar de día.'
                  : 'Los widgets nativos de pantalla de inicio están disponibles en el APK de Android. La web se puede instalar como PWA, pero no crea widgets del sistema.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                        ('summary', 'Resumen', Icons.cottage_outlined),
                        ('shopping', 'Compras', Icons.shopping_bag_outlined),
                        ('agenda', 'Agenda', Icons.calendar_month_outlined),
                        ('kitchen', 'Cocina', Icons.restaurant_menu),
                      ]
                      .map(
                        (entry) => OutlinedButton.icon(
                          onPressed: NativeServices.isAndroid
                              ? () => pinHomeWidget(entry.$1)
                              : null,
                          icon: Icon(entry.$3, size: 17),
                          label: Text(entry.$2),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
      sectionTitle('Privacidad y acceso'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    vault!.hasProfile
                        ? 'Perfil local · ${vault!.username}'
                        : 'Modo invitado',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              vault!.hasProfile
                  ? 'Tus datos se cifran en este dispositivo con AES-GCM y una clave derivada de tu contraseña. No existe cuenta en la nube, recuperación por correo ni sincronización automática. Los avisos autorizados del sistema y widgets compartidos pueden mostrar contenido fuera del cifrado.'
                  : 'Tus datos se guardan solo en este dispositivo, sin cifrar en modo invitado. Puedes crear un perfil local con usuario y contraseña para protegerlos; se conservará tu información.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: vault!.hasProfile
                      ? lockProfile
                      : () async {
                          await saveQueue;
                          if (!mounted) return;
                          setState(() {
                            authenticated = false;
                            settings = false;
                          });
                        },
                  icon: Icon(
                    vault!.hasProfile
                        ? Icons.lock_outline
                        : Icons.person_add_alt,
                  ),
                  label: Text(
                    vault!.hasProfile
                        ? 'Bloquear perfil / cerrar sesión'
                        : 'Crear mi perfil local',
                  ),
                ),
                if (vault!.hasProfile)
                  OutlinedButton.icon(
                    onPressed: configurePin,
                    icon: const Icon(Icons.pin_outlined),
                    label: Text(
                      vault!.hasPin ? 'Cambiar PIN' : 'Crear PIN de acceso',
                    ),
                  ),
                if (vault!.hasProfile && !vault!.biometricEnabled)
                  OutlinedButton.icon(
                    onPressed: configureBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Activar biometría'),
                  ),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('Tus datos, contigo'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Respalda con frecuencia, especialmente antes de desinstalar o cambiar de dispositivo. Los respaldos JSON son legibles y no incluyen contraseña. Son para la app nativa; no sincronizan con la web.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: exportBackup,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Exportar respaldo'),
                ),
                OutlinedButton.icon(
                  onPressed: importBackup,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Importar respaldo'),
                ),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('Cocina y compras'),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recetario sin servicios externos',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${catalog.length} variantes originales de bases culinarias. Recomendación determinista local, no IA generativa. Fotos ilustrativas. Las recetas no contemplan tus alergias individuales: revisa ingredientes y etiquetas.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Puedes guardar tus propias recetas, ingredientes y preparaciones sin restricciones de tipo de comida.',
              style: TextStyle(fontSize: 12),
            ),
            const Divider(height: 28),
            const Text(
              'Márgenes del comparador',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...[
              ('Hasta \$40', '−15% / +10%'),
              ('Hasta \$100', '−15% / +8%'),
              ('Hasta \$200', '−15% / +4%'),
              ('Hasta \$500', '−10% / +3%'),
              ('Hasta \$1,000', '−10% / +2%'),
              ('Más de \$1,000', '−10% / +1%'),
            ].map(
              (band) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        band.$1,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      band.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 30),
      const Center(
        child: Text(
          'Foráneo · versión 2.1.0\nHecho para sentirte en casa.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text(
          'by Joseph Ubaldo Trejo Hernandez',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10),
        ),
      ),
    ],
  );
}
