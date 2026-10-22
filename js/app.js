// The UI can be opened through Express, Live Server, or from disk. The API
// always lives on the Express server so those entry points share one contract.
const API_BASE_URL = window.location.protocol.startsWith('http') && window.location.port === '3000' ? '/api' : 'http://localhost:3000/api';
const state = { applications: [], branches: [], currentStep: 1 };
const $ = id => document.getElementById(id);
const money = value => new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(Number(value || 0));
const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
async function api(path, options) { const response = await fetch(`${API_BASE_URL}${path}`, options); const data = await response.json().catch(() => ({})); if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`); return data; }
function showError(error) { console.error(error); alert(`Error: ${error.message}`); }
function renderRows(target, applications) { target.innerHTML = applications.map(application => `<tr><td><strong>${escapeHtml(application.customer)}</strong><br><small>ID: ${application.id}</small></td><td>${money(application.amount)}</td><td>${new Date(application.date).toLocaleDateString()}</td><td><span class="badge badge-${String(application.status).toLowerCase()}">${escapeHtml(application.status)}</span></td><td><button type="button" class="btn btn-secondary view-app" data-id="${application.id}">View</button></td></tr>`).join('') || '<tr><td colspan="5" class="state-message">No applications found.</td></tr>'; }
async function refreshDashboard() { const data = await api('/dashboard'); $('totalApps').textContent = data.totalApplications; $('pendingApps').textContent = data.pendingApplications; $('activeLoans').textContent = data.activeLoans; $('totalDisbursed').textContent = money(data.totalDisbursed); }
async function refreshApplications() { state.applications = await api('/applications'); renderDashboardRows(); renderApplications(); }
function matchesApplication(application, search, status) { return (application.customer.toLowerCase().includes(search.toLowerCase()) || String(application.id).includes(search)) && (status === 'all' || application.status === status); }
function renderDashboardRows() { renderRows($('applicationsBody'), state.applications.filter(application => matchesApplication(application, $('searchInput').value, $('statusFilter').value)).slice(0, 5)); }
function renderApplications() { renderRows($('allApplicationsBody'), state.applications.filter(application => matchesApplication(application, $('appSearch').value, $('appStatus').value))); }
function renderBranches() { $('branchesBody').innerHTML = state.branches.map(branch => `<tr><td>${escapeHtml(branch.branch_name)}</td><td>${escapeHtml(branch.city)}</td><td>Branch #${branch.branch_id}</td></tr>`).join('') || '<tr><td colspan="3">No branches found.</td></tr>'; }
function renderCustomers(customers) { $('customersBody').innerHTML = customers.map(customer => `<tr><td><strong>${escapeHtml(customer.name)}</strong></td><td>${escapeHtml(customer.email || '-')}</td><td>${escapeHtml(customer.phone || '-')}</td><td><code>${escapeHtml(customer.pan || '-')}</code></td><td>${escapeHtml(customer.credit_score ?? '-')}</td><td>${escapeHtml(customer.address || '-')}</td><td>${customer.application_count}</td></tr>`).join('') || '<tr><td colspan="7">No customers found.</td></tr>'; }
function setView(view) { document.querySelectorAll('.view').forEach(element => element.classList.toggle('hidden', element.id !== `${view}View`)); document.querySelectorAll('.sidebar-nav a').forEach(link => link.parentElement.classList.toggle('active', link.dataset.view === view)); if (view === 'customers') api('/customers').then(renderCustomers).catch(showError); if (view === 'branches') renderBranches(); }
function openDetail(id) { const application = state.applications.find(item => item.id === Number(id)); if (!application) return; $('detailContent').innerHTML = `<dl><dt>Application</dt><dd>#${application.id}</dd><dt>Customer</dt><dd>${escapeHtml(application.customer)}</dd><dt>PAN</dt><dd>${escapeHtml(application.pan || '-')}</dd><dt>Credit Score</dt><dd>${escapeHtml(application.credit_score ?? '-')}</dd><dt>Email</dt><dd>${escapeHtml(application.email || '-')}</dd><dt>Phone</dt><dd>${escapeHtml(application.phone || '-')}</dd><dt>Amount</dt><dd>${money(application.amount)}</dd><dt>Term</dt><dd>${application.tenure || '-'} months</dd><dt>Type</dt><dd>${escapeHtml(application.type || '-')}</dd><dt>Purpose</dt><dd>${escapeHtml(application.purpose || '-')}</dd><dt>Branch</dt><dd>${escapeHtml(application.branch || '-')} (${escapeHtml(application.city || '')})</dd><dt>Status</dt><dd>${escapeHtml(application.status)}</dd></dl>`; $('detailModal').classList.remove('hidden'); }
function validateStep(step) {
  let valid = true;
  document.querySelectorAll(`#step${step} [required]`).forEach(input => {
    const invalid = !input.value.trim() || (input.type === 'number' && Number(input.value) < Number(input.min || 0));
    input.parentElement.classList.toggle('invalid', invalid);
    valid &&= !invalid;
  });
  if (step === 1) {
    const panEl = $('panNumber');
    if (panEl && panEl.value.trim()) {
      const invalidPan = !/^[A-Za-z]{5}[0-9]{4}[A-Za-z]{1}$/.test(panEl.value.trim());
      panEl.parentElement.classList.toggle('invalid', invalidPan);
      valid &&= !invalidPan;
    } else if (panEl) {
      panEl.parentElement.classList.remove('invalid');
    }
    const scoreEl = $('creditScore');
    if (scoreEl && scoreEl.value.trim()) {
      const score = Number(scoreEl.value);
      const invalidScore = !Number.isInteger(score) || score < 300 || score > 900;
      scoreEl.parentElement.classList.toggle('invalid', invalidScore);
      valid &&= !invalidScore;
    } else if (scoreEl) {
      scoreEl.parentElement.classList.remove('invalid');
    }
  }
  return valid;
}
function updateStepper() { document.querySelectorAll('.form-step').forEach((step, index) => step.classList.toggle('hidden', index + 1 !== state.currentStep)); document.querySelectorAll('.step-indicator').forEach((indicator, index) => indicator.classList.toggle('active', index + 1 <= state.currentStep)); }
function populateReview() { const data = Object.fromEntries(new FormData($('loanForm'))); const mapping = { Name: 'customerName', Email: 'customerEmail', Phone: 'customerPhone', DOB: 'customerDOB', PAN: 'panNumber', CreditScore: 'creditScore', Address: 'residentialAddress', Employment: 'employmentType', Employer: 'employerName', Income: 'monthlyIncome', Experience: 'yearsExperience', EMI: 'existingEMI', Type: 'loanType', Amount: 'loanAmount', Tenure: 'loanTenure', Purpose: 'loanPurpose', Branch: 'branchSelection' }; Object.entries(mapping).forEach(([label, key]) => { $(`rev${label}`).textContent = data[key] ? (key === 'panNumber' ? data[key].toUpperCase() : data[key]) : '-'; }); const branch = state.branches.find(item => item.branch_id === Number(data.branchSelection)); if (branch) $('revBranch').textContent = `${branch.branch_name} (${branch.city})`; }
async function submitForm(event) { event.preventDefault(); if (!validateStep(4)) return; const raw = Object.fromEntries(new FormData($('loanForm'))); const payload = { customerName: raw.customerName, customerEmail: raw.customerEmail, customerPhone: raw.customerPhone, customerDOB: raw.customerDOB, panNumber: raw.panNumber && raw.panNumber.trim() ? raw.panNumber.trim().toUpperCase() : null, creditScore: raw.creditScore && raw.creditScore.trim() ? Number(raw.creditScore) : null, residentialAddress: raw.residentialAddress, employmentType: raw.employmentType, employerName: raw.employerName, monthlyIncome: Number(raw.monthlyIncome), yearsExperience: Number(raw.yearsExperience), existingEMI: Number(raw.existingEMI), loanType: raw.loanType, loanAmount: Number(raw.loanAmount), loanTenure: Number(raw.loanTenure), loanPurpose: raw.loanPurpose, branchSelection: Number(raw.branchSelection) }; const result = await api('/applications', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) }); alert(`Success! Application ${result.applicationId} has been submitted.`); $('loanForm').reset(); $('formModal').classList.add('hidden'); state.currentStep = 1; updateStepper(); await Promise.all([refreshDashboard(), refreshApplications()]); }
function applyTheme() { const dark = localStorage.getItem('aiwize-theme') === 'dark'; document.body.classList.toggle('dark-theme', dark); $('themeToggle').checked = dark; }
async function init() { const views = ['dashboard', 'applications', 'customers', 'branches', 'settings']; document.querySelectorAll('.sidebar-nav a').forEach((link, index) => { link.dataset.view = views[index]; link.onclick = event => { event.preventDefault(); setView(link.dataset.view); }; }); state.branches = await api('/branches'); $('branchSelection').innerHTML = '<option value="">Select branch</option>' + state.branches.map(branch => `<option value="${branch.branch_id}">${escapeHtml(branch.branch_name)} (${escapeHtml(branch.city)})</option>`).join(''); renderBranches(); await Promise.all([refreshDashboard(), refreshApplications()]); applyTheme(); $('openFormBtn').onclick = () => $('formModal').classList.remove('hidden'); $('closeFormBtn').onclick = () => $('formModal').classList.add('hidden'); $('closeDetailBtn').onclick = () => $('detailModal').classList.add('hidden'); document.querySelectorAll('.next-step').forEach(button => button.onclick = () => { if (validateStep(state.currentStep)) { state.currentStep++; if (state.currentStep === 4) populateReview(); updateStepper(); } }); document.querySelectorAll('.prev-step').forEach(button => button.onclick = () => { state.currentStep--; updateStepper(); }); $('loanForm').addEventListener('submit', event => submitForm(event).catch(showError)); $('appSearch').oninput = renderApplications; $('appStatus').onchange = renderApplications; $('searchInput').oninput = renderDashboardRows; $('statusFilter').onchange = renderDashboardRows; document.addEventListener('click', event => { if (event.target.matches('.view-app')) openDetail(event.target.dataset.id); }); $('themeToggle').onchange = event => { localStorage.setItem('aiwize-theme', event.target.checked ? 'dark' : 'light'); applyTheme(); }; }
document.addEventListener('DOMContentLoaded', () => init().catch(showError));
