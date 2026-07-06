import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';

class BarberServicesScreen extends StatefulWidget {
  const BarberServicesScreen({super.key});

  @override
  State<BarberServicesScreen> createState() => _BarberServicesScreenState();
}

class _BarberServicesScreenState extends State<BarberServicesScreen> {
  List<dynamic> _services = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getBarberServices();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _services = result.data!;
        } else {
          _services = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load services.')),
          );
        }
      });
    }
  }

  void _showAddEditServiceBottomSheet({Map<String, dynamic>? service}) {
    final isEdit = service != null;
    final nameController = TextEditingController(text: isEdit ? service['name'] : '');
    final durationController = TextEditingController(text: isEdit ? service['durationInMinutes'].toString() : '');
    final priceController = TextEditingController(text: isEdit ? service['price'].toString() : '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSheetLoading = false;
        String? sheetError;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? 'Edit Service' : 'Add New Service',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: isSheetLoading ? null : () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (sheetError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                          ),
                          child: Text(
                            sheetError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Service Name
                      TextFormField(
                        controller: nameController,
                        enabled: !isSheetLoading,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Service Name',
                          labelStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.spa, color: Color(0xFF9C27B0)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter service name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Duration
                      TextFormField(
                        controller: durationController,
                        enabled: !isSheetLoading,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duration (Minutes)',
                          labelStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.timer, color: Color(0xFF9C27B0)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter duration.';
                          }
                          final dur = int.tryParse(val);
                          if (dur == null || dur <= 0) {
                            return 'Please enter a valid duration.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Price
                      TextFormField(
                        controller: priceController,
                        enabled: !isSheetLoading,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Fiyat (TL)',
                          labelStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.payments, color: Color(0xFF9C27B0)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.03),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Fiyat giriniz.';
                          }
                          final price = double.tryParse(val);
                          if (price == null || price <= 0) {
                            return 'Please enter a valid price.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action Button
                      ElevatedButton(
                        onPressed: isSheetLoading ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          final name = nameController.text.trim();
                          final duration = int.parse(durationController.text.trim());
                          final price = double.parse(priceController.text.trim());

                          setSheetState(() {
                            isSheetLoading = true;
                            sheetError = null;
                          });

                          TaskResult<Map<String, dynamic>> result;
                          if (isEdit) {
                            result = await ApiService.updateBarberService(
                              service['id'],
                              name,
                              duration,
                              price,
                            );
                          } else {
                            result = await ApiService.addBarberService(
                              name,
                              duration,
                              price,
                            );
                          }

                          if (context.mounted) {
                            if (result.success) {
                              Navigator.pop(context); // close bottom sheet on success
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit
                                      ? 'Service successfully updated!'
                                      : 'Service successfully added!'),
                                ),
                              );
                              _loadServices(); // reload parent screen list
                            } else {
                              setSheetState(() {
                                isSheetLoading = false;
                                sheetError = result.message ?? 'Operation failed.';
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isSheetLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                isEdit ? 'Update Service' : 'Add Service',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteService(String serviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hizmeti Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this service? If there are active appointments for this service, it cannot be deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final result = await ApiService.deleteBarberService(serviceId);
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service successfully deleted.')),
          );
          _loadServices();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Deletion failed.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditServiceBottomSheet(),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Service Management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadServices,
              color: const Color(0xFF9C27B0),
              backgroundColor: const Color(0xFF1E1E2F),
              child: _isLoading && _services.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                      ),
                    )
                  : _services.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            const Center(
                              child: Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orangeAccent),
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'Please Add At least One Service!\n\nDefining a service is mandatory for customers to discover your shop and book appointments.',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text(
                                'You can add your first service immediately by tapping the "+" button in the bottom right.',
                                style: TextStyle(color: Colors.white38, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _services.length,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final svc = _services[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9C27B0).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.content_cut,
                                      color: Color(0xFFE040FB),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          svc['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.timer_outlined, color: Colors.white38, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${svc['durationInMinutes']} dk',
                                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                                            ),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.payments_outlined, color: Colors.white38, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${svc['price']} TL',
                                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Edit & Delete Actions
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                                    onPressed: () => _showAddEditServiceBottomSheet(service: svc),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () => _deleteService(svc['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
