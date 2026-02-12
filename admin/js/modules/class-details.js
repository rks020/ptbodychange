import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

let currentSessionId = null;
let originalData = {};
let currentCallback = null; // To refresh parent list (loadHistory or loadClasses)

export function setUpdateCallback(cb) {
    currentCallback = cb;
}

export async function openClassDetailModal(sessionId) {
    currentSessionId = sessionId;
    const modal = document.getElementById('class-detail-modal');
    const updateBtn = document.getElementById('update-class-btn');

    // Reset UI
    document.getElementById('detail-title').textContent = 'Yükleniyor...';
    document.getElementById('detail-member-name').textContent = '-';
    document.getElementById('detail-avatar').textContent = '-';
    document.getElementById('detail-date-input').value = '';
    document.getElementById('detail-time-start').value = '';
    document.getElementById('detail-time-end').value = '';

    updateBtn.style.display = 'none';
    document.getElementById('complete-class-btn').style.display = 'none';

    try {
        const { data: session, error } = await supabaseClient
            .from('class_sessions')
            .select(`
                *,
                trainer:trainer_id(first_name, last_name),
                enrollments:class_enrollments(
                    member_id,
                    status,
                    member:member_id(name)
                )
            `)
            .eq('id', sessionId)
            .single();

        if (error) throw error;

        // Populate Data
        const startDate = new Date(session.start_time);
        const endDate = new Date(session.end_time);

        document.getElementById('detail-title').textContent = session.title || 'Bireysel Ders';

        // Date & Time Inputs
        const dateStr = startDate.toISOString().split('T')[0];
        const timeStartStr = startDate.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });
        const timeEndStr = endDate.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });

        document.getElementById('detail-date-input').value = dateStr;
        document.getElementById('detail-time-start').value = timeStartStr;
        document.getElementById('detail-time-end').value = timeEndStr;

        // Store original for comparison
        originalData = {
            date: dateStr,
            start: timeStartStr,
            end: timeEndStr
        };

        // Member Info
        const enrollment = session.enrollments[0];
        if (enrollment && enrollment.member) {
            document.getElementById('detail-member-name').textContent = enrollment.member.name;
            document.getElementById('detail-avatar').textContent = enrollment.member.name.charAt(0).toUpperCase();
        }

        // Action Buttons Visibility
        if (session.status === 'scheduled') {
            document.getElementById('complete-class-btn').style.display = 'block';
        }

        modal.classList.add('active');

    } catch (err) {
        showToast('Ders detayları yüklenemedi', 'error');
    }
}

// Check for changes to show Update button
function checkChanges() {
    const newDate = document.getElementById('detail-date-input').value;
    const newStart = document.getElementById('detail-time-start').value;
    const newEnd = document.getElementById('detail-time-end').value;

    const hasChanged =
        newDate !== originalData.date ||
        newStart !== originalData.start ||
        newEnd !== originalData.end;

    document.getElementById('update-class-btn').style.display = hasChanged ? 'block' : 'none';
}

// Initial Setup
export function setupClassDetailModal() {
    const modal = document.getElementById('class-detail-modal');
    if (!modal) return;

    // Changes Listener
    ['detail-date-input', 'detail-time-start', 'detail-time-end'].forEach(id => {
        document.getElementById(id).addEventListener('input', checkChanges);
    });

    // Close
    document.getElementById('close-detail-modal').onclick = () => {
        modal.classList.remove('active');
    };

    // Update Action
    document.getElementById('update-class-btn').onclick = saveChanges;

    // Delete Modal Trigger
    document.getElementById('delete-class-trigger').onclick = () => {
        modal.classList.remove('active');
        document.getElementById('delete-confirm-modal').classList.add('active');
    };

    // Delete Actions
    document.getElementById('delete-single-btn').onclick = () => deleteClass('single');
    document.getElementById('delete-program-btn').onclick = () => deleteClass('program');

    // Cancel Delete
    const cancelDelete = document.getElementById('cancel-delete-btn');
    if (cancelDelete) { // if exists
        cancelDelete.onclick = () => document.getElementById('delete-confirm-modal').classList.remove('active');
    } else {
        // Fallback if user clicks outside or needs close button
        const closeDelete = document.querySelector('#delete-confirm-modal .close-modal');
        if (closeDelete) closeDelete.onclick = () => document.getElementById('delete-confirm-modal').classList.remove('active');
    }

    // Complete Action
    document.getElementById('complete-class-btn').onclick = completeClass;
}

