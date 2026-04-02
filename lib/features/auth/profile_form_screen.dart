import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import '../../core/supabase_service.dart';

class ProfileFormScreen extends StatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _phoneCtrl = TextEditingController();
  DateTime? _dob;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.currentUser;
    _nameCtrl = TextEditingController(
        text: user?.userMetadata?['full_name'] as String? ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.upsertProfile(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        dateOfBirth: _dob!,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dobLabel = _dob == null
        ? 'Select date of birth'
        : '${_dob!.day}/${_dob!.month}/${_dob!.year}';

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.sp(28), context.sp(32), context.sp(28), context.sp(28)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                SizedBox(height: context.sp(6)),
                Text(
                  'Just once — helps us personalise your experience',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                SizedBox(height: context.sp(36)),

                _label(context, 'Name'),
                SizedBox(height: context.sp(8)),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco(context, 'Your name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: context.sp(20)),

                _label(context, 'Email'),
                SizedBox(height: context.sp(8)),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDeco(context, 'you@example.com'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Invalid email' : null,
                ),
                SizedBox(height: context.sp(20)),

                _label(context, 'Mobile number'),
                SizedBox(height: context.sp(8)),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDeco(context, '+91 98765 43210'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length < 7) return 'Enter a valid number';
                    return null;
                  },
                ),
                SizedBox(height: context.sp(20)),

                _label(context, 'Date of birth'),
                SizedBox(height: context.sp(8)),
                GestureDetector(
                  onTap: _pickDob,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: context.sp(16), vertical: context.sp(14)),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(context.sp(12)),
                    ),
                    child: Text(
                      dobLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _dob == null ? colors.onSurfaceVariant : colors.onSurface,
                          ),
                    ),
                  ),
                ),

                SizedBox(height: context.sp(40)),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: context.sp(14)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(context.sp(12)),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: context.sp(20),
                            height: context.sp(20),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary),
                          )
                        : Text('Continue', style: TextStyle(fontSize: context.sp(15))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
      );

  InputDecoration _inputDeco(BuildContext context, String hint) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.sp(12)),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.sp(12)),
          borderSide: BorderSide(color: outline),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: context.sp(16), vertical: context.sp(14)),
    );
  }
}
