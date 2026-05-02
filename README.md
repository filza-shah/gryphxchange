# GryphXchange 🦅

A full-stack mobile marketplace app built for **University of Guelph students** to buy, sell, and trade items on campus — built with Flutter and Firebase.

---

## Features

- 🔐 **Authentication** — Secure sign up and login with Firebase Auth
- 📋 **Listings** — Browse, search, and filter campus marketplace listings in real time
- ➕ **Create Listings** — Post items for sale or trade with photos and course codes
- ❤️ **Wishlist** — Save and track listings you're interested in
- 📷 **QR Code Trade Verification** — Verify trades in person via QR code scanning
- 👤 **Profile** — View and manage your activity and listings
- 🧭 **Command Center** — Central hub for managing your trades and activity

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| State Management | Riverpod |
| Navigation | go_router |
| Backend | Firebase (Auth, Firestore, Cloud Storage) |
| QR Code | qr_flutter |

---

## Project Structure

```
app/
├── lib/
│   ├── core/
│   │   ├── providers/       # Riverpod providers (auth, listings, workflow)
│   │   ├── router/          # go_router navigation config
│   │   └── widgets/         # Shared UI components (header, nav, cards)
│   ├── features/
│   │   ├── auth/            # Login & Sign Up screens
│   │   ├── home/            # Listings feed with search
│   │   ├── listing/         # Create & view listing details
│   │   ├── wishlist/        # Saved listings
│   │   ├── profile/         # User profile
│   │   └── command/         # Command center / trade management
│   ├── models/              # Data models and Firestore mappers
│   └── services/            # Firebase services and workflow controller
```

---

## Getting Started

### Prerequisites
- Flutter SDK `^3.11.1`
- A Firebase project with Firestore, Auth, and Storage enabled

### Setup

1. Clone the repo
```bash
git clone https://github.com/filza-shah/gryphxchange.git
cd gryphxchange/app
```

2. Install dependencies
```bash
flutter pub get
```

3. Add your Firebase config
```bash
# firebase_options.dart is not included in this repo (contains private keys)
# Run FlutterFire CLI to generate your own:
flutterfire configure
```

4. Run the app
```bash
flutter run
```

---

## Theme

GryphXchange uses the University of Guelph's official colours:
- **Gryph Red** `#8B0000`
- **Gryph Gold** `#FFD700`

---

## Course

This project was built as part of **Mobile Computing** at the **University of Guelph** (2026), developed collaboratively by a team of 5 students.

---

## Author

**Filza Shah**
[filzashah.com](https://filzashah.com) · [LinkedIn](https://linkedin.com/in/filza-shah) · [GitHub](https://github.com/filza-shah)

