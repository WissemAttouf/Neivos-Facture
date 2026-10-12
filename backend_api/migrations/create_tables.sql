-- Migration pour créer les tables de l'application OCR Scanner
-- Version: 1.0.0
-- Date: 2025-01-26

-- Création de la base de données
CREATE DATABASE IF NOT EXISTS ocr_scanner_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE ocr_scanner_db;

CREATE DATABASE IF NOT EXISTS ocr_scanner_db;

USE ocr_scanner_db;

CREATE TABLE IF NOT EXISTS users (
  id CHAR(36) PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des utilisateurs
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    gender ENUM('homme', 'femme') NOT NULL,
    profile_image_path VARCHAR(255) DEFAULT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des documents scannés
CREATE TABLE IF NOT EXISTS scanned_documents (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    document_type ENUM('id_card', 'professional_badge', 'commercial_document', 'invoice', 'unknown') NOT NULL,
    original_text TEXT,
    image_path VARCHAR(255),
    image_size INT DEFAULT NULL,
    confidence DECIMAL(4,3) DEFAULT 0.000,
    processing_time_ms INT DEFAULT NULL,
    is_validated BOOLEAN DEFAULT FALSE,
    validation_score DECIMAL(4,3) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_documents (user_id, created_at DESC),
    INDEX idx_document_type (document_type),
    INDEX idx_confidence (confidence),
    INDEX idx_created_at (created_at DESC),
    FULLTEXT idx_original_text (original_text)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des données extraites
CREATE TABLE IF NOT EXISTS extracted_data (
    id INT PRIMARY KEY AUTO_INCREMENT,
    document_id INT NOT NULL,
    field_name VARCHAR(50) NOT NULL,
    field_value TEXT NOT NULL,
    confidence_score DECIMAL(4,3) DEFAULT 0.000,
    original_text TEXT DEFAULT NULL,
    field_position JSON DEFAULT NULL,
    is_manually_corrected BOOLEAN DEFAULT FALSE,
    validation_status ENUM('pending', 'validated', 'rejected') DEFAULT 'pending',
    metadata JSON DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (document_id) REFERENCES scanned_documents(id) ON DELETE CASCADE,
    INDEX idx_document_data (document_id),
    INDEX idx_field_name (field_name),
    INDEX idx_confidence_score (confidence_score),
    INDEX idx_validation_status (validation_status),
    FULLTEXT idx_field_value (field_value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des sessions utilisateur (pour JWT blacklist)
CREATE TABLE IF NOT EXISTS user_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    token_jti VARCHAR(255) UNIQUE NOT NULL,
    device_info JSON DEFAULT NULL,
    ip_address VARCHAR(45),
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_sessions (user_id, is_active),
    INDEX idx_token_jti (token_jti),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des logs d'activité
CREATE TABLE IF NOT EXISTS activity_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT DEFAULT NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) DEFAULT NULL,
    resource_id INT DEFAULT NULL,
    details JSON DEFAULT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_user_activity (user_id, created_at DESC),
    INDEX idx_action (action),
    INDEX idx_resource (resource_type, resource_id),
    INDEX idx_created_at (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des statistiques utilisateur (cache)
CREATE TABLE IF NOT EXISTS user_statistics (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL,
    total_documents INT DEFAULT 0,
    documents_this_week INT DEFAULT 0,
    documents_this_month INT DEFAULT 0,
    avg_confidence DECIMAL(4,3) DEFAULT 0.000,
    most_used_document_type VARCHAR(50) DEFAULT NULL,
    last_scan_date TIMESTAMP NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_total_documents (total_documents DESC),
    INDEX idx_last_updated (last_updated)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table des templates de documents (pour améliorer la reconnaissance)
CREATE TABLE IF NOT EXISTS document_templates (
    id INT PRIMARY KEY AUTO_INCREMENT,
    document_type ENUM('id_card', 'professional_badge', 'commercial_document', 'invoice', 'unknown') NOT NULL,
    template_name VARCHAR(100) NOT NULL,
    field_patterns JSON NOT NULL,
    confidence_weights JSON DEFAULT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    usage_count INT DEFAULT 0,
    success_rate DECIMAL(4,3) DEFAULT 0.000,
    created_by INT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_document_type_active (document_type, is_active),
    INDEX idx_success_rate (success_rate DESC),
    INDEX idx_usage_count (usage_count DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertion des templates par défaut
INSERT INTO document_templates (document_type, template_name, field_patterns, confidence_weights) VALUES
('id_card', 'Carte Identité Tunisienne',
 '{"nom": ["nom[:\\s]+([a-zA-ZÀ-ÿ\\s]+)", "^([A-ZÀ-Ÿ]{2,})\\s+[A-ZÀ-Ÿ]"], "prenom": ["prénom[:\\s]+([a-zA-ZÀ-ÿ\\s]+)", "prenom[:\\s]+([a-zA-ZÀ-ÿ\\s]+)"], "cin": ["cin[:\\s]*(\\d{8})", "\\b(\\d{8})\\b"], "date_birth": ["né\\(e\\)\\s+le[:\\s]*(\\d{1,2}[\\/\\-]\\d{1,2}[\\/\\-]\\d{4})", "(\\d{1,2}[\\/\\-]\\d{1,2}[\\/\\-]\\d{4})"]}',
 '{"nom": 0.9, "prenom": 0.9, "cin": 0.95, "date_birth": 0.8}'),

('professional_badge', 'Badge Professionnel Standard',
 '{"nom": ["nom[:\\s]+([a-zA-ZÀ-ÿ\\s]+)", "^([A-ZÀ-Ÿ]{2,})\\s+[A-ZÀ-Ÿ]"], "prenom": ["prénom[:\\s]+([a-zA-ZÀ-ÿ\\s]+)", "prenom[:\\s]+([a-zA-ZÀ-ÿ\\s]+)"], "matricule": ["matricule[:\\s]*([a-zA-Z0-9]+)", "mat[:\\s]*([a-zA-Z0-9]+)", "n°[:\\s]*([a-zA-Z0-9]+)"], "company": ["entreprise[:\\s]+([a-zA-ZÀ-ÿ\\s&\\.]+)", "société[:\\s]+([a-zA-ZÀ-ÿ\\s&\\.]+)"]}',
 '{"nom": 0.85, "prenom": 0.85, "matricule": 0.9, "company": 0.8}'),

('commercial_document', 'Document Commercial Standard',
 '{"company": ["^([A-ZÀ-Ÿ][a-zA-ZÀ-ÿ\\s&\\.]{2,})", "société[:\\s]+([a-zA-ZÀ-ÿ\\s&\\.]+)"], "tva": ["tva[:\\s]*([a-zA-Z]{2}\\d{8,})", "n°\\s*tva[:\\s]*([a-zA-Z]{2}\\d{8,})", "([a-zA-Z]{2}\\d{8,})"], "address": ["adresse[:\\s]+([a-zA-ZÀ-ÿ0-9\\s,\\.]+)"], "phone": ["tél[:\\s]*(\\+?[\\d\\s\\-\\(\\)]{8,})", "téléphone[:\\s]*(\\+?[\\d\\s\\-\\(\\)]{8,})", "(\\+?[\\d\\s\\-\\(\\)]{8,})"]}',
 '{"company": 0.8, "tva": 0.9, "address": 0.7, "phone": 0.75}');

-- Création des vues pour les statistiques
CREATE VIEW user_document_stats AS
SELECT
    u.id as user_id,
    u.username,
    COUNT(sd.id) as total_documents,
    COUNT(CASE WHEN sd.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY) THEN 1 END) as documents_this_week,
    COUNT(CASE WHEN sd.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY) THEN 1 END) as documents_this_month,
    AVG(sd.confidence) as avg_confidence,
    MAX(sd.created_at) as last_scan_date
FROM users u
LEFT JOIN scanned_documents sd ON u.id = sd.user_id
GROUP BY u.id, u.username;

-- Création des triggers pour maintenir les statistiques
DELIMITER //

CREATE TRIGGER update_user_stats_after_insert
AFTER INSERT ON scanned_documents
FOR EACH ROW
BEGIN
    INSERT INTO user_statistics (user_id, total_documents, documents_this_week, documents_this_month, avg_confidence, last_scan_date)
    VALUES (NEW.user_id, 1, 1, 1, NEW.confidence, NEW.created_at)
    ON DUPLICATE KEY UPDATE
        total_documents = total_documents + 1,
        documents_this_week = (
            SELECT COUNT(*) FROM scanned_documents
            WHERE user_id = NEW.user_id
            AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ),
        documents_this_month = (
            SELECT COUNT(*) FROM scanned_documents
            WHERE user_id = NEW.user_id
            AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        ),
        avg_confidence = (
            SELECT AVG(confidence) FROM scanned_documents
            WHERE user_id = NEW.user_id
        ),
        last_scan_date = NEW.created_at;
END//

CREATE TRIGGER update_user_stats_after_delete
AFTER DELETE ON scanned_documents
FOR EACH ROW
BEGIN
    UPDATE user_statistics
    SET
        total_documents = total_documents - 1,
        documents_this_week = (
            SELECT COUNT(*) FROM scanned_documents
            WHERE user_id = OLD.user_id
            AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        ),
        documents_this_month = (
            SELECT COUNT(*) FROM scanned_documents
            WHERE user_id = OLD.user_id
            AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        ),
        avg_confidence = (
            SELECT COALESCE(AVG(confidence), 0) FROM scanned_documents
            WHERE user_id = OLD.user_id
        ),
        last_scan_date = (
            SELECT MAX(created_at) FROM scanned_documents
            WHERE user_id = OLD.user_id
        )
    WHERE user_id = OLD.user_id;
END//

DELIMITER ;

-- Insertion d'un utilisateur de test (mot de passe: "password123")
INSERT INTO users (username, email, password_hash, gender, email_verified) VALUES
('testuser', 'test@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'homme', TRUE);

-- Affichage des informations de création
SELECT 'Base de données OCR Scanner créée avec succès!' as message;
SELECT 'Tables créées:' as info;
SELECT TABLE_NAME as tables FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'ocr_scanner_db';