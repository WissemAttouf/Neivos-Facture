# Neivos Facture

Application mobile Flutter de gestion et de numérisation de factures, associée à une API Node.js/Express et à une base de données MySQL. Le projet vise à faciliter la capture des factures, l’extraction des informations, leur validation et leur consultation.

> **État du déploiement :** le backend et la base de données cloud sont encore en cours de configuration. Les instructions ci-dessous décrivent principalement l’exécution locale ; elles ne signifient pas que la version cloud est déjà opérationnelle.

## Fonctionnalités

- Inscription et connexion des utilisateurs avec authentification par jeton JWT.
- Gestion du profil : consultation et mise à jour des informations, changement de mot de passe et image de profil.
- Enregistrement et consultation des factures associées à un utilisateur.
- Stockage des données extraites des documents et des informations de facture.
- Statistiques personnelles sur les factures et les montants.
- Fonctions d’administration : gestion des utilisateurs, paramètres système, factures, journaux d’activité et rapports de bugs.
- Réinitialisation du mot de passe par e-mail.
- Export et partage de données depuis l’application mobile, avec prise en charge de PDF et de fichiers Excel/CSV selon les écrans concernés.
- Intégration prévue avec un service OCR externe.

## Technologies

### Application mobile
- Flutter et Dart
- Provider pour la gestion d’état
- HTTP pour les appels à l’API
- Shared Preferences
- Image Picker et gestion des permissions
- Génération et partage de documents avec les bibliothèques PDF, Excel et CSV

### Backend
- Node.js
- Express
- MySQL via `mysql2/promise`
- JWT pour l’authentification
- bcrypt/bcryptjs pour le hachage des mots de passe
- Multer pour la réception de fichiers
- Nodemailer pour les e-mails
- Axios et FormData pour les échanges HTTP

### Données
La sauvegarde SQL du projet contient notamment les tables `users`, `invoices`, `invoice_items`, `invoice_details`, `invoice_taxes`, `scanned_documents`, `extracted_data`, `suppliers`, `activity_logs`, `bug_reports` et `system_settings`.

## Architecture du dépôt

```text
Neivos-Facture/
├── android/              # Configuration Android Flutter
├── assets/               # Images et icônes de l'application
├── lib/                  # Code source Flutter
├── backend_api/
│   ├── server.js         # Serveur Express et routes API
│   ├── db.js             # Pool de connexions MySQL
│   ├── package.json      # Dépendances et scripts Node.js
│   └── uploads/          # Fichiers téléversés (ex. images de profil)
├── pubspec.yaml          # Dépendances Flutter
└── README.md
```

La présence exacte de certains fichiers ou dossiers peut évoluer avec les versions du projet.

## Prérequis

- Flutter SDK compatible avec Dart `>=3.0.0 <4.0.0`
- Android Studio ou un environnement de développement Flutter configuré
- Node.js et npm
- MySQL ou MariaDB pour l’exécution locale
- Accès au service OCR externe si la fonctionnalité OCR est utilisée

## Installation locale

### 1. Récupérer le projet

```bash
git clone https://github.com/WissemAttouf/Neivos-Facture.git
cd Neivos-Facture
```

Le dépôt est privé : un accès GitHub autorisé est nécessaire pour le cloner.

### 2. Configurer le backend

```bash
cd backend_api
npm install
```

Crée un fichier `.env` dans le dossier `backend_api/`. Exemple de structure :

```dotenv
PORT=8086

DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_local_mysql_password
DB_NAME=ocr_scanner_db

JWT_SECRET=replace_with_a_long_random_secret

OCR_API_URL=http://37.60.239.139:8775

EMAIL_USER=your_email@example.com
EMAIL_PASS=your_email_app_password
```

Remplace les valeurs d’exemple par tes propres paramètres. Ne publie jamais ce fichier, les mots de passe, les clés JWT ou les identifiants e-mail. En production, configure ces valeurs dans les variables d’environnement de l’hébergeur et utilise un secret JWT fort.

### 3. Préparer la base de données

1. Crée une base nommée `ocr_scanner_db` dans ton serveur MySQL/MariaDB local.
2. Importe le dump SQL du projet dans cette base depuis phpMyAdmin ou un client MySQL.
3. Vérifie que les tables et les données ont été restaurées avant de lancer le backend.

