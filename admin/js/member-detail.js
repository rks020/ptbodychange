import { supabaseClient } from './supabase-config.js';
import { showToast, formatDate } from './utils.js';
import { checkConflicts } from './modules/classes.js';
import { setupClassDetailModal, openClassDetailModal, setUpdateCallback } from './modules/class-details.js';

let memberId = null;
let profile = null;
let charts = {}; // Store Chart instances

document.addEventListener('DOMContentLoaded', async () => {
    // Get Member ID from URL
    const urlParams = new URLSearchParams(window.location.search);
    memberId = urlParams.get('id');

    if (!memberId) {
        showToast('Üye ID bulunamadı', 'error');
        setTimeout(() => window.location.href = 'dashboard.html#members', 2000);
        return;
    }

    // Initialize
    await loadCurrentUserProfile();
    await loadMemberDetails();

    // Globals for HTML access
    window.showSection = showSection;
    window.openScheduleModal = openScheduleModal;
    window.openMeasurementModal = openMeasurementModal;
    window.openClassDetailModal = openClassDetailModal; // Shared Modal

    // Setup Modals
    setupScheduleModal();
    setupMeasurementModal();

    // Setup Shared Class Detail Modal
    setupClassDetailModal();
    setUpdateCallback(() => {
        loadHistory(); // Refresh history list on update/delete
    });
});

async function loadCurrentUserProfile() {
    const { data: { user } } = await supabaseClient.auth.getUser();
    if (user) {
        const { data } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single();
        profile = data;
    }
}

async function loadMemberDetails() {
    try {
        const { data: member, error } = await supabaseClient
            .from('members')
            .select('*')
            .eq('id', memberId)
            .single();

        if (error) throw error;

        document.getElementById('member-name').textContent = member.name;
        document.getElementById('member-email').textContent = member.email || 'Email yok';

    } catch (error) {
        console.error('Error loading member:', error);
        showToast('Üye bilgileri yüklenemedi', 'error');
    }
}

// --- Navigation ---
function showSection(sectionId) {
    // Hide all
    document.querySelectorAll('.detail-section').forEach(el => el.style.display = 'none');

    // Show selected
    const target = document.getElementById(`section-${sectionId}`);
    if (target) {
        target.style.display = 'block';

        // Load data on demand
        if (sectionId === 'history') loadHistory();
        if (sectionId === 'measurements') loadMeasurements();
        if (sectionId === 'charts') loadCharts();
    }
}

// --- History Logic ---
async function loadHistory() {
    const container = document.getElementById('history-list');
    container.innerHTML = 'Yükleniyor...';

    try {
        // CORRECT QUERY: Fetch from class_enrollments, join class_sessions
        // Sorting by nested column might differ in syntax, fetching simple first
        // If Supabase API supports nested order: .order('class_sessions(start_time)', { ascending: false })

        const { data, error } = await supabaseClient
            .from('class_enrollments')
            .select(`
                id,
                status,
                session:class_sessions!inner (
                    id,
                    title,
                    start_time,
                    end_time,
                    status,
                    trainer:trainer_id (first_name, last_name)
                )
            `)
            .eq('member_id', memberId)
            .order('created_at', { ascending: false }) // Fallback sort by creation if nested sort fails
            .limit(20);

        if (error) throw error;

        if (!data || data.length === 0) {
            container.innerHTML = '<p style="color:#888;">Henüz kayıtlı ders yok.</p>';
            return;
        }

        // Sort manually by start_time just in case created_at isn't perfect order
        data.sort((a, b) => new Date(b.session.start_time) - new Date(a.session.start_time));

        container.innerHTML = data.map(enrollment => {
            const session = enrollment.session;
            const date = new Date(session.start_time).toLocaleDateString('tr-TR');
            const time = new Date(session.start_time).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });

            // Status: Enrollment status or Session status? usually session status implies completion
            // But enrollment has its own status too (booked, cancelled).
            // Let's use session status primarily.
            const statusColor = session.status === 'completed' ? '#10B981' :
                session.status === 'cancelled' ? '#EF4444' : '#F59E0B';
            const statusText = session.status === 'completed' ? 'Tamamlandı' :
                session.status === 'cancelled' ? 'İptal' : 'Planlandı';

            let trainerName = '-';
            if (session.trainer) {
                trainerName = session.trainer.first_name || '';
            }

            return `
                <div onclick="openClassDetailModal('${session.id}')" style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 12px; margin-bottom: 10px; display:flex; justify-content:space-between; align-items:center; cursor: pointer; transition: background 0.2s;">
                    <div>
                        <div style="font-weight:600; font-size:15px; color:#fff;">${session.title || 'Ders'}</div>
                        <div style="font-size:13px; color:#888;">${date} • ${time}</div>
                        <div style="font-size:12px; color:#666;">Eğitmen: ${trainerName}</div>
                    </div>
                    <div>
                        <span style="background: ${statusColor}20; color: ${statusColor}; padding: 4px 8px; border-radius: 6px; font-size: 12px;">
                            ${statusText}
                        </span>
                    </div>
                </div>
            `;
        }).join('');

    } catch (error) {
        console.error('History Load Error:', error);
        container.innerHTML = `<div style="color: #ff6b6b; padding: 10px; background: rgba(255,0,0,0.1); border-radius: 8px;">
            Hata oluştu: ${error.message || 'Veriler yüklenemedi'}
        </div>`;
    }
}

