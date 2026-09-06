import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/design.dart';

const List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

/// Edit the citizen's profile fields (full name / mobile / DOB / gender) →
/// PATCH /auth/me/profile. Pops with `true` on a successful save.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    this.fullName,
    this.mobile,
    this.dateOfBirth,
    this.gender,
  });

  final String? fullName;
  final String? mobile;
  final String? dateOfBirth; // ISO yyyy-MM-dd
  final String? gender;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.fullName ?? '');
  late final TextEditingController _mobile =
      TextEditingController(text: widget.mobile ?? '');

  DateTime? _dob;
  String? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.dateOfBirth != null) {
      _dob = DateTime.tryParse(widget.dateOfBirth!);
    }
    if (widget.gender != null && _genders.contains(widget.gender)) {
      _gender = widget.gender;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
  String _pretty(DateTime d) => '${_two(d.month)}/${_two(d.day)}/${d.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final api = ApiClient();
    try {
      await api.updateProfile(
        fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        mobile: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        dateOfBirth: _dob == null ? null : _iso(_dob!),
        gender: _gender,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Check your connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 24),
              _label('FULL NAME'),
              const SizedBox(height: 6),
              _field(_name, 'Your full name'),
              const SizedBox(height: 18),
              _label('MOBILE NUMBER'),
              const SizedBox(height: 6),
              _field(_mobile, 'e.g. 0917 123 4567', keyboard: TextInputType.phone),
              const SizedBox(height: 18),
              _label('DATE OF BIRTH'),
              const SizedBox(height: 6),
              _dobField(),
              const SizedBox(height: 18),
              _label('GENDER'),
              const SizedBox(height: 6),
              _genderField(),
              const SizedBox(height: 28),
              _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const BackWell(),
        const SizedBox(width: 16),
        Text('Edit Profile'.toUpperCase(), style: AppText.screenTitle),
      ],
    );
  }

  Widget _label(String text) => Eyebrow(text, color: AppColors.label);

  BoxDecoration _box() => BoxDecoration(
    color: AppColors.inputBg,
    borderRadius: BorderRadius.circular(AppRadius.control),
    border: Border.all(color: AppColors.line),
  );

  Widget _field(
    TextEditingController c,
    String hint, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: _fieldStyle,
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _dobField() => GestureDetector(
    onTap: _pickDob,
    child: Container(
      height: 54,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _box(),
      child: Text(
        _dob == null ? 'mm/dd/yyyy' : _pretty(_dob!),
        style: _fieldStyle.copyWith(
          color: _dob == null
              ? AppColors.label.withValues(alpha: 0.45)
              : AppColors.onBackground,
        ),
      ),
    ),
  );

  Widget _genderField() => Container(
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: _box(),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: _gender,
        hint: Text(
          'Select',
          style: _fieldStyle.copyWith(
            color: AppColors.label.withValues(alpha: 0.45),
          ),
        ),
        dropdownColor: AppColors.surfaceSolid,
        borderRadius: BorderRadius.circular(AppRadius.control),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.muted,
        ),
        style: _fieldStyle,
        items: _genders
            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
            .toList(),
        onChanged: (v) => setState(() => _gender = v),
      ),
    ),
  );

  Widget _saveButton() => AppButton(
    'Save changes',
    busy: _saving,
    onPressed: _saving ? null : _save,
  );
}

const TextStyle _fieldStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  color: AppColors.onBackground,
);
