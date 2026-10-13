// server.js -
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const axios = require('axios');
const FormData = require('form-data');
const path = require('path');
const fs = require('fs');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 8086;
if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET doit être configuré dans les variables d’environnement.');
}

const JWT_SECRET = process.env.JWT_SECRET;
const OCR_API_URL = process.env.OCR_API_URL || 'http://**.**.***.***:8775';

// ✅ CONFIGURATION NODEMAILER (Pour le mot de passe oublié)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS
  }
});

// Dossier pour les images de profil
const PROFILE_IMAGES_DIR = path.join(__dirname, 'uploads', 'profiles');
if (!fs.existsSync(PROFILE_IMAGES_DIR)) {
  fs.mkdirSync(PROFILE_IMAGES_DIR, { recursive: true });
}

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Configuration Multer
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    if (file.fieldname === 'profileImage') {
      cb(null, PROFILE_IMAGES_DIR);
    } else {
      const tempDir = path.join(__dirname, 'uploads', 'temp');
      if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });
      cb(null, tempDir);
    }
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.fieldname === 'profileImage') {
      const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png'];
      if (allowedTypes.includes(file.mimetype)) {
        cb(null, true);
      } else {
        cb(new Error('Seules les images JPG, PNG sont autorisées'));
      }
    } else {
      const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'application/pdf'];
      if (allowedTypes.includes(file.mimetype)) {
        cb(null, true);
      } else {
        cb(new Error('Seules les images JPG, PNG et PDF sont autorisées'));
      }
    }
  }
});

// Middleware d'authentification
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: "Token d'authentification manquant"
    });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        message: "Token invalide ou expiré"
      });
    }
    req.user = user;
    next();
  });
};

