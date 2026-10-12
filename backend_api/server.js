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
const JWT_SECRET = process.env.JWT_SECRET || 'neivos_secret_2024';
const OCR_API_URL = process.env.OCR_API_URL || 'http://37.60.239.139:8775';

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

    await db.query('UPDATE users SET updated_at = NOW() WHERE id = ?', [user.id]);
    await logActivity(user.id, 'login', 'user', user.id.toString(), 'Connexion réussie', req.ip);

    res.status(200).json({
      success: true,
      message: 'Connexion réussie',
      accessToken: token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        gender: user.gender,
        role: user.role,
        is_active: user.is_active,
        profile_image: user.profile_image_path,
        created_at: user.created_at
      }
    });

  } catch (error) {
    console.error('❌ Erreur connexion:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur lors de la connexion',
      error: error.message
    });
  }
});

// ✅ NOUVELLE ROUTE : MOT DE PASSE OUBLIÉ (CORRIGÉE)
app.post('/forgot-password', async (req, res) => {
  const { email } = req.body;

  try {
    const [users] = await db.query('SELECT * FROM users WHERE email = ?', [email]);

    if (users.length === 0) {
      return res.status(404).json({ success: false, message: "Aucun compte trouvé avec cet email" });
    }

    const user = users[0];

    // Générer un mot de passe temporaire de 8 caractères
    const tempPassword = crypto.randomBytes(4).toString('hex');

    // Hasher le mot de passe
    const hashedPassword = await bcrypt.hash(tempPassword, 10);

    // Mettre à jour le mot de passe dans la base de données
    await db.query('UPDATE users SET password_hash = ? WHERE id = ?', [hashedPassword, user.id]);

    // Préparer l'email
    const mailOptions = {
      from: `"Neivos Facture" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: 'Réinitialisation de votre mot de passe',
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
          <h2 style="color: #00529B;">Bonjour ${user.username},</h2>
          <p>Vous avez demandé la réinitialisation de votre mot de passe pour l'application <b>Neivos Facture</b>.</p>
          <p>Voici votre mot de passe temporaire :</p>
          <h3 style="background-color: #f4f4f4; padding: 10px; display: inline-block; border-radius: 5px; letter-spacing: 2px;">${tempPassword}</h3>
          <p>Veuillez vous connecter avec ce mot de passe et le <b>changer immédiatement</b> dans les paramètres de votre profil.</p>
          <br>
          <p>Cordialement,<br>L'équipe Neivos Facture</p>
        </div>
      `
    };

    // Envoyer l'email EN ARRIÈRE-PLAN
    transporter.sendMail(mailOptions).then(() => {
      console.log('✅ Email envoyé avec succès à', email);
    }).catch(err => {
      console.error('❌ Erreur lors de l\'envoi de l\'email en arrière-plan :', err);
    });

    // Enregistrer l'activité
    await logActivity(user.id, 'password_reset', 'user', user.id.toString(), 'Demande de réinitialisation de mot de passe', req.ip);

    // Répondre IMMÉDIATEMENT à l'application
    res.status(200).json({ success: true, message: "Email envoyé avec succès" });

  } catch (error) {
    console.error('❌ Erreur forgot-password:', error);
    res.status(500).json({ success: false, message: "Erreur lors de l'envoi de l'email" });
  }
}); // <-- C'est souvent cette parenthèse/accolade qui a été effacée par erreur !
// Obtenir le profil utilisateur
app.get('/profile', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const [users] = await db.query(
      'SELECT id, username, email, gender, role, is_active, profile_image_path, created_at FROM users WHERE id = ?',
      [userId]
    );

    if (users.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Utilisateur non trouvé'
      });
    }

    const user = users[0];

    res.status(200).json({
      success: true,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        gender: user.gender,
        role: user.role,
        is_active: user.is_active,
        profile_image: user.profile_image_path,
        created_at: user.created_at
      }
    });

  } catch (error) {
    console.error('❌ Erreur profil:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur',
      error: error.message
    });
  }
});

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

// 2. STATISTIQUES ADMIN

