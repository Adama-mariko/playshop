# PlayShop — Application de vente en ligne

## Structure du projet

```
playshop/
├── backend/     AdonisJS v5 + TypeScript + MySQL
├── frontend/    Vue.js 3 + TypeScript + Vite
└── mobile/      Flutter + Dart + Riverpod
```

---

## 1. Backend (AdonisJS)

### Configuration

1. Créer la base de données MySQL :
```sql
CREATE DATABASE playshop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. Configurer le fichier `backend/.env` :
```env
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=votre_mot_de_passe
MYSQL_DB_NAME=playshop
APP_KEY=une-clé-secrète-longue-et-aléatoire
```

3. Lancer les migrations :
```bash
cd backend
node ace migration:run
```

4. Démarrer le serveur :
```bash
node ace serve --watch
```

Le serveur tourne sur **http://localhost:3333**

---

## 2. Frontend (Vue.js)

```bash
cd frontend
npm install
npm run dev
```

Accessible sur **http://localhost:5173**

---

## 3. Mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

> Pour Android : l'URL de l'API est `http://10.0.2.2:3333/api`  
> Pour iOS : modifier en `http://localhost:3333/api` dans `lib/core/api/api_client.dart`

---

## API — Endpoints (Postman)

### Authentification
| Méthode | Route | Description |
|---------|-------|-------------|
| POST | /api/auth/register | Inscription |
| POST | /api/auth/login | Connexion → retourne un token |
| POST | /api/auth/logout | Déconnexion (auth requis) |
| GET | /api/auth/me | Profil connecté (auth requis) |

### Produits
| Méthode | Route | Description |
|---------|-------|-------------|
| GET | /api/products | Liste des produits |
| GET | /api/products/:id | Détail d'un produit |
| POST | /api/products | Créer un produit (admin) |
| PUT | /api/products/:id | Modifier un produit (admin) |
| DELETE | /api/products/:id | Supprimer un produit (admin) |

### Commandes
| Méthode | Route | Description |
|---------|-------|-------------|
| GET | /api/orders | Mes commandes (auth) |
| GET | /api/orders/:id | Détail commande (auth) |
| POST | /api/orders | Créer une commande (auth) |
| PATCH | /api/orders/:id/cancel | Annuler une commande (auth) |

### Paiements
| Méthode | Route | Description |
|---------|-------|-------------|
| POST | /api/payments/initiate | Initier un paiement (auth) |
| POST | /api/payments/callback | Webhook Orange Money / Wave |
| GET | /api/payments/status/:orderId | Statut du paiement (auth) |

### Authentification dans Postman
Après le login, copier le token et l'ajouter dans :
`Authorization → Bearer Token → coller le token`

---

## Paiement (Orange Money / Wave)

Le contrôleur `PaymentsController` contient une simulation.  
Pour la production, intégrer :
- **Orange Money** : https://developer.orange.com/apis/om-webpay
- **Wave** : https://docs.wave.com/
