import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ініціалізація Hive (Працює в Chrome без жодних налаштувань)
  await Hive.initFlutter();
  Hive.registerAdapter(ExpenseAdapter());
  await Hive.openBox<Expense>('expensesBox');

  runApp(const ExpensesApp());
}

// ==========================================
// 1. МОДЕЛЬ ДАНИХ ТА АДАПТЕР
// ==========================================
class Expense {
  String id;
  String title;
  double amount;
  String category;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
  });
}

// Ручний адаптер (щоб не використовувати термінал)
class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 0;

  @override
  Expense read(BinaryReader reader) {
    final map = reader.readMap();
    return Expense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer.writeMap({
      'id': obj.id,
      'title': obj.title,
      'amount': obj.amount,
      'category': obj.category,
    });
  }
}

// ==========================================
// 2. ІНТЕРФЕЙС ТА ЛОГІКА
// ==========================================
class ExpensesApp extends StatelessWidget {
  const ExpensesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Журнал витрат',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const ExpenseListScreen(),
    );
  }
}

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final Box<Expense> _box = Hive.box<Expense>('expensesBox');

  // Видалення
  void _deleteExpense(String id) {
    _box.delete(id);
  }

  // Відкриття форми додавання
  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'Їжа';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нова витрата'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Що купили?'),
            ),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Сума'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: ['Їжа', 'Транспорт', 'Розваги', 'Інше']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => selectedCategory = v!,
              decoration: const InputDecoration(labelText: 'Категорія'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) return;
              
              final newExpense = Expense(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleCtrl.text,
                amount: double.tryParse(amountCtrl.text) ?? 0.0,
                category: selectedCategory,
              );
              
              _box.put(newExpense.id, newExpense); // Зберігаємо в базу
              Navigator.pop(ctx);
            },
            child: const Text('Додати'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал витрат (Hive)'),
        backgroundColor: Colors.teal,
      ),
      // ValueListenableBuilder автоматично оновлює екран, коли база змінюється
      body: ValueListenableBuilder(
        valueListenable: _box.listenable(),
        builder: (context, Box<Expense> box, _) {
          final expenses = box.values.toList();
          
          // Рахуємо загальну суму (Аналітика)
          final totalAmount = expenses.fold(0.0, (sum, item) => sum + item.amount);

          return Column(
            children: [
              // Блок статистики
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.teal.shade50,
                child: Column(
                  children: [
                    const Text('Загалом витрачено:', style: TextStyle(fontSize: 16, color: Colors.teal)),
                    Text('${totalAmount.toStringAsFixed(0)} грн', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
              // Список
              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Text('Немає витрат. Додайте першу!'))
                    : ListView.builder(
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal,
                                child: Text(expense.category[0], style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(expense.category),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${expense.amount} грн', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.grey),
                                    onPressed: () => _deleteExpense(expense.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}