// --- Recurring Schedule Logic ---
function setupScheduleModal() {
    const modal = document.getElementById('schedule-modal');
    if (!modal) return;

    const close = document.getElementById('close-schedule-modal');
    if (close) close.onclick = () => modal.classList.remove('active');

    const form = document.getElementById('schedule-form');
    // Scope search to the modal to avoid conflicts
    const dayCheckboxes = modal.querySelectorAll('input[name="days"]');
    const timesContainer = document.getElementById('day-times-container');

    if (!timesContainer || dayCheckboxes.length === 0) return;

    // Listen for day changes
    dayCheckboxes.forEach(cb => {
        cb.addEventListener('change', updateTimeInputs);
    });

    function updateTimeInputs() {
        // Use Array.from to ensure we can filter/sort
        const selected = Array.from(dayCheckboxes)
            .filter(cb => cb.checked)
            .sort((a, b) => {
                const valA = parseInt(a.value) || 0;
                const valB = parseInt(b.value) || 0;
                // Monday=1...Sunday=7 logic handled by value (1..7) or (0=Sunday)?
                // Assuming values 1-7 (Mon-Sun) based on HTML
                return valA - valB;
            });

        if (selected.length === 0) {
            timesContainer.innerHTML = '<div style="color: #666; font-size: 13px; font-style: italic;">Lütfen yukarıdan gün seçiniz.</div>';
            return;
        }

        // Save existing values to prevent data loss when checking new days
        const existingValues = {};
        const inputs = timesContainer.querySelectorAll('.day-time-input');
        inputs.forEach(input => {
            existingValues[input.dataset.day] = input.value;
        });

        timesContainer.innerHTML = '';

        selected.forEach(cb => {
            const dayVal = cb.value;
            // Safer sibling text retrieval
            const span = cb.nextElementSibling;
            const dayName = span ? span.textContent.trim() : 'Gün ' + dayVal;

            const savedTime = existingValues[dayVal] || '10:00';

            const row = document.createElement('div');
            // Inline styles for reliability
            row.style.cssText = 'display: flex; align-items: center; justify-content: space-between; background: rgba(255,255,255,0.05); padding: 8px 12px; border-radius: 8px; margin-bottom: 6px;';

            row.innerHTML = `
                <span style="color: #fff; font-weight: 500;">${dayName}</span>
                <input type="time" class="day-time-input" data-day="${dayVal}" value="${savedTime}" required 
                    style="background: #2C2C2E; border: 1px solid rgba(255,255,255,0.1); color: white; padding: 6px; border-radius: 6px;">
            `;
            timesContainer.appendChild(row);
        });
    }

    form.onsubmit = async (e) => {
        e.preventDefault();
        const btn = e.target.querySelector('button');

        // 4. Helper for final creation
        const executeCreation = async (candidatesToCreate, limitReached = false) => {
            btn.disabled = true; btn.textContent = 'Oluşturuluyor...';
            try {
                let createdCount = 0;
                for (const cand of candidatesToCreate) {
                    const { data: sessionData, error: sessionError } = await supabaseClient
                        .from('class_sessions')
                        .insert({
                            trainer_id: cand.trainerId || (profile ? profile.id : (await supabaseClient.auth.getUser()).data.user.id),
                            title: 'Bireysel Ders',
                            start_time: cand.start.toISOString(),
                            end_time: cand.end.toISOString(),
                            description: document.getElementById('schedule-notes').value,
                            status: 'scheduled'
                        })
                        .select()
                        .single();

                    if (sessionError) throw sessionError;

                    const { error: enrollError } = await supabaseClient
                        .from('class_enrollments')
                        .insert({
                            class_id: sessionData.id,
                            member_id: memberId,
                            status: 'booked'
                        });

                    if (enrollError) throw enrollError;
                    createdCount++;
                }

                let successMsg = `${createdCount} ders başarıyla oluşturuldu!`;
                if (limitReached) {
                    successMsg += ' (Paket doldu)';
                }
                showToast(successMsg, limitReached ? 'warning' : 'success', limitReached ? 5000 : 3000);
                modal.classList.remove('active');
                e.target.reset();
                timesContainer.innerHTML = '<div style="color: #666; font-size: 13px; font-style: italic;">Lütfen yukarıdan gün seçiniz.</div>';

                if (document.getElementById('section-history').style.display === 'block') loadHistory();

                // Close conflict modal if open
                document.getElementById('conflict-modal').classList.remove('active');

            } catch (error) {
                console.error(error);
                showToast('Hata: ' + (error.message || 'Ders oluşturulamadı'), 'error');
            } finally {
                btn.disabled = false; btn.textContent = 'Programı Oluştur';
            }
        };

        btn.disabled = true; btn.textContent = 'Kontrol Ediliyor...';

        try {
            const startDateVal = document.getElementById('schedule-start-date').value;
            const endDateVal = document.getElementById('schedule-end-date').value;
            const duration = parseInt(document.getElementById('schedule-duration').value);

            const dayTimeInputs = document.querySelectorAll('.day-time-input');
            if (dayTimeInputs.length === 0) throw new Error('Lütfen en az bir gün seçin');
            if (!startDateVal || !endDateVal) throw new Error('Tarih aralığı seçiniz');

            const startDt = new Date(startDateVal);
            const endDt = new Date(endDateVal);

            // Validate dates
            if (endDt < startDt) throw new Error('Bitiş tarihi başlangıç tarihinden önce olamaz');

            const dayTimes = {};
            dayTimeInputs.forEach(input => {
                dayTimes[parseInt(input.dataset.day)] = input.value;
            });

            // 1. Generate Candidates with Package Limit
            const candidates = [];

            // FIX: Use Member's session count, not Admin's
            // member variable is loaded in loadMemberDetails but not returned. 
            // We need to access it. Let's fetch it or use a global. 
            // Better: use the global 'currentMember' we will introduce, or fetch fresh.
            // For now, let's assume we need to fetch fresh to be safe or use what's on screen.
            // Actually, loadMemberDetails doesn't store it globally yet. 
            // I will update loadMemberDetails to store 'window.currentMember' shortly.
            // For this step I will rely on a new fetch or wait for the next step where I add window.currentMember.
            // To prevent breaking, I'll fetch it here first.

            const { data: memberData } = await supabaseClient
                .from('members')
                .select('session_count, used_session_count')
                .eq('id', memberId)
                .single();

            const remainingSessions = (memberData?.session_count || 0) - (memberData?.used_session_count || 0);

            let limitReached = false;

            for (let d = new Date(startDt); d <= endDt; d.setDate(d.getDate() + 1)) {
                // Stop if we hit the limit
                if (candidates.length >= remainingSessions) {
                    limitReached = true;
                    // Do not show error, just break to add what we can
                    break;
                }

                const currentDay = d.getDay();
                if (dayTimes.hasOwnProperty(currentDay)) {
                    const timeVal = dayTimes[currentDay];
                    const sessionStart = new Date(d);
                    const [hours, mins] = timeVal.split(':');
                    sessionStart.setHours(parseInt(hours), parseInt(mins), 0, 0);
                    const sessionEnd = new Date(sessionStart.getTime() + duration * 60000);

                    candidates.push({ start: sessionStart, end: sessionEnd });
                }
            }

            if (candidates.length === 0) {
                if (remainingSessions <= 0) throw new Error('Üyenin ders hakkı tükenmiş!');
                throw new Error('Seçilen tarih aralığında uygun gün bulunamadı.');
            }

            // 2. Check Conflicts (Optimized Global Check)
            const allConflicts = [];
            const processedConflictIds = new Set();

            // Batch check? Or Sequential? sequential is safer for now to get details
            // For large batches this might be slow, but typically 12-20 requests.
            // Suggestion: we could write a better single query check in classes.js but that's complex range overlap.
            // We'll stick to sequential reuse of checkConflicts.

            for (const cand of candidates) {
                const conflicts = await checkConflicts(cand.start, cand.end);
                conflicts.forEach(c => {
                    if (!processedConflictIds.has(c.id)) {
                        processedConflictIds.add(c.id);
                        allConflicts.push(c);
                    }
                });
            }

            // 3. Handle Conflicts
            if (allConflicts.length > 0) {
                const conflictListHtml = allConflicts.map(c => {
                    const start = new Date(c.start_time);
                    const end = new Date(c.end_time);
                    const timeStr = `${start.toLocaleDateString('tr-TR')} ${String(start.getHours()).padStart(2, '0')}:${String(start.getMinutes()).padStart(2, '0')}`;

                    const trainerName = c.trainer ? `${c.trainer.first_name} ${c.trainer.last_name}` : 'Bilinmeyen Hoca';
                    const memberNames = c.class_enrollments && c.class_enrollments.length > 0
                        ? c.class_enrollments.map(e => e.member?.name || 'Bilinmiyor').join(', ')
                        : 'Üye Yok';

                    return `• ${timeStr} | ${c.title}\n   👨‍🏫 Hoca: ${trainerName}\n   👤 Üye: ${memberNames}`;
                }).join('\n\n');

                // Show Modal
                const conflictModal = document.getElementById('conflict-modal');
                document.getElementById('conflict-list').style.whiteSpace = 'pre-wrap';
                document.getElementById('conflict-list').textContent = conflictListHtml;

                // Re-bind buttons
                const forceBtn = document.getElementById('conflict-force-btn');
                const cancelBtn = document.getElementById('conflict-cancel-btn');

                // Clone buttons to clear old listeners
                const newForceBtn = forceBtn.cloneNode(true);
                const newCancelBtn = cancelBtn.cloneNode(true);
                forceBtn.parentNode.replaceChild(newForceBtn, forceBtn);
                cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);

                newForceBtn.onclick = () => {
                    executeCreation(candidates, limitReached);
                };

                newCancelBtn.onclick = () => {
                    conflictModal.classList.remove('active');
                };

                // Close main modal listener for x
                document.getElementById('close-conflict-modal').onclick = () => {
                    conflictModal.classList.remove('active');
                };


                conflictModal.classList.add('active');
                btn.disabled = false; btn.textContent = 'Programı Oluştur';
                return; // Stop here, wait for modal action
            }

            // No conflicts, proceed immediately
            executeCreation(candidates, limitReached);

        } catch (error) {
            console.error(error);
            showToast('Hata: ' + (error.message || 'İşlem başarısız'), 'error');
            btn.disabled = false; btn.textContent = 'Programı Oluştur';
        }
    };
}