async function saveChanges() {
    const newDate = document.getElementById('detail-date-input').value;
    const newStart = document.getElementById('detail-time-start').value;
    const newEnd = document.getElementById('detail-time-end').value;

    const btn = document.getElementById('update-class-btn');
    btn.textContent = 'Kaydediliyor...';
    btn.disabled = true;

    try {
        // Construct ISO strings
        const startDateTime = new Date(`${newDate}T${newStart}`);
        const endDateTime = new Date(`${newDate}T${newEnd}`);

        if (isNaN(startDateTime) || isNaN(endDateTime)) throw new Error('Geçersiz tarih/saat');
        if (endDateTime <= startDateTime) throw new Error('Bitiş saati başlangıçtan sonra olmalı');

        const { error } = await supabaseClient
            .from('class_sessions')
            .update({
                start_time: startDateTime.toISOString(),
                end_time: endDateTime.toISOString()
            })
            .eq('id', currentSessionId);

        if (error) throw error;
        showToast('Ders güncellendi', 'success');
        document.getElementById('class-detail-modal').classList.remove('active');
        if (currentCallback) currentCallback();

    } catch (err) {
        showToast('Güncelleme başarısız: ' + err.message, 'error');
    } finally {
        btn.textContent = 'Değişiklikleri Kaydet';
        btn.disabled = false;
    }
}

async function deleteClass(mode) {
    if (!currentSessionId) return;
    const modal = document.getElementById('delete-confirm-modal');

    try {
        if (mode === 'single') {
            const { error } = await supabaseClient
                .from('class_sessions')
                .delete()
                .eq('id', currentSessionId);
            if (error) throw error;
            showToast('Ders silindi', 'success');
        } else {
            // Get member Id first from the session... or passing it might be cleaner. 
            // Reuse the logic from before: Find enrollment -> find member -> delete future sessions

            // 1. Get enrollments for this session to identify the member
            const { data: session } = await supabaseClient
                .from('class_sessions')
                .select('class_enrollments(member_id)')
                .eq('id', currentSessionId)
                .single();

            const memberId = session?.class_enrollments?.[0]?.member_id;
            if (!memberId) throw new Error('Üye bilgisi bulunamadı');

            // 2. Find all future schedules for this member
            const { data: enrollments } = await supabaseClient
                .from('class_enrollments')
                .select('class_id, class_sessions!inner(status, start_time)')
                .eq('member_id', memberId)
                .eq('class_sessions.status', 'scheduled')
                .gt('class_sessions.start_time', new Date().toISOString());

            if (enrollments && enrollments.length > 0) {
                const ids = enrollments.map(e => e.class_id);
                const { error: delError } = await supabaseClient
                    .from('class_sessions')
                    .delete()
                    .in('id', ids);
                if (delError) throw delError;
                showToast('Tüm program silindi', 'success');
            } else {
                showToast('Silinecek program bulunamadı', 'info');
            }
        }
        modal.classList.remove('active');
        if (currentCallback) currentCallback();

    } catch (err) {
        showToast('Silme işlemi başarısız', 'error');
    }
}

async function completeClass() {
    if (!currentSessionId) return;

    try {
        const { data: session } = await supabaseClient
            .from('class_sessions')
            .select('class_enrollments(member_id)')
            .eq('id', currentSessionId)
            .single();

        const memberId = session?.class_enrollments?.[0]?.member_id;

        const { error } = await supabaseClient
            .from('class_sessions')
            .update({ status: 'completed' })
            .eq('id', currentSessionId);

        if (error) throw error;

        // Update count if member exists
        if (memberId) {
            const { data: member } = await supabaseClient
                .from('members')
                .select('used_session_count')
                .eq('id', memberId)
                .single();

            await supabaseClient
                .from('members')
                .update({ used_session_count: (member?.used_session_count || 0) + 1 })
                .eq('id', memberId);
        }

        showToast('Ders tamamlandı', 'success');
        document.getElementById('class-detail-modal').classList.remove('active');
        if (currentCallback) currentCallback();

    } catch (err) {
        showToast('Tamamlama başarısız', 'error');
    }
}
