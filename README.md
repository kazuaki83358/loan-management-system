# AIWIZE Labs Loan Management System - Frontend

Welcome to the frontend prototype of the Loan Management System. This phase focuses on the User Interface (UI) and User Experience (UX) using standard web technologies.

## 🚀 How to Run the Project

Since this project uses vanilla HTML, CSS, and JavaScript, you do not need a complex build process.

### Option 1: Direct Open (Simplest)
1. Navigate to the project folder: `C:\Users\pc\Desktop\Important\My Project\loan-management-system`
2. Double-click `index.html` to open it in your default web browser.

### Option 2: Using a Local Server (Recommended)
If you have VS Code installed, use the **Live Server** extension:
1. Right-click `index.html`.
2. Select **"Open with Live Server"**.
3. The project will run at `http://127.0.0.1:5500`.

## 🛠️ Technical Overview

### Architecture
- **HTML5**: Semantic structure for accessibility and SEO.
- **CSS3**: Custom properties (variables) for theming and CSS Grid/Flexbox for a responsive layout.
- **Vanilla JavaScript**: State-driven rendering logic to manage the table and KPI cards.

### Key Features
- **Responsive Dashboard**: Adapts from desktop to mobile.
- **Real-time Filtering**: Filter applications by status or search for customers instantly.
- **Form Validation**: Client-side validation to ensure data integrity before submission.
- **KPI Tracking**: Automatic calculation of totals based on the current data set.

## ⚠️ Current Limitations
- **Static Data**: The application uses a local JavaScript array (`DEMO_APPLICATIONS`) instead of a live database.
- **Persistence**: New applications added via the form will disappear if you refresh the page.
- **No Backend**: No actual emails are sent or database records created.

*The next phase will implement a Node.js/Express backend to connect this frontend to the PostgreSQL database.*
