# 🛡️ Redactify – Offline PII Detection & Redaction App

Redactify is a fully offline, AI-powered Flutter app that empowers users—especially those from low-digital-literacy or rural backgrounds—to **detect and redact Personally Identifiable Information (PII)** from documents like PDFs, images, and text files. The app ensures data privacy while providing a beautifully interactive and intuitive UI.

---

## 📌 Submission Theme

**AI for Safer, Smarter & Inclusive Bharat 🇮🇳**

---

## 🧠 Problem Statement

India's digital transformation has made data sharing common, but many citizens—especially in rural or semi-literate communities—unknowingly upload sensitive documents (like Aadhaar, phone numbers, bank info) without redaction.

> 🔒 There's a lack of tools that work **offline, in Indian languages**, and are simple enough for **first-time smartphone users**.

---

## ✅ Our Solution

Redactify is an offline PII Detection & Redaction mobile app that allows users to:

- 📁 **Upload** PDFs, images, or text
- 🔍 **Detect** PII using OCR + AI (Aadhaar, phone numbers, passport, etc.)
- 🧹 **Choose** what to redact
- ✨ **Redact** the content with one click
- 📤 **Download or share** the sanitized file
- 🧾 **View audit logs** of redactions

Built using:
- 🧠 **ONNX-based AI models** (for NER)
- 🔤 **Tesseract OCR** (with Hindi/Marathi support)
- 🧪 **Regex/NLP** for contextual analysis
- 📡 **Fully offline-first architecture**

---

## 🎯 Key Features

| Feature | Description |
|--------|-------------|
| 🗂️ Multi-format Upload | Supports PDFs, images (JPG, PNG), and plain text |
| 🔍 AI-Powered PII Detection | Aadhaar, Phone, Email, Address, Passport, PAN, etc. |
| 📡 Offline Functionality | No internet required — full redaction on-device |
| 🗣️ Voice Input | For low-literacy users to trigger actions |
| 📦 Batch Redaction | Redact multiple files in one session |
| 🌐 Indian Language OCR | Hindi and Marathi supported |
| 📄 Redaction Audit Log | Maintains local log of all redacted entries |
| 💅 Modern UI | Glassmorphism, Lottie animations, particle background |

---

## 📱 Screenshots

![Splash](assets/screenshots/splash.png)
![Home](assets/screenshots/home.png)
![File Preview](assets/screenshots/preview.png)
![Redaction Result](assets/screenshots/result.png)

---

## ⚙️ Tech Stack

| Layer | Tech |
|------|------|
| Frontend | Flutter (with Riverpod & Glassmorphism) |
| AI Models | ONNX (NER), Regex, BERT (Optional) |
| OCR | Tesseract OCR with Hindi/Marathi trained data |
| Animations | Lottie, Rive, Confetti |
| Offline DB | SQLite for audit logs |
| File Handling | PDF Render, File Picker, Storage APIs |
| Speech | `speech_to_text` for voice interactions |

---

## 🔧 How to Run Locally

1. **Clone the Repo**

```bash
git clone https://github.com/your-username/redactify.git
cd redactify
