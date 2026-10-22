/**
 * AIWIZE Labs Loan Management System - Frontend Logic
 * This version uses static demo data reflecting the PostgreSQL schema.
 */

// 1. Demo Data (Simulating DB Records)
const DEMO_APPLICATIONS = [
    { id: 'APP-1001', customer: 'Alice Johnson', amount: 5000, date: '2026-10-15', status: 'Approved', email: 'alice@example.com' },
    { id: 'APP-1002', customer: 'Bob Smith', amount: 12000, date: '2026-10-18', status: 'Pending', email: 'bob@example.com' },
    { id: 'APP-1003', customer: 'Charlie Brown', amount: 2500, date: '2026-10-20', status: 'Rejected', email: 'charlie@example.com' },
    { id: 'APP-1004', customer: 'Diana Prince', amount: 45000, date: '2026-10-21', status: 'Approved', email: 'diana@example.com' },
    { id: 'APP-1005', customer: 'Ethan Hunt', amount: 8000, date: '2026-10-22', status: 'Pending', email: 'ethan@example.com' },
    { id: 'APP-1006', customer: 'Fiona Glenanne', amount: 15000, date: '2026-10-10', status: 'Approved', email: 'fiona@example.com' },
];

// Application State
let state = {
    applications: [...DEMO_APPLICATIONS],
    filters: {
        search: '',
        status: 'all'
    }
};

// 2. DOM Elements
const elements = {
    appBody: document.getElementById('applicationsBody'),
    searchInput: document.getElementById('searchInput'),
    statusFilter: document.getElementById('statusFilter'),
    totalApps: document.getElementById('totalApps'),
    pendingApps: document.getElementById('pendingApps'),
    activeLoans: document.getElementById('activeLoans'),
    totalDisbursed: document.getElementById('totalDisbursed'),
    loadingState: document.getElementById('loadingState'),
    emptyState: document.getElementById('emptyState'),

    // Modal Elements
    openFormBtn: document.getElementById('openFormBtn'),
    closeFormBtn: document.getElementById('closeFormBtn'),
    cancelFormBtn: document.getElementById('cancelFormBtn'),
    formModal: document.getElementById('formModal'),
    loanForm: document.getElementById('loanForm'),
};

// 3. Core Functions

/**
 * Updates the KPI cards based on current application data
 */
function updateKPIs() {
    const total = state.applications.length;
    const pending = state.applications.filter(a => a.status === 'Pending').length;
    const active = state.applications.filter(a => a.status === 'Approved').length;
    const disbursed = state.applications
        .filter(a => a.status === 'Approved')
        .reduce((sum, a) => sum + a.amount, 0);

    elements.totalApps.textContent = total;
    elements.pendingApps.textContent = pending;
    elements.activeLoans.textContent = active;
    elements.totalDisbursed.textContent = new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        maximumFractionDigits: 0
    }).format(disbursed);
}

/**
 * Renders the application table with filtering logic
 */
function renderTable() {
    const { search, status } = state.filters;

    // Show loading state briefly to simulate real API
    elements.appBody.innerHTML = '';
    elements.loadingState.classList.remove('hidden');
    elements.emptyState.classList.add('hidden');

    setTimeout(() => {
        elements.loadingState.classList.add('hidden');

        const filtered = state.applications.filter(app => {
            const matchesSearch = app.customer.toLowerCase().includes(search.toLowerCase()) ||
                                 app.id.toLowerCase().includes(search.toLowerCase());
            const matchesStatus = status === 'all' || app.status === status;
            return matchesSearch && matchesStatus;
        });

        if (filtered.length === 0) {
            elements.emptyState.classList.remove('hidden');
            return;
        }

        filtered.forEach(app => {
            const row = document.createElement('tr');
            const statusClass = `badge-${app.status.toLowerCase()}`;

            row.innerHTML = `
                <td style="font-weight: 500;">${app.customer}<br><small style="color: var(--text-muted)">${app.id}</small></td>
                <td>${new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(app.amount)}</td>
                <td>${app.date}</td>
                <td><span class="badge ${statusClass}">${app.status}</span></td>
                <td><button class="btn btn-secondary" style="padding: 4px 8px; font-size: 0.7rem;">View</button></td>
            `;
            elements.appBody.appendChild(row);
        });
    }, 300);
}

// 4. Form Validation & Handling

function validateForm() {
    let isValid = true;
    const fields = [
        { id: 'customerName', errorId: 'nameError', validation: val => val.trim().length > 0 },
        { id: 'customerEmail', errorId: 'emailError', validation: val => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val) },
        { id: 'loanAmount', errorId: 'amountError', validation: val => parseInt(val) >= 100 },
        { id: 'loanTerm', errorId: 'termError', validation: val => val !== '' },
    ];

    fields.forEach(field => {
        const input = document.getElementById(field.id);
        const error = document.getElementById(field.errorId);
        if (!field.validation(input.value)) {
            input.parentElement.classList.add('invalid');
            isValid = false;
        } else {
            input.parentElement.classList.remove('invalid');
        }
    });

    return isValid;
}

function handleFormSubmit(e) {
    e.preventDefault();
    if (!validateForm()) return;

    const formData = new FormData(elements.loanForm);
    const newApp = {
        id: `APP-${Math.floor(1000 + Math.random() * 9000)}`,
        customer: formData.get('customerName'),
        email: formData.get('customerEmail'),
        amount: parseInt(formData.get('loanAmount')),
        date: new Date().toISOString().split('T')[0],
        status: 'Pending'
    };

    // Add to state
    state.applications.unshift(newApp);

    // UI Feedback
    alert(`Success! Application ${newApp.id} has been submitted for ${newApp.customer}.`);

    // Reset and Close
    elements.loanForm.reset();
    toggleModal(false);

    // Refresh View
    updateKPIs();
    renderTable();
}

// 5. Event Listeners & UI Helpers

function toggleModal(show) {
    if (show) {
        elements.formModal.classList.remove('hidden');
        document.body.style.overflow = 'hidden'; // Prevent scrolling
    } else {
        elements.formModal.classList.add('hidden');
        document.body.style.overflow = 'auto';
        // Clear validation errors on close
        document.querySelectorAll('.form-group').forEach(el => el.classList.remove('invalid'));
    }
}

function init() {
    // Event: Open/Close Modal
    elements.openFormBtn.addEventListener('click', () => toggleModal(true));
    elements.closeFormBtn.addEventListener('click', () => toggleModal(false));
    elements.cancelFormBtn.addEventListener('click', () => toggleModal(false));

    // Event: Filter/Search
    elements.searchInput.addEventListener('input', (e) => {
        state.filters.search = e.target.value;
        renderTable();
    });

    elements.statusFilter.addEventListener('change', (e) => {
        state.filters.status = e.target.value;
        renderTable();
    });

    // Event: Form Submit
    elements.loanForm.addEventListener('submit', handleFormSubmit);

    // Initial Load
    updateKPIs();
    renderTable();
}

// Launch application
document.addEventListener('DOMContentLoaded', init);
