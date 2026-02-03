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
    close.onclick = () => modal.classList.remove('active');

    document.getElementById('schedule-form').onsubmit = async (e) => {
        e.preventDefault();
        const btn = e.target.querySelector('button');
        btn.disabled = true; btn.textContent = 'Oluşturuluyor...';

        try {
            const startDateVal = document.getElementById('schedule-start-date').value;
            const endDateVal = document.getElementById('schedule-end-date').value;
            const timeVal = document.getElementById('schedule-time').value; // HH:MM
            const duration = parseInt(document.getElementById('schedule-duration').value);
            const notes = document.getElementById('schedule-notes').value;

            // Get checked days
            const dayCheckboxes = document.querySelectorAll('input[name="days"]:checked');
            const selectedDays = Array.from(dayCheckboxes).map(cb => parseInt(cb.value)); // 1=Mon, ..., 0=Sun

            if (selectedDays.length === 0) throw new Error('Lütfen en az bir gün seçin');
            if (!startDateVal || !endDateVal) throw new Error('Tarih aralığı seçiniz');
            if (!timeVal) throw new Error('Saat seçiniz');

            // Find valid dates
            const startDt = new Date(startDateVal);
            const endDt = new Date(endDateVal);
            let createdCount = 0;

            // Loop through dates
            for (let d = new Date(startDt); d <= endDt; d.setDate(d.getDate() + 1)) {
                if (selectedDays.includes(d.getDay())) {
                    // 1. Create Class Session
                    const sessionStart = new Date(d);
                    const [hours, mins] = timeVal.split(':');
                    sessionStart.setHours(parseInt(hours), parseInt(mins), 0, 0);
                    const sessionEnd = new Date(sessionStart.getTime() + duration * 60000);

                    const { data: sessionData, error: sessionError } = await supabaseClient
                        .from('class_sessions')
                        .insert({
                            // member_id is NOT in this table
                            trainer_id: profile ? profile.id : (await supabaseClient.auth.getUser()).data.user.id,
                            title: 'Bireysel Ders',
                            start_time: sessionStart.toISOString(),
                            end_time: sessionEnd.toISOString(),
                            notes: notes,
                            status: 'scheduled'
                        })
                        .select()
                        .single();

                    if (sessionError) throw sessionError;

                    // 2. Create Enrollment
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
            }

            if (createdCount === 0) throw new Error('Seçilen tarih aralığında ve günlerde uygun gün bulunamadı.');

            showToast(`${createdCount} ders başarıyla oluşturuldu!`, 'success');
            modal.classList.remove('active');
            e.target.reset();

            // Refresh history if open
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
                body_fat_ratio: parseFloat(document.getElementById('meas-fat').value) || null,
                muscle_mass: parseFloat(document.getElementById('meas-muscle').value) || null,
                water_ratio: parseFloat(document.getElementById('meas-water').value) || null,
                visceral_fat_rating: parseFloat(document.getElementById('meas-visceral').value) || null,
                metabolic_age: parseInt(document.getElementById('meas-metabolic-age').value) || null,
                bmr: parseInt(document.getElementById('meas-bmr').value) || null,

                // Circumference
                shoulder_circumference: parseFloat(document.getElementById('meas-shoulder').value) || null,
                chest_circumference: parseFloat(document.getElementById('meas-chest').value) || null,
                arm_right_circumference: parseFloat(document.getElementById('meas-arm-right').value) || null,
                waist_circumference: parseFloat(document.getElementById('meas-waist').value) || null,
                hip_circumference: parseFloat(document.getElementById('meas-hip').value) || null,
                leg_right_circumference: parseFloat(document.getElementById('meas-leg-right').value) || null,
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
    tbody.innerHTML = '<tr><td colspan="6">Yükleniyor...</td></tr>';

    try {
        const { data, error } = await supabaseClient
            .from('measurements')
            .select('*')
            .eq('member_id', memberId)
            // CORRECT FIELD: measurement_date
            .order('measurement_date', { ascending: false });

        if (error) throw error;

        if (!data || data.length === 0) {
            tbody.innerHTML = '<tr><td colspan="6">Kayıt bulunamadı.</td></tr>';
            return;
        }

        tbody.innerHTML = data.map(m => `
            <tr>
                <td>${new Date(m.measurement_date).toLocaleDateString('tr-TR')}</td>
                <td>${m.weight?.toFixed(1) || '-'}</td>
                <td>${m.body_fat_ratio?.toFixed(1) || '-'}</td>
                <td>${m.muscle_mass?.toFixed(1) || '-'}</td>
                <td>${m.waist_circumference?.toFixed(1) || '-'}</td>
                <td>${m.hip_circumference?.toFixed(1) || '-'}</td>
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
        .select('measurement_date, weight, body_fat_ratio') // CORRECT FIELD
        .eq('member_id', memberId)
        .order('measurement_date', { ascending: true }); // Ascending for chart

    if (error || !data) return;

    const labels = data.map(d => new Date(d.measurement_date).toLocaleDateString('tr-TR', { day: 'numeric', month: 'short' }));
    const weights = data.map(d => d.weight);
    const fats = data.map(d => d.body_fat_ratio);

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
