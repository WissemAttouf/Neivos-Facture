// lib/config/api_config.dart
class ApiConfig {
  // Backend principal (Node.js)
  static const String backendBaseUrl = '*************';

  // API OCR externe (NEIVOS)
  static const String ocrBaseUrl = '***********';

  // Endpoints utiles
  static const String ocrEndpoint = '$ocrBaseUrl/extract-invoices/';
  static const String healthEndpoint = '$backendBaseUrl/health';
  static const String saveInvoiceEndpoint = '$backendBaseUrl/api/invoices/save';
}