async function openScheduleModal() {
    // Check for existing future schedule
    try {
        const { data: existing, error } = await supabaseClient
            .from('class_enrollments')
            .select(`
                class_id,
                class_sessions!inner(start_time, status)
            `)
            .eq('member_id', memberId)
            .eq('class_sessions.status', 'scheduled')
            .gt('class_sessions.start_time', new Date().toISOString())
            .limit(1);

        if (error) throw error;

        if (existing && existing.length > 0) {
            document.getElementById('program-exists-modal').classList.add('active');
            return;
        }
    } catch (err) {
        console.error('Check existing schedule error:', err);
    }

    const today = new Date();
    document.getElementById('schedule-start-date').value = today.toISOString().split('T')[0];
    const nextMonth = new Date();
    nextMonth.setDate(nextMonth.getDate() + 30);
    document.getElementById('schedule-end-date').value = nextMonth.toISOString().split('T')[0];
    document.getElementById('schedule-modal').classList.add('active');
}


// --- Class Detail & Management Logic ---
let currentSessionId = null;

// openClassDetail removed


// Modal Actions Setup
document.addEventListener('DOMContentLoaded', () => {
    // ... existing ...

    // Close Detail Modal
    document.getElementById('close-detail-modal').onclick = () => {
        document.getElementById('class-detail-modal').classList.remove('active');
    };

    // Delete Button -> Open Confirm Modal
    document.getElementById('delete-class-btn').onclick = () => {
        document.getElementById('class-detail-modal').classList.remove('active'); // Close detail
        document.getElementById('delete-confirm-modal').classList.add('active'); // Open confirm
    };

    // Delete Logic
    document.getElementById('delete-single-btn').onclick = () => deleteClass('single');
    document.getElementById('delete-program-btn').onclick = () => deleteClass('program');

    // Complete Logic
    document.getElementById('complete-class-btn').onclick = completeClass;
});

