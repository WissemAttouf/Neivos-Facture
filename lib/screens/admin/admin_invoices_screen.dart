// lib/screens/admin/admin_invoices_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/particle_background.dart';

class AdminInvoicesScreen extends StatefulWidget {
  const AdminInvoicesScreen({super.key});

  @override
  State<AdminInvoicesScreen> createState() => _AdminInvoicesScreenState();
}



  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _comptableController.dispose();
    super.dispose();
  }

  

  List<Map<String, dynamic>> get _filteredInvoices {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    var invoices = adminProvider.invoices;

    // Filtre global (Barre de recherche texte)
    if (_searchQuery.isNotEmpty) {
      invoices = invoices.where((inv) =>
      (inv['invoice_number']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (inv['supplier_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    // Filtre par le nom exact ou partiel du Comptable
    if (_filterComptableName.isNotEmpty) {
      invoices = invoices.where((inv) {
        final userName = inv['user_name']?.toString().toLowerCase() ?? '';
        return userName.contains(_filterComptableName.toLowerCase());
      }).toList();
    }

    // Filtre par Date Spécifique exacte
    

  String _formatAmount(dynamic value) {
    if (value == null) return '0.000 TND';
    try {
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return '${parsed.toStringAsFixed(3)} TND';
        return '$value TND';
      }
      if (value is num) return '${value.toStringAsFixed(3)} TND';
      return '0.000 TND';
    } catch (e) {
      return '0.000 TND';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Date inconnue';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed != null) {
        return '${parsed.day.toString().padLeft(2,'0')}/${parsed.month.toString().padLeft(2,'0')}/${parsed.year}';
      }
    } catch (e) {}
    return date.toString().substring(0, 10);
  }

  // ============ EXPORT EXCEL ============
  Future<void> _exportToExcel() async {
    final invoices = _filteredInvoices;

   

    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Factures'];

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );

      final headers = ['ID', 'Numéro', 'Fournisseur', 'Client', 'Total HT', 'Total TTC', 'TVA', 'Date', 'Utilisateur'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      }

      for (int i = 0; i < invoices.length; i++) {
        final inv = invoices[i];
        final row = i + 1;
        
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue(_formatDate(inv['created_at']));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = TextCellValue(inv['user_name']?.toString() ?? '');
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Erreur création fichier');

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'factures_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles([XFile(file.path)], text: 'Export des factures');

      

   
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Filtrer les factures'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _comptableController,
                    decoration: InputDecoration(
                      labelText: 'Nom du comptable',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (value) {
                      _filterComptableName = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date exacte'),
                    subtitle: Text(
                        _filterGivenDate == null
                            ? 'Aucune date sélectionnée'
                            : '${_filterGivenDate!.day.toString().padLeft(2,'0')}/${_filterGivenDate!.month.toString().padLeft(2,'0')}/${_filterGivenDate!.year}'
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10)
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _filterGivenDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => _filterGivenDate = picked);
                      }
                    },
                  ),
                ],
              ),
             
                    Navigator.pop(ctx);
                  },
                  child: const Text('Effacer les filtres', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Applique les filtres à l'UI principale
                    Navigator.pop(ctx);
                  },
                  child: const Text('Appliquer'),
                ),
              ],
            );
          }
      ),
    );
  }

  // ============ MODIFICATION & SUPPRESSION (Gardées identiques) ============
  // ... (Je garde les méthodes _editInvoice et _confirmDeleteInvoice intactes si vous en avez besoin, mais raccourcies ici pour l'affichage)

  void _confirmDeleteInvoice(Map<String, dynamic> invoice, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la facture'),
        content: Text('Êtes-vous sûr de vouloir supprimer la facture ${invoice['invoice_number'] ?? ''} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final invoices = _filteredInvoices;

    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher par Num ou Fournisseur...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  avancés',
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download),
                    onPressed: _exportToExcel,
                    tooltip: 'Exporter Excel',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadInvoices,
                    tooltip: 'Rafraîchir',
                  ),
                ],
              ),

             
                              _comptableController.clear();
                            }),
                          ),
                        ),
                      if (_filterGivenDate != null)
                        Chip(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          label: Text('Date: ${_formatDate(_filterGivenDate)}', style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => _filterGivenDate = null),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: adminProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : invoices.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Aucune facture trouvée', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
              
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt, color: Theme.of(context).primaryColor, size: 24),
                  ),
                  title: Text(
                    'Facture ${invoice['invoice_number'] ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                 
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDeleteInvoice(invoice, authProvider.authToken!),
                        tooltip: 'Supprimer',
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
  }
}
