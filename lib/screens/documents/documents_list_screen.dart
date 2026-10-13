// screens/documents/documents_list_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'document_detail_screen.dart';
import '../../utils/app_theme.dart';
import '../../widgets/particle_background.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  bool _isLoading = true;
 
      if (maxY.isNaN || maxY.isInfinite) maxY = 0;
      maxY = maxY > 0 ? (maxY * 1.2) : 100;

      List<double> yTicks = List.generate(6, (i) => (maxY / 5) * i);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // En-tête avec logo et titre
              pw.Center(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'NEIVOS GROUPE',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Rapport Financier',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Période se terminant le ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),

              // ✅ SECTION INFORMATIONS UTILISATEUR (NOUVEAU)
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Icon(pw.IconData(0xF0E0), size: 12, color: PdfColors.blue800),
                        pw.SizedBox(width: 5),
                        pw.Text(
                          'Informations du client',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Nom: $userName', style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Expanded(
                          child: pw.Text('Email: $userEmail', style: const pw.TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date de génération: $generationDate',
                      style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Résumé de la période
              _buildPdfSectionTitle('Résumé de la Période'),
              pw.SizedBox(height: 10),
              pw.Text('- Nombre total de factures traitées : $totalInvoices'),
              pw.SizedBox(height: 5),
              pw.Text('- Dépenses totales (TTC) : ${totalTTC.toStringAsFixed(3)} TND'),
              pw.SizedBox(height: 5),
              pw.Text('- TVA totale potentiellement déductible : ${totalTVA.toStringAsFixed(3)} TND'),
              pw.SizedBox(height: 30),

              // Analyse par fournisseur
              if (top5Suppliers.isNotEmpty) ...[
                _buildPdfSectionTitle('Analyse par Fournisseur'),
                pw.SizedBox(height: 15),
                pw.Center(
                  child: pw.Text('Top 5 des Dépenses par Fournisseur', style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 200,
                  child: pw.Chart(
                    grid: pw.CartesianGrid(
                      xAxis: pw.FixedAxis.fromStrings(
                        List<String>.generate(top5Suppliers.length, (i) {
                          String name = top5Suppliers[i].key;
                          return name.length > 15 ? name.substring(0, 15) + '...' : name;
                        }),
                        marginStart: 30,
                        marginEnd: 30,
                        ticks: true,
                      ),
                      yAxis: pw.FixedAxis(
                        yTicks,
                        format: (v) => v.toInt().toString(),
                        divisions: true,
                      ),
                    ),
                    datasets: [
                      pw.BarDataSet(
                        color: PdfColors.blue400,
                        width: 40,
                        data: List<pw.PointChartValue>.generate(
                          top5Suppliers.length,
                              (i) => pw.PointChartValue(i.toDouble(), top5Suppliers[i].value),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
              ],

            

                const SizedBox(height: 8),

                Expanded(
                  child: _isLoading || isProcessing
                      ? const Center(child: CircularProgressIndicator())
                      : filteredDocuments.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocuments[index];
                      return _buildDocumentCard(doc, context);
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: isLoggedIn
          ? FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/scan'),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.document_scanner, color: Colors.white),
        tooltip: 'Scanner une facture',
      )
          : null,
    );
  }

  Widget _buildDocumentCard(ScannedDocument doc, BuildContext context) {
    final invoiceNumber = doc.extractedData['invoice_number'] ?? 'N/A';
    final supplier = doc.extractedData['supplier_name'] ?? 'Fournisseur inconnu';
    final amount = doc.extractedData['total_ttc'] ?? doc.extractedData['net_a_payer'] ?? '0.00';
    final formattedAmount = _formatAmount(amount);

    final isFavorite = _favoriteIds.contains(doc.id.toString());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.receipt,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
        ),
        title: Text(
          'Facture $invoiceNumber',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              supplier,
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Montant: $formattedAmount',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).primaryColor,
              ),
            ),
            Text(
              'Créée le: ${_formatDateTime(doc.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
       
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(doc, context);
              },
            ),
          ],
        ),
      ),
    );
  }
  void _showDeleteDialog(ScannedDocument doc, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Supprimer la facture', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer cette facture ?',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument(doc, context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteDocument(ScannedDocument doc, BuildContext context) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    final success = await provider.deleteDocument(doc.id, userId: doc.userId);

    if (_favoriteIds.contains(doc.id.toString())) {
      _toggleFavorite(doc.id.toString());
    }

    
          ),
        );
      }
    }
  }
}
