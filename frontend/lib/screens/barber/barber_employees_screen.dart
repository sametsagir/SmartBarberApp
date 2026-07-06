import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/barber/barber_working_hours_screen.dart';

class BarberEmployeesScreen extends StatefulWidget {
  const BarberEmployeesScreen({super.key});

  @override
  State<BarberEmployeesScreen> createState() => _BarberEmployeesScreenState();
}

class _BarberEmployeesScreenState extends State<BarberEmployeesScreen> {
  List<dynamic> _employees = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getEmployees();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success && result.data != null) {
          _employees = result.data!;
        } else {
          _employees = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Failed to load staff list.')),
          );
        }
      });
    }
  }

  Future<void> _addEmployee() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSheetLoading = false;
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
                          const Text(
                            'Add New Employee',
                            style: TextStyle(
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
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Ad Soyad', Icons.person),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter full name' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.phone,
                        decoration: _buildInputDecoration('Phone Number (e.g. +905...)', Icons.phone),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter phone number';
                          }
                          if (!value.startsWith('+')) {
                            return 'Number must start with country code (e.g. +90)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _buildInputDecoration('Specialty Title (e.g. Hair Stylist)', Icons.work_outline),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Please enter title' : null,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isSheetLoading
                            ? null
                            : () async {
                                if (formKey.currentState!.validate()) {
                                  setSheetState(() => isSheetLoading = true);
                                  final res = await ApiService.addEmployee(
                                    nameController.text.trim(),
                                    phoneController.text.trim(),
                                    titleController.text.trim(),
                                  );
                                  setSheetState(() => isSheetLoading = false);
                                  if (mounted) {
                                    if (res.success) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Employee successfully added!')),
                                      );
                                      _loadEmployees();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res.message ?? 'An error occurred.')),
                                      );
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: isSheetLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _deleteEmployee(dynamic employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        title: const Text('Remove Employee', style: TextStyle(color: Colors.white)),
        content: Text(
          '${employee['fullName']}? Future appointments must be completed or cancelled first.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove from staff', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final res = await ApiService.deleteEmployee(employee['id'].toString());
      if (mounted) {
        setState(() => _isLoading = false);
        if (res.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee removed from staff.')),
          );
          _loadEmployees();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.message ?? 'An error occurred.')),
          );
        }
      }
    }
  }

  Future<void> _editServiceAuthorizations(dynamic employee) async {
    setState(() => _isLoading = true);
    final allServicesRes = await ApiService.getBarberServices();
    final authorizedServicesRes = await ApiService.getEmployeeServices(employee['id'].toString());
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!allServicesRes.success || !authorizedServicesRes.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch service authorizations.')),
      );
      return;
    }

    final List<dynamic> allServices = allServicesRes.data ?? [];
    final List<dynamic> authorizedList = authorizedServicesRes.data ?? [];
    
    // Set of authorized service IDs
    final Set<String> authorizedIds = authorizedList.map((s) => s['id'].toString()).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${employee['fullName']} - Authorized Services',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select the haircut and grooming services this employee can offer.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  if (allServices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'The salon has no defined services. Please add services first from the Services tab.',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allServices.length,
                        itemBuilder: (context, idx) {
                          final service = allServices[idx];
                          final serviceId = service['id'].toString();
                          final isChecked = authorizedIds.contains(serviceId);

                          return CheckboxListTile(
                            title: Text(service['name'], style: const TextStyle(color: Colors.white)),
                            subtitle: Text('${service['price']} TL - ${service['durationInMinutes']} dk', style: const TextStyle(color: Colors.white54)),
                            value: isChecked,
                            activeColor: const Color(0xFF9C27B0),
                            checkColor: Colors.white,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  authorizedIds.add(serviceId);
                                } else {
                                  authorizedIds.remove(serviceId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isSaving || allServices.isEmpty
                        ? null
                        : () async {
                            if (authorizedIds.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please select at least one service for the barber.')),
                              );
                              return;
                            }
                            setSheetState(() => isSaving = true);
                            final saveRes = await ApiService.updateEmployeeServices(
                              employee['id'].toString(),
                              authorizedIds.toList(),
                            );
                            setSheetState(() => isSaving = false);
                            if (mounted) {
                              if (saveRes.success) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Service authorizations updated!')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(saveRes.message ?? 'An error occurred.')),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEmployeeOptions(dynamic employee) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                employee['fullName'],
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                employee['title'],
                style: const TextStyle(color: Colors.white38, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(Icons.access_time, color: Color(0xFFE040FB)),
                title: const Text('Edit Shift Hours', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BarberWorkingHoursScreen(
                        stylistId: employee['id'].toString(),
                        stylistName: employee['fullName'],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined, color: Color(0xFFE040FB)),
                title: const Text('Hizmet Yetkilendirmesi', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _editServiceAuthorizations(employee);
                },
              ),
              if (employee['isOwner'] != true)
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                  title: const Text('Remove from Staff', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteEmployee(employee);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF9C27B0)),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: const Color(0xFF1E1E2F),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFE040FB), size: 28),
            onPressed: _addEmployee,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2F), Color(0xFF0F0F1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadEmployees,
          color: const Color(0xFF9C27B0),
          backgroundColor: const Color(0xFF1E1E2F),
          child: _isLoading && _employees.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9C27B0)),
                  ),
                )
              : _employees.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        const Center(child: Icon(Icons.people_outline, size: 64, color: Colors.white24)),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'No registered employees found in the staff.',
                            style: TextStyle(color: Colors.white38, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'Staff',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Manage barbers working in the salon, schedule their shift hours, and configure their service authorizations.',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _employees.length,
                              itemBuilder: (context, index) {
                                final employee = _employees[index];
                                final isOwner = employee['isOwner'] == true;
                                final rating = (employee['rating'] as num?)?.toDouble() ?? 5.0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF9C27B0).withOpacity(0.15),
                                      child: Text(
                                        employee['fullName'].isNotEmpty ? employee['fullName'][0].toUpperCase() : 'B',
                                        style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          employee['fullName'],
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        if (isOwner) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF9C27B0).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.4)),
                                            ),
                                            child: const Text(
                                              'OWNER',
                                              style: TextStyle(color: Color(0xFFE040FB), fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(employee['title'], style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: const Icon(Icons.more_vert, color: Colors.white38),
                                    onTap: () => _showEmployeeOptions(employee),
                                  ),
                                );
                              },
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
