# Neivos Facture — Application mobile de traitement de factures

Application mobile développée avec **Flutter et Dart**, connectée à un backend **Node.js/Express** et à une base de données relationnelle. Le projet de fin d’études explore un workflow de traitement de factures assisté par reconnaissance optique de caractères (OCR).

## Présentation

Neivos Facture vise à faciliter la numérisation, l’extraction et l’organisation des informations contenues dans des factures. Le workflow combine l’interface mobile, l’intégration d’une API REST et un service de traitement OCR. Les résultats extraits doivent pouvoir être contrôlés avant d’être utilisés.

## Fonctionnalités du parcours applicatif

- Tableau de bord mobile donnant accès aux principales sections.
- Sélection d’une image depuis la galerie ou capture d’une facture.
- Transmission des documents au workflow de traitement OCR configuré.
- Extraction assistée des données de facture et présentation pour vérification.
- Gestion des enregistrements de factures via le backend.
- Intégration mobile avec une API REST.
- Fonctionnalités liées au profil, aux paramètres et à l’assistance selon les écrans du projet.

Le résultat de l’OCR dépend de la qualité de l’image et de la disponibilité du service de reconnaissance configuré. Vérifiez les données extraites avant toute utilisation comptable.

## Technologies

| Domaine | Technologies |
|---|---|
| Application mobile | Flutter, Dart |
| Backend | Node.js, Express.js |
| Données | MySQL / base relationnelle selon la configuration |
| Communication | API REST |
| Traitement documentaire | OCR |
| Documents | Génération ou export de rapports selon l’implémentation du projet |

## Architecture générale

```text
Neivos-Facture/
├── application Flutter/      # Interface mobile
├── backend/                  # API et logique serveur, selon l’organisation du dépôt
├── docs/
│   └── screenshots/          # Captures d’écran documentées
└── README.md
```

Consultez l’arborescence réelle du dépôt pour repérer les dossiers et fichiers d’entrée de chaque composant.

## Installation et configuration

Les étapes exactes dépendent des versions des SDK et des services configurés dans le dépôt.

### Application Flutter

```bash
flutter pub get
flutter run
```

### Backend Node.js

Si le backend possède son propre fichier `package.json`, ouvrez son dossier, installez les dépendances et lancez le script défini dans ce fichier :

```bash
npm install
npm run
```

Configurez les paramètres de base de données et les URL des services dans les fichiers d’environnement prévus. Ne publiez jamais de secrets, mots de passe ou clés d’API.

## Captures d’écran

Les captures documentées dans `docs/screenshots/` peuvent être consultées directement dans le dépôt GitHub.

## Auteur

**Wissem Attouf** — Ingénieur logiciel | Développeur Full Stack  
Projet de fin d’études réalisé au sein de Neivos Groupe.

[GitHub](https://github.com/WissemAttouf) · [LinkedIn](https://www.linkedin.com/in/wissem-attouf-452509226/) · [Portfolio](https://wissem-portfolio.vercel.app/) · [E-mail](mailto:wattouf35@gmail.com)
