# DevCase Notification Backend (Phase 1)

Backend foundation for DevCase Notification System using Node.js, Express, and PostgreSQL.

## Prerequisites
- Node.js (v18+)
- PostgreSQL installed and running

## 1. Installation
Navigate to the `backend` directory and install dependencies:
```bash
cd backend
npm install
```

## 2. Configuration
Copy `.env.example` to `.env` and update your database credentials:
```bash
cp .env.example .env
```

## 3. Database Setup
Create a PostgreSQL database (e.g. `devcase_db`), then run migrations:
```bash
npm run migrate
```

## 4. Running the Server
Development mode (with auto-reload):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

## 5. Testing Health Check API
Open Postman and send a `GET` request to:
```
http://localhost:3000/api/health
```
Expected response:
```json
{
  "success": true,
  "status": "UP",
  "timestamp": "2026-11-06T...",
  "database": {
    "status": "healthy",
    "timestamp": "..."
  }
}
```