// deleteClass and completeClass removed (using shared module)



// --- Measurement Logic ---
function setupMeasurementModal() {
    const modal = document.getElementById('measurement-modal');
    const close = document.getElementById('close-measurement-modal');
    close.onclick = () => modal.classList.remove('active');

    document.getElementById('measurement-form').onsubmit = async (e) => {
        e.preventDefault();
        const btn = e.target.querySelector('button');
        btn.disabled = true; btn.textContent = '...';

        try {
            const formData = {
                member_id: memberId,
                // CORRECT FIELD: measurement_date, not date
                measurement_date: new Date().toISOString(),
                weight: parseFloat(document.getElementById('meas-weight').value) || null,
                height: parseFloat(document.getElementById('meas-height').value) || null,
                body_fat_percentage: parseFloat(document.getElementById('meas-fat').value) || null,
                bone_mass: parseFloat(document.getElementById('meas-muscle').value) || null,
                water_percentage: parseFloat(document.getElementById('meas-water').value) || null,
                visceral_fat_rating: parseFloat(document.getElementById('meas-visceral').value) || null,
                metabolic_age: parseInt(document.getElementById('meas-metabolic-age').value) || null,
                basal_metabolic_rate: parseInt(document.getElementById('meas-bmr').value) || null,

                // Circumference (in cm)
                chest_cm: parseFloat(document.getElementById('meas-chest').value) || null,
                waist_cm: parseFloat(document.getElementById('meas-waist').value) || null,
                hips_cm: parseFloat(document.getElementById('meas-hip').value) || null,
                right_arm_cm: parseFloat(document.getElementById('meas-arm-right').value) || null,
                left_arm_cm: parseFloat(document.getElementById('meas-arm-left').value) || null,
                right_thigh_cm: parseFloat(document.getElementById('meas-leg-right').value) || null,
                left_thigh_cm: parseFloat(document.getElementById('meas-leg-left').value) || null,
            };

            const { error } = await supabaseClient.from('measurements').insert(formData);
            if (error) throw error;

            showToast('Ölçüm kaydedildi', 'success');
            modal.classList.remove('active');
            e.target.reset();

            // Refresh loaded sections if open
            if (document.getElementById('section-measurements').style.display === 'block') loadMeasurements();
            if (document.getElementById('section-charts').style.display === 'block') loadCharts();

        } catch (error) {
            showToast('Hata: ' + (error.message || 'Ölçüm kaydedilemedi'), 'error');
            console.error('Measurement Insert Error:', error);
        } finally {
            btn.disabled = false; btn.textContent = 'Kaydet';
        }
    };
}

