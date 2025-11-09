import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product Update App',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const ProductUpdateScreen(),
    );
  }
}

class ProductUpdateScreen extends StatefulWidget {
  const ProductUpdateScreen({super.key});

  @override
  State<ProductUpdateScreen> createState() => _ProductUpdateScreenState();
}

class _ProductUpdateScreenState extends State<ProductUpdateScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _currentProductId;
  Map<String, dynamic>? _currentProduct;

  bool _isSearching = false;
  bool _isSaving = false;

  // Normalize names to avoid case/space mismatches
  String _normalizeName(String raw) => raw.trim().toLowerCase();

  Future<void> _searchProduct() async {
    final rawName = _nameController.text;
    final productName = _normalizeName(rawName);

    if (productName.isEmpty) {
      _toast('Please enter a product name');
      return;
    }

    setState(() => _isSearching = true);
    try {
      final qs = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: productName)
          .limit(1)
          .get();

      if (qs.docs.isNotEmpty) {
        final doc = qs.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        _currentProductId = doc.id;
        _currentProduct = data;

        _quantityController.text = (data['quantity'] ?? '').toString();
        _priceController.text = (data['price'] ?? '').toString();

        setState(() {});
        _toast('Product found');
      } else {
        _currentProductId = null;
        _currentProduct = null;
        _quantityController.clear();
        _priceController.clear();
        setState(() {});
        _toast('Product not found. You can create ');
      }
    } on FirebaseException catch (e) {
      _toast('Firestore error: ${e.code} — ${e.message}');
    } catch (e) {
      _toast('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveProduct() async {
    // Basic validation for quantity/price inputs
    if (!_formKey.currentState!.validate()) return;

    final rawName = _nameController.text;
    final productName = _normalizeName(rawName);

    if (productName.isEmpty) {
      _toast('Please enter a product name');
      return;
    }

    final int newQuantity = int.parse(_quantityController.text.trim());
    final double newPrice = double.parse(_priceController.text.trim());

    setState(() => _isSaving = true);
    try {
      final docRef = _currentProductId != null
          ? FirebaseFirestore.instance.collection('products').doc(_currentProductId)
          : FirebaseFirestore.instance.collection('products').doc(productName);

      await docRef.set({
        'name': productName,
        'quantity': newQuantity,
        'price': newPrice,

      }, SetOptions(merge: true)); // create or update

      _currentProductId = docRef.id;
      _currentProduct = {
        'name': productName,
        'quantity': newQuantity,
        'price': newPrice,
      };
      setState(() {});

      _toast('Product saved successfully');
    } on FirebaseException catch (e) {
      _toast('Firestore error: ${e.code} — ${e.message}');
    } catch (e) {
      _toast('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _currentProductId = null;
    _currentProduct = null;
    setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final hasProduct = _currentProduct != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Update'),
        actions: [
          IconButton(
            tooltip: 'Clear',
            onPressed: _clearForm,
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _searchProduct(),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a product name' : null,
              ),
              const SizedBox(height: 12),

              // Search button
              FilledButton.icon(
                onPressed: _isSearching ? null : _searchProduct,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Search'),
              ),

              const SizedBox(height: 20),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter quantity';
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null) return 'Quantity must be an integer';
                  if (parsed < 0) return 'Quantity cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Price
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    signed: false, decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter price';
                  final parsed = double.tryParse(v.trim());
                  if (parsed == null) return 'Price must be a number';
                  if (parsed < 0) return 'Price cannot be negative';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Save (Create/Update)
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveProduct,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save (Create/Update)'),
              ),

              const SizedBox(height: 24),
              if (hasProduct) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Current Product Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: $_currentProductId'),
                          const SizedBox(height: 8),
                          Text('Name: ${_currentProduct!['name']}'),
                          const SizedBox(height: 8),
                          Text('Quantity: ${_currentProduct!['quantity']}'),
                          const SizedBox(height: 8),
                          Text('Price: ${_currentProduct!['price']}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
