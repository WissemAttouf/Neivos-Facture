// lib/config/api_config.dart
class ApiConfig {
  // Backend principal (Node.js)
  static const String backendBaseUrl = 'http://37.60.239.139:8086';

  // API OCR externe (NEIVOS)
  static const String ocrBaseUrl = 'http://37.60.239.139:8775';

  // Endpoints utiles
  static const String ocrEndpoint = '$ocrBaseUrl/extract-invoices/';
  static const String healthEndpoint = '$backendBaseUrl/health';
  static const String saveInvoiceEndpoint = '$backendBaseUrl/api/invoices/save';
}