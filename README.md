# GST Billing Invoice App — Full Stack

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.33-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Node.js-Express-green?logo=node.js" />
  <img src="https://img.shields.io/badge/MongoDB-Atlas-brightgreen?logo=mongodb" />
  <img src="https://img.shields.io/badge/GST-Compliant-orange" />
</p>

A **production-ready GST Billing & Invoice Management App** built with Flutter (mobile frontend) and Node.js + MongoDB (backend). Designed for Indian small businesses to create professional, GST-compliant invoices in seconds.

---

## 📱 What is this App?

This is a **complete billing solution** for Indian businesses that need to:
- Create GST-compliant tax invoices (CGST/SGST for intra-state, IGST for inter-state)
- Manage customers (B2B & B2C) and product/service catalogs
- Generate and share PDF invoices via WhatsApp or email
- Track payment status (Paid, Unpaid, Partially Paid)
- Maintain business profile with bank details for invoice footers

---

## 🚀 Features

| Feature | Details |
|---------|---------|
| **GST Auto-Calculation** | Automatically applies CGST+SGST or IGST based on seller vs buyer state |
| **PDF Generation** | Pixel-perfect Indian Tax Invoice PDF with HSN codes, bank details & e-sign |
| **Customer Management** | B2B (GST registered) and B2C (unregistered consumer) support |
| **Product Catalog** | Reusable products & services with HSN/SAC codes |
| **Payment Tracking** | Mark as Paid, Partially Paid; track outstanding balances |
| **Business Profile** | GSTIN, PAN, bank details, UPI ID, invoice prefix settings |
| **Onboarding Flow** | 3-slide onboarding → Login/Register → Dashboard |
| **Offline-first** | Local state with API sync; works even when backend is slow |

---

## 🏗️ App Flow

```
App Launch
    │
    ▼
Splash Screen (1.5s)
    │
    ├──► First Launch? ──► Onboarding (3 slides) ──► Login/Register
    │
    └──► Returning User ──► Login/Register
                                │
                                ├──► Demo Mode (no account needed)
                                │
                                └──► Authenticated
                                          │
                                          ▼
                                ┌─────────────────────────────────┐
                                │         MAIN NAVIGATION          │
                                │  Home │ Invoices │[+]│ Customers │ Products │
                                └─────────────────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
              Dashboard              Invoice List           Customer List
           (Stats & Quick         (Filter by status,      (Search, B2B/B2C
            Actions)               Search, Date range)      filter, GSTIN)
                    │                     │                     │
                    ▼                     ▼                     ▼
           Business Profile         Create Invoice         Add/Edit Customer
          (GSTIN, Bank,             (Select Customer,
           Terms, UPI)               Add Items from         Product Catalog
                                     Catalog, GST           (HSN/SAC, GST
                                     Auto-calc,              Rate, Unit)
                                     PDF Preview)
                                          │
                                          ▼
                                    Invoice Detail
                                   (PDF, Share, Mark
                                    Paid, Payment
                                    History)
```

---

## 🛠️ Tech Stack

### Frontend (Flutter)
```
frontend/
├── lib/
│   ├── core/
│   │   ├── api/          # HTTP client, endpoints
│   │   ├── constants/    # Colors, theme, GST constants
│   │   └── utils/        # GST calculator, currency formatter, PDF generator
│   ├── models/           # Invoice, Customer, Product, Business models
│   ├── providers/        # State management (ChangeNotifier)
│   ├── screens/
│   │   ├── auth/         # Login & Registration
│   │   ├── onboarding/   # 3-slide onboarding
│   │   ├── dashboard/    # Home + main nav
│   │   ├── invoices/     # Create, list, detail, PDF
│   │   ├── customers/    # List, add/edit
│   │   ├── products/     # Catalog, add/edit
│   │   └── business/     # Business profile
│   └── widgets/          # Shared reusable widgets
```

### Backend (Node.js + Express)
```
backend/
├── src/
│   ├── controllers/      # Auth, Invoice, Customer, Product, Business
│   ├── models/           # Mongoose schemas
│   ├── routes/           # REST API routes
│   ├── middleware/        # JWT auth, error handling
│   └── config/           # DB connection, env config
```

### Database
- **MongoDB Atlas** — Cloud-hosted, fully managed

---

## ⚙️ Setup & Installation

### Prerequisites
- Flutter SDK ≥ 3.10
- Node.js ≥ 18
- MongoDB Atlas account (free tier works)

### 1. Clone the repo
```bash
git clone https://github.com/karthik7133/Billing_invoice.git
cd Billing_invoice
```

### 2. Backend Setup
```bash
cd backend
npm install
```

Create a `.env` file in `backend/`:
```env
PORT=5000
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/gst_billing
JWT_SECRET=your_super_secret_jwt_key_here
JWT_EXPIRE=7d
NODE_ENV=development
```

> **Important:** Whitelist your IP in MongoDB Atlas → Network Access → Add IP Address

Start the backend:
```bash
npm run dev
```

### 3. Frontend Setup
```bash
cd frontend
flutter pub get
```

Update the API base URL in `frontend/lib/core/api/api_client.dart`:
```dart
static const String baseUrl = 'http://<your-local-ip>:5000/api';
// Use your machine's local IP (e.g. 192.168.1.10), NOT localhost,
// so the Android device can reach the backend on the same network.
```

Run the app:
```bash
flutter run
```

---

## 📋 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new business |
| POST | `/api/auth/login` | Login |
| GET | `/api/business` | Get business profile |
| PUT | `/api/business` | Update business profile |
| GET | `/api/customers` | List all customers |
| POST | `/api/customers` | Add customer |
| PUT | `/api/customers/:id` | Update customer |
| DELETE | `/api/customers/:id` | Delete customer |
| GET | `/api/products` | List products/services |
| POST | `/api/products` | Add product |
| GET | `/api/invoices` | List invoices |
| POST | `/api/invoices` | Create invoice |
| GET | `/api/invoices/:id` | Get invoice detail |
| POST | `/api/invoices/:id/mark-paid` | Mark as paid |
| DELETE | `/api/invoices/:id` | Delete invoice |

---

## 📄 GST Calculation Logic

```
Intra-State (Same state seller & buyer):
  CGST = taxableAmount × (gstRate / 2) / 100
  SGST = taxableAmount × (gstRate / 2) / 100

Inter-State (Different states):
  IGST = taxableAmount × gstRate / 100

Grand Total = Σ(taxableAmount + totalTax) + otherCharges - extraDiscount + roundOff
```

---

## 🔐 Environment Variables

| Variable | Description |
|----------|-------------|
| `MONGODB_URI` | MongoDB Atlas connection string |
| `JWT_SECRET` | Secret key for JWT signing |
| `JWT_EXPIRE` | Token expiry (e.g. `7d`) |
| `PORT` | Server port (default: 5000) |

---

## 📦 Dependencies

### Flutter
- `provider` — State management
- `pdf` + `printing` — PDF generation & sharing
- `shared_preferences` — Local storage
- `http` — API client
- `uuid` — Unique ID generation
- `intl` — Date & number formatting

### Node.js
- `express` — Web framework
- `mongoose` — MongoDB ODM
- `jsonwebtoken` — JWT auth
- `bcryptjs` — Password hashing
- `cors` — CORS handling
- `dotenv` — Environment config

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

---

## 📝 License

MIT License — feel free to use this for your own business or client projects.
