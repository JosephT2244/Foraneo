import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';

const productCategories = [
  'Comida',
  'Higiene',
  'Cocina',
  'Baño',
  'Lavar',
  'Tecnología',
  'Hogar',
];
const productUnits = ['pieza', 'g', 'kg', 'ml', 'L', 'rollo'];
int parseWholeNumber(String value) =>
    double.parse(value.replaceAll(',', '.')).toInt();
String? requiredText(String? text) =>
    text == null || text.trim().isEmpty ? 'Completa este campo' : null;
String? positiveNumber(
  String? text, {
  bool allowZero = true,
  bool integer = false,
}) {
  final number = double.tryParse((text ?? '').replaceAll(',', '.'));
  if (number == null ||
      !number.isFinite ||
      number < 0 ||
      (!allowZero && number == 0) ||
      number > 1000000 ||
      (integer && number != number.roundToDouble())) {
    return integer
        ? 'Usa un entero de ${allowZero ? 0 : 1} a 1 000 000'
        : 'Escribe un número ${allowZero ? 'no negativo' : 'mayor que 0'}';
  }
  return null;
}

class EditorShell extends StatelessWidget {
  const EditorShell({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.saveLabel = 'Guardar',
  });
  final String title, saveLabel;
  final Widget child;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onSave, child: Text(saveLabel)),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({
    super.key,
    this.product,
    this.name = '',
    this.forShopping = false,
  });
  final AppProduct? product;
  final String name;
  final bool forShopping;
  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      description,
      amount,
      stock,
      lowAt,
      price;
  late String category, unit;
  Uint8List? photo;
  bool picking = false;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? widget.name);
    description = TextEditingController(text: p?.description ?? '');
    amount = TextEditingController(text: '${p?.amount ?? 1}');
    stock = TextEditingController(
      text: '${p?.stock ?? (widget.forShopping ? 0 : 1)}',
    );
    lowAt = TextEditingController(text: '${p?.lowAt ?? 1}');
    price = TextEditingController(text: '${p?.referencePrice ?? 0}');
    category = p?.category ?? 'Comida';
    unit = p?.unit ?? 'pieza';
    photo = p?.photo;
  }

  @override
  void dispose() {
    for (final c in [name, description, amount, stock, lowAt, price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(bool camera) async {
    setState(() => picking = true);
    try {
      Uint8List? bytes;
      if (camera ||
          (!kIsWeb &&
              [
                TargetPlatform.android,
                TargetPlatform.iOS,
              ].contains(defaultTargetPlatform))) {
        final file = await ImagePicker().pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 75,
        );
        bytes = await file?.readAsBytes();
      } else {
        final selection = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        bytes = selection?.files.single.bytes;
      }
      if (bytes != null && bytes.length > 5 * 1024 * 1024) {
        throw StateError('La imagen debe pesar menos de 5 MB.');
      }
      if (mounted && bytes != null) setState(() => photo = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir la cámara o la imagen. Revisa los permisos y usa una imagen menor de 5 MB.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void save() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      AppProduct(
        id: widget.product?.id ?? newId(),
        name: name.text.trim(),
        description: description.text.trim(),
        category: category,
        unit: unit,
        amount: double.parse(amount.text.replaceAll(',', '.')),
        stock: parseWholeNumber(stock.text),
        lowAt: parseWholeNumber(lowAt.text),
        referencePrice: double.parse(price.text.replaceAll(',', '.')),
        photo: photo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => EditorShell(
    title: widget.product == null ? 'Añadir producto' : 'Editar producto',
    onSave: save,
    saveLabel: 'Guardar producto',
    child: Form(
      key: form,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 150,
              width: double.infinity,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: photo == null
                  ? const Icon(Icons.add_photo_alternate_outlined, size: 54)
                  : Image.memory(
                      photo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => const Center(
                        child: Text('Imagen no válida. Elige otra.'),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (kIsWeb ||
                  [
                    TargetPlatform.android,
                    TargetPlatform.iOS,
                  ].contains(defaultTargetPlatform))
                OutlinedButton.icon(
                  onPressed: picking ? null : () => pick(true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Cámara'),
                ),
              OutlinedButton.icon(
                onPressed: picking ? null : () => pick(false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
              if (photo != null)
                IconButton(
                  onPressed: () => setState(() => photo = null),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Quitar foto',
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: name,
            maxLength: 100,
            validator: requiredText,
            decoration: const InputDecoration(labelText: 'Nombre del producto'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            maxLength: 500,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Descripción, marca y características',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: category,
            isExpanded: true,
            items: {
              ...productCategories,
              category,
            }.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => category = v!),
            decoration: const InputDecoration(labelText: 'Categoría'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => positiveNumber(v, allowZero: false),
                  decoration: const InputDecoration(labelText: 'Contenido'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: unit,
                  isExpanded: true,
                  items: {...productUnits, unit}
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(v, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => unit = v!),
                  decoration: const InputDecoration(labelText: 'Unidad'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => positiveNumber(v),
            decoration: const InputDecoration(
              labelText: 'Precio habitual por paquete',
              prefixText: '\$ ',
              helperText: 'MXN · usa 0 si aún no conoces el precio',
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  validator: (v) => positiveNumber(v, integer: true),
                  decoration: const InputDecoration(
                    labelText: 'Paquetes en casa',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: lowAt,
                  keyboardType: TextInputType.number,
                  validator: (v) => positiveNumber(v, integer: true),
                  decoration: const InputDecoration(
                    labelText: 'Avisar al quedar',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Con 0 existencias pasa a compra urgente; con pocas, a compras. El contenido es por cada paquete.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class TodoEditor extends StatefulWidget {
  const TodoEditor({super.key, this.todo, required this.day});
  final TodoEntry? todo;
  final DateTime day;
  @override
  State<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<TodoEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, notes;
  late DateTime date;
  late bool remind;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.todo?.title);
    notes = TextEditingController(text: widget.todo?.notes);
    date =
        widget.todo?.date ?? dayOnly(widget.day).add(const Duration(hours: 10));
    remind = widget.todo?.remind ?? true;
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditorShell(
    title: widget.todo == null ? 'Nuevo pendiente' : 'Editar pendiente',
    onSave: () {
      if (form.currentState!.validate()) {
        Navigator.pop(
          context,
          TodoEntry(
            id: widget.todo?.id ?? newId(),
            title: title.text.trim(),
            date: date,
            notes: notes.text.trim(),
            remind: remind,
            done: widget.todo?.done ?? false,
          ),
        );
      }
    },
    child: Form(
      key: form,
      child: Column(
        children: [
          TextFormField(
            controller: title,
            validator: requiredText,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: '¿Qué necesitas hacer?',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: notes,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Notas, lugar y detalles',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month),
            title: Text(shortDate(date)),
            trailing: const Icon(Icons.edit_calendar),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(
                  () => date = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    date.hour,
                    date.minute,
                  ),
                );
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(timeLabel(date)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(date),
              );
              if (picked != null && mounted) {
                setState(
                  () => date = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    picked.hour,
                    picked.minute,
                  ),
                );
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: remind,
            onChanged: (v) => setState(() => remind = v),
            title: const Text('Recordatorio del pendiente'),
            subtitle: const Text(
              'Android: aviso local. Activa los permisos en Ajustes.',
            ),
          ),
        ],
      ),
    ),
  );
}

class RecipeEditor extends StatefulWidget {
  const RecipeEditor({super.key});
  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      ingredients = TextEditingController(),
      steps = TextEditingController(),
      minutes = TextEditingController(text: '25'),
      servings = TextEditingController(text: '2'),
      video = TextEditingController();
  String? error;
  @override
  void dispose() {
    for (final c in [
      title,
      description,
      ingredients,
      steps,
      minutes,
      servings,
      video,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditorShell(
    title: 'Mi receta casera',
    onSave: () {
      if (!form.currentState!.validate()) return;
      final recipe = Recipe(
        id: 'custom-${newId()}',
        title: title.text.trim(),
        description: description.text.trim(),
        ingredients: ingredients.text
            .split('\n')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList(),
        steps: steps.text
            .split('\n')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList(),
        minutes: '${minutes.text} min',
        servings: servings.text,
        videoUrl: video.text.trim(),
        tag: 'Mi recetario',
      );
      if (!recipe.allowed) {
        setState(
          () => error =
              'Revisa ingredientes, cantidades y cocción antes de guardar la receta.',
        );
        return;
      }
      Navigator.pop(context, recipe);
    },
    child: Form(
      key: form,
      child: Column(
        children: [
          TextFormField(
            controller: title,
            maxLength: 120,
            validator: requiredText,
            decoration: const InputDecoration(labelText: 'Nombre de la receta'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            maxLines: 2,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: ingredients,
            validator: requiredText,
            maxLines: 5,
            maxLength: 6000,
            decoration: const InputDecoration(
              labelText: 'Ingredientes y cantidades',
              helperText: 'Uno por línea, ej. 250 g de pasta',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: steps,
            validator: requiredText,
            maxLines: 6,
            maxLength: 15000,
            decoration: const InputDecoration(
              labelText: 'Preparación detallada',
              helperText: 'Cada paso en una nueva línea',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      positiveNumber(v, allowZero: false, integer: true),
                  decoration: const InputDecoration(labelText: 'Minutos'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: servings,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      positiveNumber(v, allowZero: false, integer: true),
                  decoration: const InputDecoration(labelText: 'Porciones'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: video,
            decoration: const InputDecoration(
              labelText: 'Video de YouTube (opcional)',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final uri = Uri.tryParse(value.trim());
              return uri?.scheme == 'https' &&
                      (uri!.host == 'youtube.com' ||
                          uri.host.endsWith('.youtube.com') ||
                          uri.host == 'youtu.be')
                  ? null
                  : 'Usa un enlace https de YouTube';
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}