function openMeasurementModal() {
    document.getElementById('measurement-modal').classList.add('active');
}

async function loadMeasurements() {
    const tbody = document.getElementById('measurements-table-body');
    const thead = document.querySelector('#section-measurements thead tr');
    tbody.innerHTML = '<tr><td colspan="7">Yükleniyor...</td></tr>';

    try {
        const { data, error } = await supabaseClient
            .from('measurements')
            .select('*')
            .eq('member_id', memberId)
            // CORRECT FIELD: measurement_date
            .order('measurement_date', { ascending: false });

        if (error) throw error;

        if (!data || data.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7">Kayıt bulunamadı.</td></tr>';
            return;
        }

        // Store measurements globally for comparison
        window.allMeasurements = data;

        // Define all possible columns with their field names
        const columns = [
            { label: 'Kilo (kg)', field: 'weight' },
            { label: 'Yağ (%)', field: 'body_fat_percentage' },
            { label: 'Kas (kg)', field: 'bone_mass' },
            { label: 'Bel (cm)', field: 'waist_cm' },
            { label: 'Kalça (cm)', field: 'hips_cm' },
        ];

        // Filter columns - only show if at least one measurement has a value
        const visibleColumns = columns.filter(col =>
            data.some(m => m[col.field] != null)
        );

        // Build table headers dynamically
        thead.innerHTML = `
            <th style="width: 40px;">Seç</th>
            <th>Tarih</th>
            ${visibleColumns.map(col => `<th>${col.label}</th>`).join('')}
        `;

        // Build table rows with only visible columns
        tbody.innerHTML = data.map(m => `
            <tr>
                <td><input type="checkbox" class="measurement-checkbox" data-measurement-id="${m.id}" onchange="handleMeasurementSelection()"></td>
                <td>${new Date(m.measurement_date).toLocaleDateString('tr-TR')}</td>
                ${visibleColumns.map(col => `<td>${m[col.field]?.toFixed(1) || '-'}</td>`).join('')}
            </tr>
        `).join('');

        return data; // Return for charts use
    } catch (error) {
        console.error('Measurement Load Error:', error);
        tbody.innerHTML = `<tr><td colspan="6" style="color: #ff6b6b;">Hata: ${error.message} (Detaylar konsolda)</td></tr>`;
    }
}