// Middleware pour vérifier si l'utilisateur est admin
const isAdmin = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const [users] = await db.query(
      'SELECT role FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0 || users[0].role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Accès non autorisé. Droits administrateur requis.'
      });
    }
    next();
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Fonction pour logger les activités
async function logActivity(userId, action, entityType = null, entityId = null, details = null, ipAddress = null) {
  try {
    await db.query(
      `INSERT INTO activity_logs (user_id, action, entity_type, entity_id, details, ip_address)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [userId, action, entityType, entityId, details, ipAddress]
    );
  } catch (error) {
    console.error('❌ Erreur log activité:', error);
  }
}

// ============ ROUTES D'AUTHENTIFICATION ============

// Route de test
app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Serveur Neivos OCR en ligne',
    timestamp: new Date().toISOString()
  });
});

// Inscription
app.post('/register', async (req, res) => {
  try {
    const { username, email, password, gender } = req.body;

    if (!username || !email || !password || !gender) {
      return res.status(400).json({
        success: false,
        message: 'Tous les champs sont obligatoires'
      });
    }

    const [existingUsers] = await db.query(
      'SELECT id FROM users WHERE email = ?',
      [email]
    );

    if (existingUsers.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'Un utilisateur avec cet email existe déjà'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const [result] = await db.query(
      'INSERT INTO users (username, email, password_hash, gender, role, is_active) VALUES (?, ?, ?, ?, ?, ?)',
      [username, email, hashedPassword, gender, 'user', 1]
    );

    const token = jwt.sign(
      { id: result.insertId, email, username },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      success: true,
      message: 'Inscription réussie',
      accessToken: token,
      user: {
        id: result.insertId,
        username,
        email,
        gender,
        role: 'user',
        is_active: true
      }
    });

  } catch (error) {
    console.error('❌ Erreur inscription:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur lors de l\'inscription',
      error: error.message
    });
  }
});

// Connexion
app.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email et mot de passe requis'
      });
    }

    const [users] = await db.query(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        message: 'Identifiants incorrects'
      });
    }

    const user = users[0];

    if (!user.is_active) {
      return res.status(401).json({
        success: false,
        message: 'Votre compte a été désactivé. Veuillez contacter l\'administrateur.'
      });
    }

    const passwordMatch = await bcrypt.compare(password, user.password_hash);

    if (!passwordMatch) {
      return res.status(401).json({
        success: false,
        message: 'Identifiants incorrects'
      });
    }

    const token = jwt.sign(
      {
        id: user.id,
        email: user.email,
        username: user.username,
        role: user.role
      },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

   

// Mettre à jour le profil utilisateur
app.put('/profile', upload.single('profileImage'), authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const { username, email, currentPassword, newPassword } = req.body;
    const profileImage = req.file;

    console.log('\n🔄 Mise à jour profil pour user:', userId);

    const [users] = await db.query(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    const user = users[0];
    const updates = [];
    const values = [];

    if (username && username.trim() !== '' && username !== user.username) {
      updates.push('username = ?');
      values.push(username.trim());
    }

    if (email && email.trim() !== '' && email !== user.email) {
      const [existingEmail] = await db.query(
        'SELECT id FROM users WHERE email = ? AND id != ?',
        [email, userId]
      );

      if (existingEmail.length > 0) {
        return res.status(409).json({
          success: false,
          message: 'Cet email est déjà utilisé'
        });
      }

      updates.push('email = ?');
      values.push(email.trim());
    }

    if (newPassword && newPassword.trim() !== '') {
      if (!currentPassword) {
        return res.status(400).json({
          success: false,
          message: 'Mot de passe actuel requis'
        });
      }

      const passwordMatch = await bcrypt.compare(currentPassword, user.password_hash);
      if (!passwordMatch) {
        return res.status(401).json({
          success: false,
          message: 'Mot de passe actuel incorrect'
        });
      }

      const hashedPassword = await bcrypt.hash(newPassword, 10);
      updates.push('password_hash = ?');
      values.push(hashedPassword);
    }

    if (profileImage) {
      if (user.profile_image_path) {
        const oldImagePath = path.join(PROFILE_IMAGES_DIR, user.profile_image_path);
        if (fs.existsSync(oldImagePath)) {
          fs.unlinkSync(oldImagePath);
        }
      }
      updates.push('profile_image_path = ?');
      values.push(profileImage.filename);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Aucune donnée à mettre à jour'
      });
    }

    values.push(userId);
    const query = `UPDATE users SET ${updates.join(', ')}, updated_at = NOW() WHERE id = ?`;
    await db.query(query, values);

    await logActivity(userId, 'update_profile', 'user', userId.toString(), 'Profil mis à jour', req.ip);

    const [updatedUsers] = await db.query(
      'SELECT id, username, email, gender, role, is_active, profile_image_path, created_at FROM users WHERE id = ?',
      [userId]
    );

    const updatedUser = updatedUsers[0];

    res.status(200).json({
      success: true,
      message: 'Profil mis à jour avec succès',
      user: {
        id: updatedUser.id,
        username: updatedUser.username,
        email: updatedUser.email,
        gender: updatedUser.gender,
        role: updatedUser.role,
        is_active: updatedUser.is_active,
        profile_image: updatedUser.profile_image_path,
        created_at: updatedUser.created_at
      }
    });

  } catch (error) {
    console.error('❌ Erreur mise à jour profil:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur',
      error: error.message
    });
  }
});

// ============ ROUTES ADMINISTRATEUR ============

// 1. GESTION DES UTILISATEURS

// Récupérer tous les utilisateurs (admin uniquement)
app.get('/api/admin/users', authenticateToken, isAdmin, async (req, res) => {
  try {
    const [users] = await db.query(
      `SELECT id, username, email, gender, role, is_active, profile_image_path, created_at, updated_at
       FROM users
       ORDER BY created_at DESC`
    );

    res.status(200).json({
      success: true,
      users: users,
      count: users.length
    });
  } catch (error) {
    console.error('❌ Erreur récupération utilisateurs:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Récupérer un utilisateur par ID (admin uniquement)
app.get('/api/admin/users/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    const userId = req.params.id;

    const [users] = await db.query(
      `SELECT id, username, email, gender, role, is_active, profile_image_path, created_at, updated_at
       FROM users WHERE id = ?`,
      [userId]
    );

    if (users.length === 0) {
      return res.status(404).json({ success: false, message: 'Utilisateur non trouvé' });
    }

    res.status(200).json({ success: true, user: users[0] });
  } catch (error) {
    console.error('❌ Erreur récupération utilisateur:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Créer un utilisateur (admin uniquement)
app.post('/api/admin/users', authenticateToken, isAdmin, async (req, res) => {
  try {
    const { username, email, password, gender, role, is_active } = req.body;

    if (!username || !email || !password) {
      return res.status(400).json({ success: false, message: 'Champs requis manquants' });
    }

    // Vérifier si l'email existe déjà
    const [existingUsers] = await db.query('SELECT id FROM users WHERE email = ?', [email]);
    if (existingUsers.length > 0) {
      return res.status(409).json({ success: false, message: 'Cet email est déjà utilisé' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const userRole = role || 'user';
    const userActive = is_active !== undefined ? is_active : 1;

    const [result] = await db.query(
      'INSERT INTO users (username, email, password_hash, gender, role, is_active) VALUES (?, ?, ?, ?, ?, ?)',
      [username, email, hashedPassword, gender || 'homme', userRole, userActive]
    );

    await logActivity(req.user.id, 'create_user', 'user', result.insertId.toString(),
      `Création utilisateur: ${username} (${userRole})`, req.ip);

    res.status(201).json({
      success: true,
      message: 'Utilisateur créé avec succès',
      userId: result.insertId
    });
  } catch (error) {
    console.error('❌ Erreur création utilisateur:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Modifier un utilisateur (admin uniquement)
app.put('/api/admin/users/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    const userId = req.params.id;
    const { username, email, role, is_active, password } = req.body;

    // Vérifier si l'utilisateur existe
    const [existingUsers] = await db.query('SELECT * FROM users WHERE id = ?', [userId]);
    if (existingUsers.length === 0) {
      return res.status(404).json({ success: false, message: 'Utilisateur non trouvé' });
    }

    const updates = [];
    const values = [];

    if (username !== undefined) {
      updates.push('username = ?');
      values.push(username);
    }
    if (email !== undefined) {
      // Vérifier si l'email n'est pas déjà utilisé
      const [emailCheck] = await db.query('SELECT id FROM users WHERE email = ? AND id != ?', [email, userId]);
      if (emailCheck.length > 0) {
        return res.status(409).json({ success: false, message: 'Cet email est déjà utilisé' });
      }
      updates.push('email = ?');
      values.push(email);
    }
    if (role !== undefined) {
      updates.push('role = ?');
      values.push(role);
    }
    if (is_active !== undefined) {
      updates.push('is_active = ?');
      values.push(is_active);
    }
    if (password && password.trim() !== '') {
      const hashedPassword = await bcrypt.hash(password, 10);
      updates.push('password_hash = ?');
      values.push(hashedPassword);
    }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'Aucune modification' });
    }

    values.push(userId);
    await db.query(`UPDATE users SET ${updates.join(', ')}, updated_at = NOW() WHERE id = ?`, values);

    await logActivity(req.user.id, 'update_user', 'user', userId,
      `Modification utilisateur ID ${userId}`, req.ip);

    res.status(200).json({ success: true, message: 'Utilisateur mis à jour' });
  } catch (error) {
    console.error('❌ Erreur modification utilisateur:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Supprimer un utilisateur (admin uniquement)
app.delete('/api/admin/users/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    const userId = req.params.id;

    // Vérifier si l'utilisateur existe
    const [existingUsers] = await db.query('SELECT * FROM users WHERE id = ?', [userId]);
    if (existingUsers.length === 0) {
      return res.status(404).json({ success: false, message: 'Utilisateur non trouvé' });
    }

    // Ne pas supprimer son propre compte
    if (parseInt(userId) === req.user.id) {
      return res.status(400).json({ success: false, message: 'Vous ne pouvez pas supprimer votre propre compte' });
    }

    await db.query('DELETE FROM users WHERE id = ?', [userId]);

    await logActivity(req.user.id, 'delete_user', 'user', userId,
      `Suppression utilisateur ID ${userId}`, req.ip);

    res.status(200).json({ success: true, message: 'Utilisateur supprimé' });
  } catch (error) {
    console.error('❌ Erreur suppression utilisateur:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});



// Mettre à jour les paramètres
app.put('/api/admin/settings', authenticateToken, isAdmin, async (req, res) => {
  try {
    const { settings } = req.body;

    for (const [key, value] of Object.entries(settings)) {
      let settingValue = value;
      let settingType = 'string';

      if (typeof value === 'boolean') {
        settingValue = value.toString();
        settingType = 'bool';
      } else if (typeof value === 'number') {
        settingValue = value.toString();
        settingType = 'int';
      } else if (typeof value === 'object') {
        settingValue = JSON.stringify(value);
        settingType = 'json';
      }

      await db.query(
        `INSERT INTO system_settings (setting_key, setting_value, setting_type, updated_at)
         VALUES (?, ?, ?, NOW())
         ON DUPLICATE KEY UPDATE
         setting_value = VALUES(setting_value),
         setting_type = VALUES(setting_type),
         updated_at = NOW()`,
        [key, settingValue, settingType]
      );
    }

    await logActivity(req.user.id, 'update_settings', 'system', null, 'Paramètres système mis à jour', req.ip);

    res.status(200).json({ success: true, message: 'Paramètres mis à jour' });
  } catch (error) {
    console.error('❌ Erreur mise à jour paramètres:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// 5. LOGS D'ACTIVITÉ

app.get('/api/admin/logs', authenticateToken, isAdmin, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 100;
    const offset = parseInt(req.query.offset) || 0;

    const [logs] = await db.query(
      `SELECT
        al.*,
        u.username as user_name,
        u.email as user_email
       FROM activity_logs al
       LEFT JOIN users u ON al.user_id = u.id
       ORDER BY al.created_at DESC
       LIMIT ? OFFSET ?`,
      [limit, offset]
    );

    const [total] = await db.query('SELECT COUNT(*) as total FROM activity_logs');

    res.status(200).json({
      success: true,
      logs: logs,
      total: total[0].total,
      limit: limit,
      offset: offset
    });
  } catch (error) {
    console.error('❌ Erreur récupération logs:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// ============ ROUTES POUR LES RAPPORTS DE BUG ============

// 1. L'utilisateur/comptable signale un bug
app.post('/api/bug-reports', authenticateToken, async (req, res) => {
  try {
    const { user_id, subject, description, app_version, device_info } = req.body;

    if (!subject || !description) {
      return res.status(400).json({
        success: false,
        message: 'Le sujet et la description sont obligatoires'
      });
    }

    const [result] = await db.query(
      `INSERT INTO bug_reports (user_id, subject, description, app_version, device_info, reported_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [user_id || 0, subject, description, app_version || '1.0.0', device_info || 'Mobile']
    );

    await logActivity(req.user.id, 'report_bug', 'bug', result.insertId.toString(), subject, req.ip);

    res.status(201).json({
      success: true,
      message: 'Rapport envoyé avec succès',
      report_id: result.insertId
    });

  } catch (error) {
    console.error('❌ Erreur enregistrement bug report:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur',
      error: error.message
    });
  }
});

// 2. L'administrateur lit les bugs signalés (NOUVELLE ROUTE)
app.get('/api/admin/bug-reports', authenticateToken, isAdmin, async (req, res) => {
  try {
    const [reports] = await db.query(
      `SELECT
        b.*,
        u.username as user_name,
        u.email as user_email
       FROM bug_reports b
       LEFT JOIN users u ON b.user_id = u.id
       ORDER BY b.reported_at DESC`
    );

  

// Démarrer le serveur
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 Serveur Neivos OCR démarré sur le port ${PORT}`);
  console.log(`🔗 URL OCR API: ${OCR_API_URL}`);
  console.log(`📊 Base de données: ${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || '3306'}/${process.env.DB_NAME || 'ocr_scanner_db'}`);
  console.log(`📧 Email configuré: ${process.env.EMAIL_USER}`);
  console.log(`📸 Dossier images profil: ${PROFILE_IMAGES_DIR}`);
  console.log(`👑 Mode Admin: Activé\n`);
});