app.get('/api/admin/stats', authenticateToken, isAdmin, async (req, res) => {
  try {
    // Statistiques utilisateurs
    const [userStats] = await db.query(
      `SELECT
        COUNT(*) as total_users,
        SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active_users,
        SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) as inactive_users,
        SUM(CASE WHEN role = 'admin' THEN 1 ELSE 0 END) as admin_count,
        SUM(CASE WHEN role = 'accountant' THEN 1 ELSE 0 END) as accountant_count
       FROM users`
    );

    // Statistiques factures
    const [invoiceStats] = await db.query(
      `SELECT
        COUNT(*) as total_invoices,
        COALESCE(SUM(total_ttc), 0) as total_amount
       FROM invoices`
    );

    // Factures par mois
    const [monthlyInvoices] = await db.query(
      `SELECT
        DATE_FORMAT(created_at, '%Y-%m') as month,
        COUNT(*) as count
       FROM invoices
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
       GROUP BY DATE_FORMAT(created_at, '%Y-%m')
       ORDER BY month DESC`
    );

    // Activité récente
    const [recentActivity] = await db.query(
      `SELECT
        al.*,
        u.username as user_name
       FROM activity_logs al
       LEFT JOIN users u ON al.user_id = u.id
       ORDER BY al.created_at DESC
       LIMIT 20`
    );

    const monthlyMap = {};
    monthlyInvoices.forEach(item => {
      monthlyMap[item.month] = item.count;
    });

    res.status(200).json({
      success: true,
      stats: {
        total_users: userStats[0]?.total_users || 0,
        active_users: userStats[0]?.active_users || 0,
        inactive_users: userStats[0]?.inactive_users || 0,
        admin_count: userStats[0]?.admin_count || 0,
        accountant_count: userStats[0]?.accountant_count || 0,
        total_invoices: invoiceStats[0]?.total_invoices || 0,
        total_amount: parseFloat(invoiceStats[0]?.total_amount || 0),
        monthly_invoices: monthlyMap,
        recent_activity: recentActivity
      }
    });
  } catch (error) {
    console.error('❌ Erreur stats admin:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// 3. GESTION DES FACTURES (ADMIN)

// Récupérer toutes les factures (admin)
app.get('/api/admin/invoices', authenticateToken, isAdmin, async (req, res) => {
  try {
    const [invoices] = await db.query(
      `SELECT
        i.*,
        u.username as user_name,
        u.email as user_email
       FROM invoices i
       LEFT JOIN users u ON i.user_id = u.id
       ORDER BY i.created_at DESC`
    );

    res.status(200).json({
      success: true,
      invoices: invoices,
      count: invoices.length
    });
  } catch (error) {
    console.error('❌ Erreur récupération factures:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Supprimer une facture (admin)
app.delete('/api/admin/invoices/:id', authenticateToken, isAdmin, async (req, res) => {
  try {
    const invoiceId = req.params.id;

    // Récupérer les infos de la facture pour le log
    const [invoiceInfo] = await db.query(
      'SELECT invoice_number, user_id FROM invoices WHERE id = ?',
      [invoiceId]
    );

    if (invoiceInfo.length === 0) {
      return res.status(404).json({ success: false, message: 'Facture non trouvée' });
    }

    // Supprimer de scanned_documents liés
    await db.query('DELETE FROM scanned_documents WHERE document_number = ? AND user_id = ?',
      [invoiceInfo[0].invoice_number, invoiceInfo[0].user_id]);

    // Supprimer la facture
    await db.query('DELETE FROM invoices WHERE id = ?', [invoiceId]);

    await logActivity(req.user.id, 'delete_invoice', 'invoice', invoiceId,
      `Suppression facture ${invoiceInfo[0]?.invoice_number}`, req.ip);

    res.status(200).json({ success: true, message: 'Facture supprimée' });
  } catch (error) {
    console.error('❌ Erreur suppression facture:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// 4. PARAMÈTRES SYSTÈME

// Récupérer les paramètres
app.get('/api/admin/settings', authenticateToken, isAdmin, async (req, res) => {
  try {
    const [settings] = await db.query('SELECT * FROM system_settings');

    const settingsObj = {};
    settings.forEach(setting => {
      let value = setting.setting_value;
      if (setting.setting_type === 'bool') {
        value = value === 'true';
      } else if (setting.setting_type === 'int') {
        value = parseInt(value);
      } else if (setting.setting_type === 'json') {
        try {
          value = JSON.parse(value);
        } catch (e) {
          value = [];
        }
      }
      settingsObj[setting.setting_key] = value;
    });

    res.status(200).json({ success: true, settings: settingsObj });
  } catch (error) {
    console.error('❌ Erreur récupération paramètres:', error);
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

    res.status(200).json({
      success: true,
      reports: reports
    });
  } catch (error) {
    console.error('❌ Erreur récupération rapports de bug:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// ============ ROUTES DOCUMENTS & INVOICES ============

// Sauvegarder une facture
app.post('/api/invoices/save', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      invoice_number,
      supplier_name,
      invoice_date,
      total_ht,
      total_ttc,
      tva_amount,
      net_a_payer,
      retenue_source,
      timbre_fiscal,
      matricule_fiscal,
      client_name,
      client_address,
      client_tax_id,
      supplier_address,
      supplier_tax_id,
      tva_rate,
      currency,
      payment_terms,
      due_date,
      iban,
      phone,
      email,
      description,
      raw_text,
      confidence,
      processed_with,
      extracted_data
    } = req.body;

    console.log('📥 Sauvegarde facture pour user:', userId);
    console.log('📄 Numéro facture:', invoice_number);

    // Vérification des doublons
    if (invoice_number && invoice_number !== 'INCONNU' && invoice_number !== 'N/A' && invoice_number !== '') {
      const [existingInvoices] = await db.query(
        `SELECT id, invoice_number, supplier_name, created_at
         FROM invoices
         WHERE user_id = ? AND invoice_number = ? AND supplier_name = ?`,
        [userId, invoice_number, supplier_name || 'Inconnu']
      );

      if (existingInvoices.length > 0) {
        const existing = existingInvoices[0];
        console.log('⚠️ Facture en double détectée:', existing);

        return res.status(409).json({
          success: false,
          message: 'Ce document a déjà été scanné et enregistré.',
          duplicate: true,
          existing_invoice: {
            id: existing.id,
            invoice_number: existing.invoice_number,
            supplier_name: existing.supplier_name,
            created_at: existing.created_at
          }
        });
      }
    }

    // Insérer dans scanned_documents
    const [documentResult] = await db.query(
      `INSERT INTO scanned_documents (
        user_id, document_type, document_subtype,
        document_number, supplier_name, total_amount,
        currency, confidence, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        userId,
        'invoice',
        'facture_standard',
        invoice_number || `FAC_${Date.now()}`,
        supplier_name || 'Inconnu',
        total_ttc || 0,
        currency || 'TND',
        confidence || 0.8
      ]
    );

    const documentId = documentResult.insertId;

    // Insérer dans la table invoices
    const [invoiceResult] = await db.query(
      `INSERT INTO invoices (
        user_id, invoice_number, supplier_name, invoice_date,
        total_ht, total_ttc, tva_amount, tva_rate,
        timbre_fiscal, net_a_payer, matricule_fiscal,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        userId,
        invoice_number,
        supplier_name,
        invoice_date,
        total_ht || 0,
        total_ttc || 0,
        tva_amount || 0,
        tva_rate || 19,
        timbre_fiscal || 0.6,
        net_a_payer || total_ttc || 0,
        matricule_fiscal || ''
      ]
    );

    const invoiceId = invoiceResult.insertId;

    // Sauvegarder les données extraites
    if (extracted_data && typeof extracted_data === 'object') {
      const fieldsToSave = [
        'invoice_number', 'supplier_name', 'invoice_date', 'total_ht',
        'total_ttc', 'tva_amount', 'tva_rate', 'timbre_fiscal',
        'net_a_payer', 'matricule_fiscal', 'client_name',
        'client_address', 'client_tax_id', 'supplier_address',
        'supplier_tax_id', 'currency', 'payment_terms', 'due_date',
        'iban', 'phone', 'email', 'description'
      ];

      for (const field of fieldsToSave) {
        if (extracted_data[field]) {
          await db.query(
            `INSERT INTO extracted_data (
              document_id, field_name, field_value,
              confidence_score, created_at
            ) VALUES (?, ?, ?, ?, NOW())`,
            [documentId, field, extracted_data[field].toString(), confidence || 0.8]
          );
        }
      }
    }

    if (raw_text) {
      await db.query(
        `INSERT INTO extracted_data (document_id, field_name, field_value, confidence_score, created_at)
         VALUES (?, ?, ?, ?, NOW())`,
        [documentId, 'raw_text', raw_text, confidence || 0.8]
      );
    }

    await logActivity(userId, 'save_invoice', 'invoice', invoiceId.toString(),
      `Sauvegarde facture ${invoice_number}`, req.ip);

    res.status(201).json({
      success: true,
      message: 'Facture sauvegardée avec succès',
      document_id: documentId,
      invoice_id: invoiceId
    });

  } catch (error) {
    console.error('❌ Erreur sauvegarde facture:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur lors de la sauvegarde',
      error: error.message
    });
  }
});

// Récupérer les factures d'un utilisateur
app.get('/api/invoices/user/:userId', authenticateToken, async (req, res) => {
  try {
    const userId = req.params.userId;

    if (req.user.id.toString() !== userId && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Accès non autorisé'
      });
    }

    console.log('📥 Récupération factures pour user:', userId);

    const [documents] = await db.query(
      `SELECT
        sd.*,
        i.invoice_number, i.invoice_date,
        i.total_ht, i.total_ttc, i.tva_amount, i.tva_rate,
        i.timbre_fiscal, i.net_a_payer, i.matricule_fiscal
      FROM scanned_documents sd
      LEFT JOIN invoices i ON sd.user_id = i.user_id AND sd.document_number = i.invoice_number
      WHERE sd.user_id = ? AND sd.document_type = 'invoice'
      ORDER BY sd.created_at DESC`,
      [userId]
    );

    const invoicesWithData = await Promise.all(
      documents.map(async (doc) => {
        const [extractedData] = await db.query(
          `SELECT field_name, field_value, confidence_score
           FROM extracted_data
           WHERE document_id = ?
           ORDER BY field_name`,
          [doc.id]
        );

        const extractedDataObj = {};
        extractedData.forEach(item => {
          extractedDataObj[item.field_name] = item.field_value;
        });

        return {
          ...doc,
          extractedData: extractedDataObj,
          id: doc.id.toString()
        };
      })
    );

    res.status(200).json({
      success: true,
      invoices: invoicesWithData,
      count: invoicesWithData.length
    });

  } catch (error) {
    console.error('❌ Erreur récupération factures:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur',
      error: error.message
    });
  }
});

// Route de suppression d'une facture
app.delete('/api/invoices/:invoiceId', authenticateToken, async (req, res) => {
  try {
    const invoiceId = req.params.invoiceId;
    const userId = req.user.id;

    console.log('🗑️ Suppression facture:', invoiceId, 'par user:', userId);

    // Vérifier que la facture appartient à l'utilisateur
    const [documents] = await db.query(
      'SELECT id, document_number FROM scanned_documents WHERE id = ? AND user_id = ?',
      [invoiceId, userId]
    );

    if (documents.length === 0 && req.user.role !== 'admin') {
      return res.status(404).json({
        success: false,
        message: 'Facture non trouvée ou non autorisée'
      });
    }

    // Supprimer les données extraites
    await db.query('DELETE FROM extracted_data WHERE document_id = ?', [invoiceId]);

    // Supprimer scanned_documents
    await db.query('DELETE FROM scanned_documents WHERE id = ?', [invoiceId]);

    // Supprimer de la table invoices
    if (documents.length > 0 && documents[0].document_number) {
      await db.query(
        'DELETE FROM invoices WHERE user_id = ? AND invoice_number = ?',
        [userId, documents[0].document_number]
      );
    }

    // Logger l'activité
    await logActivity(userId, 'delete_invoice', 'invoice', invoiceId,
      `Suppression facture par utilisateur`, req.ip);

    res.status(200).json({
      success: true,
      message: 'Facture supprimée avec succès'
    });

  } catch (error) {
    console.error('❌ Erreur suppression facture:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur',
      error: error.message
    });
  }
});

// Statistiques utilisateur
app.get('/api/user/stats', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const [totalResult] = await db.query(
      'SELECT COUNT(*) as count FROM scanned_documents WHERE user_id = ? AND document_type = "invoice"',
      [userId]
    );

    const [amountResult] = await db.query(
      'SELECT SUM(total_ttc) as total FROM invoices WHERE user_id = ?',
      [userId]
    );

    const [recentResult] = await db.query(
      `SELECT
        sd.id, sd.document_number, sd.supplier_name,
        sd.total_amount, sd.created_at
      FROM scanned_documents sd
      WHERE sd.user_id = ? AND sd.document_type = "invoice"
        AND sd.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      ORDER BY sd.created_at DESC
      LIMIT 10`,
      [userId]
    );

    const [suppliersResult] = await db.query(
      `SELECT
        supplier_name,
        COUNT(*) as count,
        SUM(total_amount) as total_amount
      FROM scanned_documents
      WHERE user_id = ? AND document_type = "invoice" AND supplier_name IS NOT NULL
      GROUP BY supplier_name
      ORDER BY count DESC
      LIMIT 5`,
      [userId]
    );

    res.status(200).json({
      success: true,
      stats: {
        total_invoices: totalResult[0].count || 0,
        total_amount: amountResult[0].total || 0,
        recent_invoices: recentResult,
        top_suppliers: suppliersResult
      }
    });

  } catch (error) {
    console.error('❌ Erreur statistiques:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur serveur',
      error: error.message
    });
  }
});

// Route OCR proxy
app.post('/api/ocr/process', authenticateToken, async (req, res) => {
  try {
    console.log('📡 Proxy OCR appelé');

    res.status(200).json({
      success: true,
      message: 'OCR processing available',
      data: {
        available: true,
        endpoint: OCR_API_URL
      }
    });

  } catch (error) {
    console.error('❌ Erreur proxy OCR:', error);
    res.status(500).json({
      success: false,
      message: 'Erreur proxy OCR',
      error: error.message
    });
  }
});

// Démarrer le serveur
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n🚀 Serveur Neivos OCR démarré sur le port ${PORT}`);
  console.log(`🔗 URL OCR API: ${OCR_API_URL}`);
  console.log(`📊 Base de données: ${process.env.DB_HOST || 'localhost'}:${process.env.DB_PORT || '3306'}/${process.env.DB_NAME || 'ocr_scanner_db'}`);
  console.log(`📧 Email configuré: ${process.env.EMAIL_USER}`);
  console.log(`📸 Dossier images profil: ${PROFILE_IMAGES_DIR}`);
  console.log(`👑 Mode Admin: Activé\n`);
});

