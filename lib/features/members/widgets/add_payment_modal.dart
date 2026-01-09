import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/member.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../shared/widgets/custom_button.dart';

class AddPaymentModal extends StatefulWidget {
  final Member member;

  const AddPaymentModal({super.key, required this.member});

  @override
  State<AddPaymentModal> createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends State<AddPaymentModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  PaymentType _selectedType = PaymentType.cash;
  PaymentCategory _selectedCategory = PaymentCategory.packageRenewal;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final payment = Payment(
        id: const Uuid().v4(),
        memberId: widget.member.id,
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        date: _selectedDate,
        type: _selectedType,
        category: _selectedCategory,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        createdAt: DateTime.now(),
      );

      await PaymentRepository().create(payment);

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ödeme başarıyla kaydedildi'),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
        color: AppColors.surfaceDark,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ödeme Al', style: AppTextStyles.title2),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Amount Input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.title1.copyWith(color: AppColors.accentGreen),
                decoration: InputDecoration(
                  labelText: 'Tutar (TL)',
                  labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.currency_lira, color: AppColors.accentGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Tutar giriniz';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.glassBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primaryYellow),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate),
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Types Row
              Text('Ödeme Yöntemi', style: AppTextStyles.subheadline),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: PaymentType.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = PaymentType.values[index];
                    final isSelected = type == _selectedType;
                    return ChoiceChip(
                      label: Text(type.label),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedType = type),
                      selectedColor: AppColors.primaryYellow,
                      backgroundColor: AppColors.surfaceDark,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

               // Category Row
              Text('Kategori', style: AppTextStyles.subheadline),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: PaymentCategory.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = PaymentCategory.values[index];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat.label),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                      selectedColor: AppColors.accentBlue,
                      backgroundColor: AppColors.surfaceDark,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white,
                         fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                style: AppTextStyles.body,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Açıklama (Opsiyonel)',
                  labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.glassBorder),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              CustomButton(
                text: _isLoading ? 'Kaydediliyor...' : 'Ödemeyi Kaydet',
                onPressed: _isLoading ? () {} : _savePayment,
                backgroundColor: AppColors.accentGreen,
                icon: Icons.check_circle_outline,
                width: double.infinity,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
