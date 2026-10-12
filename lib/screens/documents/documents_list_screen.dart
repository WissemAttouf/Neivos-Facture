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
  bool _isGeneratingPDF = false;
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  int? _currentUserId;

  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadDocuments();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds = (prefs.getStringList('favorite_documents') ?? []).toSet();
    });
  }

  Future<void> _toggleFavorite(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteIds.contains(docId)) {
        _favoriteIds.remove(docId);
      } else {
        _favoriteIds.add(docId);
      }
      prefs.setStringList('favorite_documents', _favoriteIds.toList());
    });
  }

  Future<void> _loadDocuments() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final documentProvider = Provider.of<DocumentProvider>(context, listen: false);

    final userId = authProvider.user?.id;

    if (userId != null) {
      documentProvider.setCurrentUser(userId);
      _currentUserId = userId;
      await documentProvider.loadDocuments(userId: userId);
    } else {
      documentProvider.reset();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<ScannedDocument> _getFilteredDocuments(List<ScannedDocument> documents) {
    var filtered = documents.where((doc) => doc.userId == _currentUserId).toList();

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final invoiceNumber = doc.extractedData['invoice_number']?.toString().toLowerCase() ?? '';
        final supplier = doc.extractedData['supplier_name']?.toString().toLowerCase() ?? '';
        final client = doc.extractedData['client_name']?.toString().toLowerCase() ?? '';

        return invoiceNumber.contains(_searchQuery.toLowerCase()) ||
            supplier.contains(_searchQuery.toLowerCase()) ||
            client.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedFilter == 'Récents') {
      filtered = filtered.where((doc) {
        return doc.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)));
      }).toList();
    } else if (_selectedFilter == 'Anciens') {
      filtered = filtered.where((doc) {
        return doc.createdAt.isBefore(DateTime.now().subtract(const Duration(days: 30)));
      }).toList();
    } else if (_selectedFilter == 'Favoris') {
      filtered = filtered.where((doc) => _favoriteIds.contains(doc.id.toString())).toList();
    }

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  double _calculateTotalAmount(List<ScannedDocument> documents) {
    double total = 0;
    for (final doc in documents) {
      final amount = doc.extractedData['total_ttc'] ?? doc.extractedData['net_a_payer'];
      if (amount != null) {
        try {
          final amountStr = amount.toString().replaceAll('TND', '').replaceAll(',', '.').trim();
          final number = double.tryParse(amountStr);
          if (number != null) {
            total += number;
          }
        } catch (e) {
          // Ignorer
        }
      }
    }
    return total;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    String str = value.toString().replaceAll('TND', '').replaceAll(',', '.').replaceAll(' ', '').trim();
    double? parsed = double.tryParse(str);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return 0.0;
    return parsed;
  }

  // ✅ NOUVELLE FONCTION POUR OBTENIR LE NOM DE L'UTILISATEUR
  String _getUserName() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.user?.username ?? 'Utilisateur';
  }

  // ✅ NOUVELLE FONCTION POUR OBTENIR L'EMAIL DE L'UTILISATEUR
  String _getUserEmail() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.user?.email ?? 'email@non-renseigne.com';
  }

  // ✅ FONCTION DE GÉNÉRATION DU RAPPORT GLOBAL AVEC NOM UTILISATEUR
  Future<void> _downloadGlobalReportPDF() async {
    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      final documentProvider = Provider.of<DocumentProvider>(context, listen: false);
      final documents = documentProvider.documents.where((doc) => doc.userId == _currentUserId).toList();

      if (documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune facture à analyser.'), backgroundColor: Colors.orange),
        );
        setState(() => _isGeneratingPDF = false);
        return;
      }

      // Récupérer les informations de l'utilisateur
      final userName = _getUserName();
      final userEmail = _getUserEmail();
      final generationDate = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());

      int totalInvoices = documents.length;
      double totalTTC = 0;
      double totalTVA = 0;
      Map<String, double> supplierTotals = {};

      for (var doc in documents) {
        final data = doc.extractedData;

        double ttc = _parseDouble(data['total_ttc'] ?? data['net_a_payer']);
        totalTTC += ttc;

        double tva = _parseDouble(data['tva_amount']);
        totalTVA += tva;

        String supplier = data['supplier_name'] ?? data['supplier'] ?? 'Inconnu';
        supplierTotals[supplier] = (supplierTotals[supplier] ?? 0) + ttc;
      }

      var sortedSuppliers = supplierTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      var top5Suppliers = sortedSuppliers.take(5).toList();

      if (top5Suppliers.length == 1) {
        top5Suppliers.add(const MapEntry(' ', 0.0));
      }

      var recentDocs = List.from(documents)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      var topRecent = recentDocs.take(10).toList();

      double maxY = 0;
      if (top5Suppliers.isNotEmpty) {
        maxY = top5Suppliers.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      }

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

              // Détail des factures récentes
              _buildPdfSectionTitle('Détail des Factures Récentes'),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Fournisseur', 'Date', 'Total HT', 'Total TTC'],
                data: topRecent.map((doc) {
                  final data = doc.extractedData;
                  return [
                    data['supplier_name'] ?? data['supplier'] ?? 'Inconnu',
                    data['invoice_date'] ?? DateFormat('yyyy-MM-dd').format(doc.createdAt),
                    _parseDouble(data['total_ht']).toStringAsFixed(3),
                    _parseDouble(data['total_ttc'] ?? data['net_a_payer']).toStringAsFixed(3),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),

              // Pied de page
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Document généré par Neivos Facture - ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'Rapport_Financier_${userName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final file = File('${downloadDir.path}/$fileName');
          await file.writeAsBytes(bytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Rapport sauvegardé dans Téléchargements :\n$fileName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
        }
      } else {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }

    } catch (e) {
      print("Erreur PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du téléchargement du rapport: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isLoggedIn = authProvider.isLoggedIn;

    final documentProvider = Provider.of<DocumentProvider>(context);
    final documents = documentProvider.documents;
    final isProcessing = documentProvider.isProcessing;

    final filteredDocuments = _getFilteredDocuments(documents);
    final totalAmount = _calculateTotalAmount(filteredDocuments);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ssvg.PNG',
              height: 40,
              width: 40,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.receipt, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              'MES FACTURES',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          // Bouton pour télécharger le rapport global
          if (isLoggedIn && documents.isNotEmpty)
            IconButton(
              icon: _isGeneratingPDF
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(Icons.analytics, color: Theme.of(context).appBarTheme.foregroundColor),
              onPressed: _isGeneratingPDF ? null : _downloadGlobalReportPDF,
              tooltip: 'Rapport Financier',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).appBarTheme.foregroundColor),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadDocuments();
            },
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Stack(
        children: [
          ParticleBackground(isDarkMode: isDarkMode),

          if (!isLoggedIn)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Connectez-vous pour voir vos factures',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('SE CONNECTER'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Rechercher une facture...',
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyMedium?.color),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Tous', 'Récents', 'Anciens', 'Favoris'].map((filter) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: _selectedFilter == filter,
                                onSelected: (selected) {
                                  setState(() => _selectedFilter = selected ? filter : 'Tous');
                                },
                                backgroundColor: Theme.of(context).cardColor,
                                selectedColor: Theme.of(context).primaryColor,
                                labelStyle: TextStyle(
                                  color: _selectedFilter == filter
                                      ? Colors.white
                                      : Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredDocuments.length} facture${filteredDocuments.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Total: ${totalAmount.toStringAsFixed(3)} TND',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : Colors.grey.shade400,
              ),
              onPressed: () => _toggleFavorite(doc.id.toString()),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(document: doc.toMap()),
            ),
          );
        },
        onLongPress: () => _showDocumentOptions(doc, context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty && _selectedFilter == 'Tous'
                ? 'Aucune facture trouvée'
                : 'Aucun résultat',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty && _selectedFilter == 'Tous'
                ? 'Scannez votre première facture pour commencer'
                : 'Aucune facture ne correspond à votre recherche ou filtre',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isEmpty && _selectedFilter == 'Tous')
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/scan'),
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scanner une facture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  String _formatAmount(dynamic amount) {
    if (amount == null || amount.toString().isEmpty) return '0.00 TND';
    try {
      final number = double.tryParse(amount.toString().replaceAll(',', '.').replaceAll('TND', '').trim());
      if (number != null) {
        return '${number.toStringAsFixed(3)} TND';
      }
    } catch (e) {
      // Ignorer
    }
    return '$amount TND';
  }

  void _showDocumentOptions(ScannedDocument doc, BuildContext context) {
    final documentProvider = Provider.of<DocumentProvider>(context, listen: false);
    final isFavorite = _favoriteIds.contains(doc.id.toString());

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: Colors.amber
              ),
              title: Text(
                  isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleFavorite(doc.id.toString());
              },
            ),

            ListTile(
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

    if (success) {
      await _loadDocuments();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facture ${doc.extractedData['invoice_number'] ?? ''} supprimée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
