# Neivos Facture — Application mobile de traitement de factures

**Neivos Facture** est une application mobile développée avec **Flutter et Dart**, connectée à un backend **Node.js / Express.js** et à une base de données relationnelle. Le projet de fin d’études explore un workflow de traitement de factures assisté par reconnaissance optique de caractères (**OCR**).

## Sommaire

- [Présentation](#présentation)
- [Fonctionnalités](#fonctionnalités)
- [Captures d’écran](#captures-décran)
  - [Authentification et accueil](#1-authentification-et-accueil)
  - [OCR et extraction des données](#2-ocr-et-extraction-des-données)
  - [Documents et exports](#3-documents-et-exports)
  - [Profil et paramètres](#4-profil-et-paramètres)
  - [Assistance](#5-assistance)
- [Technologies](#technologies)
- [Architecture générale](#architecture-générale)
- [Installation et configuration](#installation-et-configuration)
- [Auteur](#auteur)

## Présentation

Neivos Facture vise à faciliter la numérisation, l’extraction et l’organisation des informations contenues dans des factures. L’application mobile communique avec une API REST et s’appuie sur un workflow OCR pour aider à récupérer les informations présentes dans les documents.

Les informations extraites doivent être vérifiées avant toute utilisation comptable. La qualité du résultat dépend notamment de la lisibilité de la facture et de la disponibilité du service OCR configuré.

## Fonctionnalités

- Création de compte et authentification.
- Tableau de bord et navigation entre les fonctionnalités.
- Sélection ou traitement d’images de factures.
- Reconnaissance optique de caractères (OCR) et extraction assistée des données.
- Consultation et organisation des documents.
- Présentation des résultats d’extraction pour vérification.
- Export ou génération de documents PDF et Excel, selon les fonctionnalités implémentées.
- Gestion du profil et des paramètres.
- Accès à l’assistance et à la messagerie.

### 1. Authentification et accueil

<p align="center">
  <img src="docs/images/auth.png" alt="Écran d’authentification de Neivos Facture" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/inscriiit.png" alt="Écran d’inscription de Neivos Facture" width="260">
</p>
<p align="center">
  <img src="docs/images/home.png" alt="Accueil et tableau de bord de Neivos Facture" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/home2.png" alt="Deuxième aperçu de l’accueil de Neivos Facture" width="260">
</p>

### 2. OCR et extraction des données

Cette section présente les écrans associés à la reconnaissance des factures et à la consultation des données extraites.

<p align="center">
  <img src="docs/images/ocr.png" alt="Écran OCR de Neivos Facture" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/pdfocr.png" alt="Traitement OCR d’un document PDF" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/extractdonee.png" alt="Résultat d’extraction des données d’une facture" width="260">
</p>
<p align="center">
  <img src="docs/images/extractdonee1.png" alt="Détails complémentaires des données extraites" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/extractdonee2.png" alt="Autre écran de résultat d’extraction" width="260">
</p>

### 3. Documents et exports

<p align="center">
  <img src="docs/images/document.png" alt="Espace de gestion des documents" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/excel.png" alt="Export ou aperçu Excel" width="260">
</p>

### 4. Profil et paramètres

<p align="center">
  <img src="docs/images/profil.png" alt="Profil utilisateur" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/parametre.png" alt="Paramètres de l’application" width="260">
</p>
<p align="center">
  <img src="docs/images/para2.png" alt="Options supplémentaires des paramètres" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/para3.png" alt="Autre écran des paramètres" width="260">
</p>

### 5. Assistance

<p align="center">
  <img src="docs/images/chat.png" alt="Interface de discussion ou de messagerie" width="260">
  &nbsp;&nbsp;
  <img src="docs/images/help.png" alt="Écran d’aide et d’assistance" width="260">
</p>

## Technologies

| Domaine | Technologies |
|---|---|
| Application mobile | Flutter, Dart |
| Backend | Node.js, Express.js |
| Base de données | MySQL / base relationnelle selon la configuration |
| Communication | API REST |
| Traitement documentaire | OCR |
| Exports | PDF, Excel, selon l’implémentation du projet |

## Architecture générale

```text
Neivos-Facture/
├── application Flutter/   # Interface mobile
├── backend/               # API et logique serveur
├── docs/
│   └── images/            # Captures d’écran présentées dans ce README
└── README.md
```

Cette représentation est indicative : consultez l’arborescence du dépôt pour connaître les chemins exacts des composants.

## Installation et configuration

Les commandes suivantes sont à adapter aux dossiers et scripts réellement présents dans le dépôt.

### Application Flutter

```bash
flutter pub get
flutter run
```

### Backend Node.js

Depuis le dossier du backend qui contient le fichier `package.json` :

```bash
npm install
npm run
```

La commande `npm run` affiche les scripts disponibles. Lancez ensuite le script de démarrage défini dans le projet.

Configurez les paramètres de base de données et les URL des services dans les fichiers d’environnement prévus. **Ne publiez jamais de mots de passe, clés d’API ou autres secrets.**

## Auteur

**Wissem Attouf** — Software Engineer | Full-Stack Developer

Projet de fin d’études réalisé au sein de **Neivos Groupe**.

- [GitHub](https://github.com/WissemAttouf)
- [LinkedIn](https://www.linkedin.com/in/wissem-attouf-452509226/)
- [Portfolio](https://wissem-portfolio.vercel.app/)
- [E-mail](mailto:wattouf35@gmail.com)

---

## Captures d’écran

Les images ci-dessous sont organisées par parcours fonctionnel. Elles sont stockées dans le dossier [`docs/images/`](docs/images/).
