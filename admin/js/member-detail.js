import { supabaseClient } from './supabase-config.js';
import { showToast, formatDate } from './utils.js';

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

    // Setup Modals
    setupScheduleModal();
    setupMeasurementModal();
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
                <div style="background: rgba(255,255,255,0.05); padding: 15px; border-radius: 12px; margin-bottom: 10px; display:flex; justify-content:space-between; align-items:center;">
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
    const close = document.getElementById('close-schedule-modal');
    const form = document.getElementById('schedule-form');
    const dayCheckboxes = document.querySelectorAll('input[name="days"]');
    const timesContainer = document.getElementById('day-times-container');

    close.onclick = () => modal.classList.remove('active');

    // Listen for day changes to update time inputs
    dayCheckboxes.forEach(cb => {
        cb.addEventListener('change', updateTimeInputs);
    });

    function updateTimeInputs() {
        const selected = Array.from(dayCheckboxes)
            .filter(cb => cb.checked)
            .sort((a, b) => {
                // Sort Mon(1) to Sun(0 -> 7)
                const valA = parseInt(a.value) === 0 ? 7 : parseInt(a.value);
                const valB = parseInt(b.value) === 0 ? 7 : parseInt(b.value);
                return valA - valB;
            });

        if (selected.length === 0) {
            timesContainer.innerHTML = '<div style="color: #666; font-size: 13px; font-style: italic;">Lütfen yukarıdan gün seçiniz.</div>';
            return;
        }

        // Save existing values
        const existingValues = {};
        document.querySelectorAll('.day-time-input').forEach(input => {
            existingValues[input.dataset.day] = input.value;
        });

        timesContainer.innerHTML = '';

        selected.forEach(cb => {
            const dayVal = cb.value;
            const dayName = cb.nextElementSibling.textContent; // "Pzt", "Sal" etc.
            const savedTime = existingValues[dayVal] || '10:00';

            const row = document.createElement('div');
            row.style.cssText = 'display: flex; align-items: center; justify-content: space-between; background: rgba(255,255,255,0.05); padding: 8px 12px; border-radius: 8px;';

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
        btn.disabled = true; btn.textContent = 'Oluşturuluyor...';

        try {
            const startDateVal = document.getElementById('schedule-start-date').value;
            const endDateVal = document.getElementById('schedule-end-date').value;
            const duration = parseInt(document.getElementById('schedule-duration').value);
            const notes = document.getElementById('schedule-notes').value;

            const dayTimeInputs = document.querySelectorAll('.day-time-input');
            if (dayTimeInputs.length === 0) throw new Error('Lütfen en az bir gün seçin');
            if (!startDateVal || !endDateVal) throw new Error('Tarih aralığı seçiniz');

            const startDt = new Date(startDateVal);
            const endDt = new Date(endDateVal);

            // Map: DayValue -> TimeString
            const dayTimes = {};
            dayTimeInputs.forEach(input => {
                dayTimes[parseInt(input.dataset.day)] = input.value;
            });

            // 1. Generate all candidates first
            const candidates = [];
            for (let d = new Date(startDt); d <= endDt; d.setDate(d.getDate() + 1)) {
                const currentDay = d.getDay();

                if (dayTimes.hasOwnProperty(currentDay)) {
                    const timeVal = dayTimes[currentDay];
                    const sessionStart = new Date(d);
                    const [hours, mins] = timeVal.split(':');
                    sessionStart.setHours(parseInt(hours), parseInt(mins), 0, 0);
                    const sessionEnd = new Date(sessionStart.getTime() + duration * 60000);

                    candidates.push({
                        start: sessionStart,
                        end: sessionEnd
                    });
                }
            }

            if (candidates.length === 0) throw new Error('Seçilen tarih aralığında uygun gün bulunamadı.');

            // 2. Check for conflicts
            btn.textContent = 'Çakışma Kontrol Ediliyor...';

            const rangeStart = new Date(startDt);
            rangeStart.setHours(0, 0, 0, 0);
            const rangeEnd = new Date(endDt);
            rangeEnd.setHours(23, 59, 59, 999);

            const trainerId = profile ? profile.id : (await supabaseClient.auth.getUser()).data.user.id;

            const { data: existingSessions, error: fetchError } = await supabaseClient
                .from('class_sessions')
                .select('start_time, end_time, title')
                .eq('trainer_id', trainerId)
                .neq('status', 'cancelled')
                .gte('start_time', rangeStart.toISOString())
                .lte('end_time', rangeEnd.toISOString());

            if (fetchError) throw fetchError;

            // Find conflicts
            const conflicts = [];
            candidates.forEach(cand => {
                const hasConflict = existingSessions.some(ex => {
                    const exStart = new Date(ex.start_time);
                    const exEnd = new Date(ex.end_time);
                    return cand.start < exEnd && cand.end > exStart;
                });
                if (hasConflict) conflicts.push(cand);
            });

            // 3. If conflicts exist, ask user
            if (conflicts.length > 0) {
                btn.disabled = false;
                btn.textContent = 'Programı Oluştur';

                const conflictList = conflicts.slice(0, 5).map(c =>
                    `• ${c.start.toLocaleDateString('tr-TR')} ${c.start.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}`
                ).join('\n');

                const extraMsg = conflicts.length > 5 ? `\n...ve ${conflicts.length - 5} diğer çakışma` : '';

                const userConfirmed = confirm(
                    `⚠️ ÇAKIŞMA TESPİT EDİLDİ!\n\n${conflicts.length} derste saat çakışması var:\n\n${conflictList}${extraMsg}\n\nYine de bu dersleri eklemek istiyor musunuz?`
                );

                if (!userConfirmed) return; // User cancelled

                btn.disabled = true;
            }

            // 4. Create all sessions
            btn.textContent = 'Oluşturuluyor...';
            let createdCount = 0;

            for (const cand of candidates) {
                const { data: sessionData, error: sessionError } = await supabaseClient
                    .from('class_sessions')
                    .insert({
                        trainer_id: trainerId,
                        title: 'Bireysel Ders',
                        start_time: cand.start.toISOString(),
                        end_time: cand.end.toISOString(),
                        description: notes,
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

            showToast(`${createdCount} ders başarıyla oluşturuldu!`, 'success');
            modal.classList.remove('active');
            e.target.reset();
            timesContainer.innerHTML = '<div style="color: #666; font-size: 13px; font-style: italic;">Lütfen yukarıdan gün seçiniz.</div>';

            if (document.getElementById('section-history').style.display === 'block') loadHistory();

        } catch (error) {
            console.error(error);
            showToast('Hata: ' + (error.message || 'Ders oluşturulamadı'), 'error');
        } finally {
            btn.disabled = false; btn.textContent = 'Programı Oluştur';
        }
    };
}

function openScheduleModal() {
    const today = new Date();
    document.getElementById('schedule-start-date').value = today.toISOString().split('T')[0];
    const nextMonth = new Date();
    nextMonth.setDate(nextMonth.getDate() + 30);
    document.getElementById('schedule-end-date').value = nextMonth.toISOString().split('T')[0];
    document.getElementById('schedule-modal').classList.add('active');
}


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
async function loadCharts() {
    const { data, error } = await supabaseClient
        .from('measurements')
        .select('measurement_date, weight, body_fat_percentage')
        .eq('member_id', memberId)
        .order('measurement_date', { ascending: true }); // Ascending for chart

    if (error || !data) return;

    const labels = data.map(d => new Date(d.measurement_date).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short' }));
    const weights = data.map(d => d.weight);
    const fats = data.map(d => d.body_fat_percentage);

    // Destroy old if exists
    if (charts.weight) charts.weight.destroy();
    if (charts.fat) charts.fat.destroy();

    // Weight Chart
    charts.weight = new Chart(document.getElementById('weightChart'), {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Kilo (kg)',
                data: weights,
                borderColor: '#FFD700', // Yellow
                backgroundColor: 'rgba(255, 215, 0, 0.1)',
                fill: true,
                tension: 0.4
            }]
        },
        options: chartOptions
    });

    // Fat Chart
    charts.fat = new Chart(document.getElementById('fatChart'), {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Yağ Oranı (%)',
                data: fats,
                borderColor: '#EF4444', // Red
                backgroundColor: 'rgba(239, 68, 68, 0.1)',
                fill: true,
                tension: 0.4
            }]
        },
        options: chartOptions
    });
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