// --- Charts Logic ---
let currentMetric = 'weight';
let metricsChart = null;
let measurementsData = [];

// Metric configuration
const metricConfig = {
    weight: { label: 'Kilo (kg)', unit: 'kg', color: '#FFD700', decreaseIsGood: true },
    body_fat_percentage: { label: 'Yağ Oranı (%)', unit: '%', color: '#EF4444', decreaseIsGood: true },
    water_percentage: { label: 'Su (%)', unit: '%', color: '#3B82F6', decreaseIsGood: false },
    bone_mass: { label: 'Kemik (kg)', unit: 'kg', color: '#8B5CF6', decreaseIsGood: false },
    visceral_fat_rating: { label: 'Visceral Yağ', unit: '', color: '#F59E0B', decreaseIsGood: true },
    metabolic_age: { label: 'Metabolik Yaş', unit: 'yaş', color: '#EC4899', decreaseIsGood: true },
    basal_metabolic_rate: { label: 'BMR', unit: 'kcal', color: '#10B981', decreaseIsGood: false },
    chest_cm: { label: 'Göğüs (cm)', unit: 'cm', color: '#06B6D4', decreaseIsGood: false },
    waist_cm: { label: 'Bel (cm)', unit: 'cm', color: '#F97316', decreaseIsGood: true },
    hips_cm: { label: 'Kalça (cm)', unit: 'cm', color: '#A855F7', decreaseIsGood: true },
    left_arm_cm: { label: 'Sol Kol (cm)', unit: 'cm', color: '#14B8A6', decreaseIsGood: false },
    right_arm_cm: { label: 'Sağ Kol (cm)', unit: 'cm', color: '#0EA5E9', decreaseIsGood: false },
    left_thigh_cm: { label: 'Sol Bacak (cm)', unit: 'cm', color: '#84CC16', decreaseIsGood: false },
    right_thigh_cm: { label: 'Sağ Bacak (cm)', unit: 'cm', color: '#22D3EE', decreaseIsGood: false },
};

async function loadCharts() {
    try {
        const { data, error } = await supabaseClient
            .from('measurements')
            .select('*')
            .eq('member_id', memberId)
            .order('measurement_date', { ascending: true });

        if (error) throw error;
        if (!data || data.length === 0) return;

        measurementsData = data;

        // Initialize metric selector buttons
        initMetricSelector();

        // Render initial chart
        renderChart(currentMetric);
        updateTotalChange(currentMetric);
    } catch (error) {
        console.error('Chart Load Error:', error);
    }
}

function initMetricSelector() {
    const metricButtons = document.querySelectorAll('.metric-btn');
    metricButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const metric = btn.dataset.metric;

            // Update active state
            metricButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Update chart and change indicator
            currentMetric = metric;
            renderChart(metric);
            updateTotalChange(metric);
        });
    });
}

function renderChart(metric) {
    const config = metricConfig[metric];
    if (!config) return;

    const labels = measurementsData.map(d =>
        new Date(d.measurement_date).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short' })
    );
    const values = measurementsData.map(d => d[metric]).filter(v => v != null);

    // Calculate total change to determine chart color
    let chartColor = config.color; // Default color
    if (measurementsData.length >= 2) {
        const firstValue = measurementsData[0][metric];
        const lastValue = measurementsData[measurementsData.length - 1][metric];

        if (firstValue != null && lastValue != null) {
            const diff = lastValue - firstValue;

            if (diff === 0) {
                chartColor = '#FFD700'; // Yellow for no change
            } else {
                const isGood = (config.decreaseIsGood && diff < 0) || (!config.decreaseIsGood && diff > 0);
                chartColor = isGood ? '#10B981' : '#EF4444'; // Green or Red
            }
        }
    }

    // Destroy old chart if exists
    if (metricsChart) {
        metricsChart.destroy();
    }

    // Create new chart
    const canvas = document.getElementById('metricsChart');
    if (!canvas) return;

    metricsChart = new Chart(canvas, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: config.label,
                data: measurementsData.map(d => d[metric]),
                borderColor: chartColor,
                backgroundColor: `${chartColor}33`,
                fill: true,
                tension: 0.4,
                pointRadius: 5,
                pointHoverRadius: 7,
                pointBackgroundColor: chartColor,
                pointBorderColor: chartColor,
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            aspectRatio: 2,
            plugins: {
                legend: {
                    labels: {
                        color: '#fff',
                        font: { size: 14 }
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.8)',
                    titleColor: '#FFD700',
                    bodyColor: '#fff',
                    borderColor: chartColor,
                    borderWidth: 1,
                }
            },
            scales: {
                y: {
                    grid: { color: 'rgba(255,255,255,0.1)' },
                    ticks: {
                        color: '#888',
                        callback: function (value) {
                            return value.toFixed(1) + ' ' + config.unit;
                        }
                    }
                },
                x: {
                    grid: { color: 'rgba(255,255,255,0.1)' },
                    ticks: { color: '#888' }
                }
            }
        }
    });
}