**Précaution :** réalise une sauvegarde avant toute importation dans une base qui contient déjà des données. Ne commite pas de dump contenant des données personnelles ou des empreintes de mots de passe.

### 4. Démarrer l’API

Depuis le dossier `backend_api/` :

```bash
npm start
```

Le serveur utilise `PORT` si cette variable est définie, sinon le port `8086`.

Pour vérifier que l’API répond, ouvre :

```text
http://localhost:8086/health
```

La route de santé renvoie un JSON indiquant que le serveur est en ligne. Cette vérification ne garantit pas à elle seule que la base MySQL ou le service OCR sont opérationnels.

### 5. Lancer l’application Flutter

Depuis la racine du dépôt :

```bash
flutter pub get
flutter doctor
flutter run
```

Vérifie la configuration des URL de l’API dans le code Flutter avant de lancer l’application. Pour l’émulateur Android, l’accès au backend local utilise généralement `http://10.0.2.2:8086` plutôt que `localhost`. Sur un appareil physique, utilise l’adresse IP locale du PC ou l’URL publique du backend, selon l’environnement.

## Routes API principales

Les routes implémentées comprennent notamment :

| Méthode | Route | Description |
|---|---|---|
| GET | `/health` | Vérifier que le serveur répond |
| POST | `/register` | Créer un compte |
| POST | `/login` | Se connecter |
| POST | `/forgot-password` | Demander une réinitialisation du mot de passe |
| GET | `/profile` | Consulter le profil authentifié |
| PUT | `/profile` | Mettre à jour le profil |
| POST | `/api/invoices/save` | Enregistrer une facture |
| GET | `/api/invoices/user/:userId` | Lister les factures d’un utilisateur autorisé |
| DELETE | `/api/invoices/:invoiceId` | Supprimer une facture selon les droits |
| GET | `/api/user/stats` | Consulter les statistiques de l’utilisateur |
| POST | `/api/bug-reports` | Envoyer un rapport de bug |

Les routes d’administration sont sous le préfixe `/api/admin` et nécessitent une authentification et des droits administrateur. Consulte `backend_api/server.js` pour la liste et les comportements exacts des routes.

Pour les routes protégées, transmets le jeton dans l’en-tête HTTP :

```http
Authorization: Bearer <access_token>
```

## Fichiers téléversés

Le backend utilise le dossier `backend_api/uploads/`, notamment pour les images de profil et les fichiers temporaires. En déploiement cloud, vérifie si le système de fichiers de l’hébergeur est persistant. Si les fichiers doivent survivre aux redémarrages et redéploiements, configure un stockage persistant adapté et une stratégie de sauvegarde.

## Déploiement

Le déploiement cloud est en préparation. Avant de mettre l’application en production :

- confirmer l’offre gratuite et ses limites chez chaque fournisseur ;
- configurer les variables d’environnement sans les inscrire dans Git ;
- activer et vérifier TLS pour la connexion MySQL distante ;
- utiliser un secret JWT robuste et obligatoire ;
- vérifier les règles réseau de la base de données ;
- choisir un stockage persistant pour les fichiers téléversés ;
- confirmer l’accessibilité du service OCR depuis l’hébergeur ;
- mettre à jour les URL de l’API dans Flutter ;
- tester les parcours d’inscription, connexion, factures, profil et administration ;
- sauvegarder et vérifier la base avant toute migration.

## Sécurité et données

- Ne publie jamais `.env`, des mots de passe, des clés privées, des jetons ou des identifiants de services.
- N’ajoute pas `node_modules/`, les fichiers de build ou des données personnelles au dépôt.
- Garde les sauvegardes SQL privées et protège-les comme des données sensibles.
- Ne supprime pas les données locales ni les fichiers d’origine tant que la migration cloud n’a pas été vérifiée.
- Les paramètres de production doivent être fournis par l’environnement d’exécution, pas codés en dur dans le dépôt.

## Licence

Aucune licence open source n’est déclarée dans le dépôt à ce stade. Contacte le propriétaire du projet avant toute réutilisation ou redistribution.
