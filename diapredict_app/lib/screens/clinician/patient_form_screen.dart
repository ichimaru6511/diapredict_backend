import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import 'patient_detail_screen.dart';

// Used for both "Add Patient" (patientId == null) and "Edit Patient".
class PatientFormScreen extends StatefulWidget {
  final String role; // 'doctor' or 'nurse'
  final String? patientId;
  final Map<String, dynamic>? initialData;

  const PatientFormScreen({
    super.key,
    required this.role,
    this.patientId,
    this.initialData,
  });

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mrnController;
  late final TextEditingController _ageController;
  late final TextEditingController _phoneController;
  String? _gender;
  bool _saving = false;

  bool get _isEdit => widget.patientId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _nameController = TextEditingController(text: data['name'] ?? '');
    _mrnController = TextEditingController(text: data['mrn'] ?? '');
    _ageController =
        TextEditingController(text: data['age'] == null ? '' : '${data['age']}');
    _phoneController = TextEditingController(text: data['phone'] ?? '');
    _gender = data['gender'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrnController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final patients = FirebaseFirestore.instance.collection('patients');
    final user = FirebaseAuth.instance.currentUser!;
    final mrn = _mrnController.text.trim().toUpperCase();

    try {
      // each patient must have a unique MRN
      final existing =
          await patients.where('mrn', isEqualTo: mrn).limit(2).get();
      final duplicate =
          existing.docs.any((doc) => doc.id != widget.patientId);
      if (duplicate) {
        _showMessage('A patient with MRN $mrn already exists.');
        return;
      }

      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'mrn': mrn,
        'age': int.parse(_ageController.text.trim()),
        'gender': _gender,
        'phone': _phoneController.text.trim(),
        'updatedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        await patients.doc(widget.patientId).update(data);
        if (!mounted) return;
        _showMessage('Patient details updated.');
        Navigator.pop(context);
      } else {
        data['createdBy'] = user.uid;
        data['createdByName'] = user.displayName ?? '';
        data['createdAt'] = FieldValue.serverTimestamp();
        final ref = await patients.add(data);
        if (!mounted) return;
        _showMessage('Patient added.');
        // open the new patient's page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PatientDetailScreen(patientId: ref.id, role: widget.role),
          ),
        );
      }
    } on FirebaseException catch (e) {
      _showMessage('Could not save patient (${e.code}). Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Patient' : 'Add Patient')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Only basic details needed to identify the patient are '
                  'recorded.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // full name
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Patient Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the patient name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // MRN
                TextFormField(
                  controller: _mrnController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Patient ID / MRN',
                    prefixIcon: Icon(Icons.badge_outlined),
                    helperText: 'Medical record number used by the clinic.',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the patient ID / MRN';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // age
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age (years)',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  validator: (value) {
                    final age = int.tryParse(value?.trim() ?? '');
                    if (age == null || age < 1 || age > 120) {
                      return 'Please enter a valid age (1-120)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // gender
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  dropdownColor: AppColors.surface,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                  validator: (value) {
                    if (value == null) return 'Please select the gender';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // phone (optional)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Save Changes' : 'Add Patient',
                            style: const TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
