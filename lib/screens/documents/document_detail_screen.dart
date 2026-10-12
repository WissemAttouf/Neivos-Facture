// screens/documents/document_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../../providers/document_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/document_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/particle_background.dart';

class DocumentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final extractedData = widget.document['extractedData'] ?? {};

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/ssvg.PNG',
              height: 30,
              width: 30,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'DÉTAILS FACTURE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).appBarTheme.foregroundColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Theme.of(context).appBarTheme.foregroundColor),
            onPressed: () => _shareDocument(context),
          ),
          IconButton(
            icon: Icon(Icons.table_chart, color: Theme.of(context).appBarTheme.foregroundColor),
            onPressed: () => _exportToExcel(context),
            tooltip: 'Exporter en Excel',
          ),
        ],
      ),
      body: Stack(
        children: [
          ParticleBackground(isDarkMode: isDarkMode),
          _isExporting
              ? _buildExportOverlay(context)
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte d'informations principales
                Card(
                  color: Theme.of(context).cardColor,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Informations de la facture',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Numéro de facture', extractedData['invoice_number'] ?? 'N/A', context),
                        _buildInfoRow('Date', extractedData['invoice_date'] ?? _formatDate(widget.document['createdAt']), context),
                        _buildInfoRow('Fournisseur', extractedData['supplier_name'] ?? extractedData['supplier'] ?? 'Non spécifié', context),
                        _buildInfoRow('Client', extractedData['client_name'] ?? extractedData['client'] ?? 'Non spécifié', context),
                        _buildInfoRow('Montant HT', _formatAmount(extractedData['total_ht']), context),
                        _buildInfoRow('Montant TTC', _formatAmount(extractedData['total_ttc']), context),
                        _buildInfoRow('TVA', _formatAmount(extractedData['tva_amount']), context),
                        _buildInfoRow('Net à payer', _formatAmount(extractedData['net_a_payer']), context),
                        const SizedBox(height: 8),
                        Divider(color: Theme.of(context).dividerColor),
                        _buildInfoRow('Date de création', _formatDate(widget.document['createdAt']), context),
                        _buildInfoRow('Nombre de champs', '${extractedData.length}', context),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Section détails financiers
                Card(
                  color: Theme.of(context).cardColor,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_money, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Détails financiers',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Retenue à la source', _formatAmount(extractedData['retenue_source']), context),
                        _buildInfoRow('Timbre fiscal', _formatAmount(extractedData['timbre_fiscal']), context),
                        _buildInfoRow('Taux TVA', '${extractedData['tva_rate'] ?? '0'}%', context),
                        _buildInfoRow('Matricule fiscal', extractedData['matricule_fiscal'] ?? 'N/A', context),
                        _buildInfoRow('Devise', extractedData['currency'] ?? 'TND', context),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Section toutes les données extraites
                Text(
                  'Toutes les données extraites:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 10),

                if (extractedData.isEmpty)
                  Card(
                    color: Theme.of(context).cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Aucune donnée extraite',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                    ),
                  ),

                ...extractedData.entries.map((entry) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  color: Theme.of(context).cardColor,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${_getFieldLabel(entry.key)}:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entry.value?.toString() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),

                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : () => _exportToExcel(context),
                        icon: _isExporting
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.table_chart, color: Colors.white),
                        label: Text(
                          _isExporting ? 'Export en cours...' : 'Exporter en Excel',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          disabledBackgroundColor: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editDocument(context),
                        icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                        label: Text('Modifier', style: TextStyle(color: Theme.of(context).primaryColor)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Bouton supplémentaire pour partager
                ElevatedButton.icon(
                  onPressed: () => _shareDocument(context),
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text('Partager la facture', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOverlay(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            strokeWidth: 4,
          ),
          const SizedBox(height: 20),
          Text(
            'Export Excel en cours...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Veuillez patienter',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  String _getFieldLabel(String fieldName) {
    final labels = {
      'invoice_number': 'Numéro de facture',
      'invoice_date': 'Date de facture',
      'supplier_name': 'Fournisseur',
      'supplier_address': 'Adresse fournisseur',
      'supplier_tax_id': 'MF fournisseur',
      'client_name': 'Client',
      'client_address': 'Adresse client',
      'client_tax_id': 'MF client',
      'total_ht': 'Total HT',
      'total_ttc': 'Total TTC',
      'tva_amount': 'Montant TVA',
      'tva_rate': 'Taux TVA',
      'net_a_payer': 'Net à payer',
      'retenue_source': 'Retenue à la source',
      'timbre_fiscal': 'Timbre fiscal',
      'matricule_fiscal': 'Matricule fiscal',
      'payment_terms': 'Conditions de paiement',
      'due_date': 'Date d\'échéance',
      'iban': 'IBAN',
      'address': 'Adresse',
      'phone': 'Téléphone',
      'email': 'Email',
      'currency': 'Devise',
      'confidence': 'Confiance OCR',
      'raw_text': 'Texte brut',
    };
    return labels[fieldName] ?? fieldName;
  }

  String _formatDate(dynamic date) {
    if (date is DateTime) {
      return DateFormat('dd/MM/yyyy à HH:mm').format(date);
    } else if (date is String) {
      try {
        final parsedDate = DateTime.parse(date);
        return DateFormat('dd/MM/yyyy à HH:mm').format(parsedDate);
      } catch (e) {
        return date.toString();
      }
    }
    return date?.toString() ?? 'N/A';
  }

  String _formatAmount(dynamic amount) {
    if (amount == null || amount.toString().isEmpty) return '0.000 TND';
    final amountStr = amount.toString();
    if (amountStr.contains('TND')) return amountStr;
    try {
      final number = double.tryParse(amountStr.replaceAll(',', '.'));
      if (number != null) {
        return '${number.toStringAsFixed(3)} TND';
      }
    } catch (e) {}
    return '$amountStr TND';
  }

  String _formatMontant(dynamic value) {
    if (value == null || value.toString().isEmpty) return '0.000';
    try {
      String strValue = value.toString().replaceAll(',', '.');
      double amount = double.parse(strValue);
      return amount.toStringAsFixed(3);
    } catch (e) {
      return value.toString();
    }
  }

  String _formatTaux(dynamic value) {
    if (value == null || value.toString().isEmpty) return '0.0';
    try {
      String strValue = value.toString().replaceAll(',', '.');
      double rate = double.parse(strValue);
      return rate.toStringAsFixed(1);
    } catch (e) {
      return value.toString();
    }
  }

  void _addRow(Sheet sheet, int row, String label, String value) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue(label);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = TextCellValue(value);
  }

  // ✅ EXPORT EXCEL UNIQUE POUR UNE FACTURE
  Future<void> _exportToExcel(BuildContext context) async {
    setState(() => _isExporting = true);

    try {
      final extractedData = widget.document['extractedData'] ?? {};

      var excel = Excel.createExcel();
      String sheetName = 'Facture';
      Sheet sheetObject = excel[sheetName];

      int rowIndex = 0;

      // En-tête
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('FACTURE N° ${extractedData['invoice_number'] ?? 'N/A'}')
        ..cellStyle = CellStyle(bold: true, fontSize: 14);
      rowIndex++;

      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('Date: ${extractedData['invoice_date'] ?? 'N/A'}')
        ..cellStyle = CellStyle(italic: true);
      rowIndex += 2;

      // Fournisseur
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('FOURNISSEUR')
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D9E1F2'));
      rowIndex++;

      _addRow(sheetObject, rowIndex++, 'Nom:', extractedData['supplier_name'] ?? '');
      _addRow(sheetObject, rowIndex++, 'Adresse:', extractedData['supplier_address']?.toString().replaceAll('\n', ' ') ?? '');
      _addRow(sheetObject, rowIndex++, 'Téléphone:', extractedData['phone'] ?? '');
      _addRow(sheetObject, rowIndex++, 'Email:', extractedData['email'] ?? '');
      _addRow(sheetObject, rowIndex++, 'Matricule fiscal:', extractedData['supplier_tax_id'] ?? '');
      rowIndex++;

      // Client
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('CLIENT')
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D9E1F2'));
      rowIndex++;

      _addRow(sheetObject, rowIndex++, 'Nom:', extractedData['client_name'] ?? '');
      _addRow(sheetObject, rowIndex++, 'Adresse:', extractedData['client_address'] ?? '');
      _addRow(sheetObject, rowIndex++, 'Matricule fiscal:', extractedData['client_tax_id'] ?? '');
      rowIndex++;

      // Détails financiers
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('DÉTAILS FINANCIERS (TND)')
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D9E1F2'));
      rowIndex++;

      _addRow(sheetObject, rowIndex++, 'Total HT:', _formatMontant(extractedData['total_ht']));
      _addRow(sheetObject, rowIndex++, 'Taux TVA (%):', _formatTaux(extractedData['tva_rate']));
      _addRow(sheetObject, rowIndex++, 'Montant TVA:', _formatMontant(extractedData['tva_amount']));
      _addRow(sheetObject, rowIndex++, 'Total TTC:', _formatMontant(extractedData['total_ttc']));

      if (extractedData.containsKey('timbre_fiscal') && extractedData['timbre_fiscal'] != null &&
          extractedData['timbre_fiscal'].toString().isNotEmpty) {
        _addRow(sheetObject, rowIndex++, 'Timbre fiscal:', _formatMontant(extractedData['timbre_fiscal']));
      }

      if (extractedData.containsKey('retenue_source') && extractedData['retenue_source'] != null &&
          extractedData['retenue_source'].toString().isNotEmpty &&
          double.tryParse(extractedData['retenue_source'].toString()) != 0) {
        _addRow(sheetObject, rowIndex++, 'Retenue à la source:', _formatMontant(extractedData['retenue_source']));
      }

      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('NET À PAYER:')
        ..cellStyle = CellStyle(bold: true);
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
        ..value = TextCellValue(_formatMontant(extractedData['net_a_payer']))
        ..cellStyle = CellStyle(bold: true);
      rowIndex += 2;

      // Métadonnées
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
        ..value = TextCellValue('MÉTADONNÉES')
        ..cellStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.fromHexString('#D9E1F2'));
      rowIndex++;

      _addRow(sheetObject, rowIndex++, 'Confiance OCR:', '${(widget.document['confidence'] ?? 80).toStringAsFixed(1)}%');
      _addRow(sheetObject, rowIndex++, 'Date d\'extraction:', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));
      _addRow(sheetObject, rowIndex++, 'ID Document:', widget.document['id']?.toString() ?? 'N/A');

      sheetObject.setColumnWidth(0, 25.0);
      sheetObject.setColumnWidth(1, 40.0);

      var fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Erreur création fichier Excel');

      final directory = await getApplicationDocumentsDirectory();
      final invoiceNumber = extractedData['invoice_number']?.toString().replaceAll('/', '-') ?? 'sans_numero';
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'FACTURE_${invoiceNumber}_${dateStr}.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(fileBytes);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ Export réussi'),
            content: Text('Fichier: $fileName'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenFile.open(file.path);
                },
                child: const Text('OUVRIR'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(file.path)],
                      text: 'Facture ${extractedData['invoice_number'] ?? ''}');
                },
                child: const Text('PARTAGER'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('FERMER'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      print('❌ Erreur export Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur export: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _shareDocument(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Partage de la facture'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  void _editDocument(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Édition du document à venir'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