function updateTotalChange(metric) {
    const config = metricConfig[metric];
    if (!config || measurementsData.length < 2) {
        document.getElementById('total-change-card').style.display = 'none';
        return;
    }

    const firstValue = measurementsData[0][metric];
    const lastValue = measurementsData[measurementsData.length - 1][metric];

    if (firstValue == null || lastValue == null) {
        document.getElementById('total-change-card').style.display = 'none';
        return;
    }

    const diff = lastValue - firstValue;
    const percentage = (diff / firstValue) * 100;

    // Determine color
    let color;
    if (diff === 0) {
        color = '#FFD700'; // Yellow for no change
    } else {
        const isGood = (config.decreaseIsGood && diff < 0) || (!config.decreaseIsGood && diff > 0);
        color = isGood ? '#10B981' : '#EF4444'; // Green or Red
    }

    // Update UI
    const changeValueEl = document.getElementById('change-value');
    const changeIconEl = document.getElementById('change-icon');
    const changePercentEl = document.getElementById('change-percentage');

    changeValueEl.textContent = `${diff > 0 ? '+' : ''}${diff.toFixed(1)} ${config.unit}`;
    changeValueEl.style.color = color;

    const icon = diff > 0 ? '▲' : (diff < 0 ? '▼' : '—');
    changeIconEl.textContent = icon;
    changeIconEl.style.color = color;

    changePercentEl.textContent = `${percentage > 0 ? '+' : ''}${percentage.toFixed(1)}%`;
    changePercentEl.style.color = color;
    changePercentEl.style.backgroundColor = `${color}33`;

    document.getElementById('total-change-card').style.display = 'block';
}

const chartOptions = {
    responsive: true,
    plugins: {
        legend: { labels: { color: '#fff' } }
    },
    scales: {
        y: {
            grid: { color: 'rgba(255,255,255,0.1)' },
            ticks: { color: '#888' }
        },
        x: {
            grid: { color: 'rgba(255,255,255,0.1)' },
            ticks: { color: '#888' }
        }
    }
};

// ==================== MEASUREMENT COMPARISON ====================
window.selectedMeasurements = [];

function handleMeasurementSelection() {
    const checkboxes = document.querySelectorAll('.measurement-checkbox:checked');
    const compareBtn = document.getElementById('compare-measurements-btn');

    if (checkboxes.length > 2) {
        checkboxes[checkboxes.length - 1].checked = false;
        showToast('En fazla 2 ölçüm seçebilirsiniz', 'warning');
        return;
    }

    window.selectedMeasurements = Array.from(checkboxes).map(cb => {
        const id = cb.dataset.measurementId;
        return window.allMeasurements.find(m => m.id === id);
    });

    if (window.selectedMeasurements.length === 2) {
        compareBtn.disabled = false;
        compareBtn.style.opacity = '1';
    } else {
        compareBtn.disabled = true;
        compareBtn.style.opacity = '0.5';
    }
}

function showMeasurementComparison() {
    if (window.selectedMeasurements.length !== 2) return;

    const [m1, m2] = window.selectedMeasurements;
    const oldM = new Date(m1.measurement_date) < new Date(m2.measurement_date) ? m1 : m2;
    const newM = new Date(m1.measurement_date) < new Date(m2.measurement_date) ? m2 : m1;

    const comparisonContent = document.getElementById('comparison-content');

    comparisonContent.innerHTML = `
        <div style="margin-bottom: 24px;">
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px;">
                <div style="text-align: center; flex: 1;">
                    <div style="color: #888; font-size: 12px; margin-bottom: 4px;">Eski Ölçüm</div>
                    <div style="font-weight: bold;">${new Date(oldM.measurement_date).toLocaleDateString('tr-TR', { day: '2-digit', month: 'short', year: 'numeric' })}</div>
                </div>
                <div style="color: #FFD700; font-size: 20px;">→</div>
                <div style="text-align: center; flex: 1;">
                    <div style="color: #888; font-size: 12px; margin-bottom: 4px;">Yeni Ölçüm</div>
                    <div style="font-weight: bold;">${new Date(newM.measurement_date).toLocaleDateString('tr-TR', { day: '2-digit', month: 'short', year: 'numeric' })}</div>
                </div>
            </div>
        </div>
        
        <h3 style="color: #FFD700; margin: 20px 0 12px;">Temel Bilgiler</h3>
        <div style="background: rgba(255,255,255,0.05); padding: 16px; border-radius: 12px; margin-bottom: 20px;">
            ${buildComparisonRow('Kilo', oldM.weight, newM.weight, 'kg', true)}
            ${buildComparisonRow('Yağ Oranı', oldM.body_fat_percentage, newM.body_fat_percentage, '%', true)}
            ${buildComparisonRow('BMI', oldM.weight && oldM.height ? calcBMI(oldM) : null, newM.weight && newM.height ? calcBMI(newM) : null, '', true)}
            ${buildComparisonRow('Su', oldM.water_percentage, newM.water_percentage, '%', false)}
            ${buildComparisonRow('Kemik', oldM.bone_mass, newM.bone_mass, 'kg', false)}
            ${buildComparisonRow('Visceral', oldM.visceral_fat_rating, newM.visceral_fat_rating, '', true)}
            ${buildComparisonRow('Met. Yaş', oldM.metabolic_age, newM.metabolic_age, '', true)}
            ${buildComparisonRow('BMR', oldM.basal_metabolic_rate, newM.basal_metabolic_rate, 'kcal', false)}
        </div>
        
        <h3 style="color: #FFD700; margin: 20px 0 12px;">Çevre Ölçümleri</h3>
        <div style="background: rgba(255,255,255,0.05); padding: 16px; border-radius: 12px;">
            ${buildComparisonRow('Göğüs', oldM.chest_cm, newM.chest_cm, 'cm', false)}
            ${buildComparisonRow('Bel', oldM.waist_cm, newM.waist_cm, 'cm', true)}
            ${buildComparisonRow('Kalça', oldM.hips_cm, newM.hips_cm, 'cm', true)}
            ${buildComparisonRow('Sol Kol', oldM.left_arm_cm, newM.left_arm_cm, 'cm', false)}
            ${buildComparisonRow('Sağ Kol', oldM.right_arm_cm, newM.right_arm_cm, 'cm', false)}
            ${buildComparisonRow('Sol Bacak', oldM.left_thigh_cm, newM.left_thigh_cm, 'cm', false)}
            ${buildComparisonRow('Sağ Bacak', oldM.right_thigh_cm, newM.right_thigh_cm, 'cm', false)}
        </div>
    `;

    document.getElementById('comparison-modal').classList.add('active');
}

function calcBMI(m) {
    if (!m.weight || !m.height) return null;
    return m.weight / ((m.height / 100) ** 2);
}

function buildComparisonRow(label, oldVal, newVal, unit, reverseLogic = false) {
    if (oldVal == null || newVal == null) return '';

    const diff = newVal - oldVal;
    let color, icon;

    if (diff === 0) {
        color = '#FFD700';
        icon = '—';
    } else {
        const isGood = (reverseLogic && diff < 0) || (!reverseLogic && diff > 0);
        color = isGood ? '#10B981' : '#EF4444';
        icon = diff > 0 ? '▲' : '▼';
    }

    return `
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">
            <div style="flex: 1; color: #ddd;">${label}</div>
            <div style="flex: 1; text-align: right;">
                <div style="font-size: 16px; font-weight: bold;">${newVal.toFixed(1)} ${unit}</div>
                <div style="font-size: 12px; color: #888;">${oldVal.toFixed(1)} ${unit}</div>
            </div>
            <div style="width: 80px; text-align: center; margin-left: 12px;">
                <div style="background: ${color}33; color: ${color}; padding: 4px 8px; border-radius: 8px; font-size: 13px; font-weight: bold;">
                    ${icon} ${Math.abs(diff).toFixed(1)}
                </div>
            </div>
        </div>
    `;
}

// Initialize comparison modal handlers
document.getElementById('compare-measurements-btn')?.addEventListener('click', showMeasurementComparison);
document.getElementById('close-comparison-modal')?.addEventListener('click', () => {
    document.getElementById('comparison-modal').classList.remove('active');
});
document.getElementById('comparison-modal')?.addEventListener('click', (e) => {
    if (e.target.id === 'comparison-modal') {
        document.getElementById('comparison-modal').classList.remove('active');
    }
});

// Make functions global
window.handleMeasurementSelection = handleMeasurementSelection;
