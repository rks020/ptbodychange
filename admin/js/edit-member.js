import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';

// Load trainers for dropdown
async function loadTrainers(selectedId) {
    try {
        const { data: trainers, error } = await supabaseClient
            .from('profiles')
            .select('id, first_name, last_name')
            .or('role.eq.trainer,role.eq.admin,role.eq.owner')
            .order('first_name');

        if (error) throw error;

        const trainerSelect = document.getElementById('member-trainer');
        trainerSelect.innerHTML = '<option value="">Eğitmen Yok</option>'; // Reset

        trainers.forEach(trainer => {
            const option = document.createElement('option');
            option.value = trainer.id;
            option.textContent = `${trainer.first_name} ${trainer.last_name}`;
            if (selectedId === trainer.id) option.selected = true;
            trainerSelect.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading trainers:', error);
    }
}

document.addEventListener('DOMContentLoaded', async () => {
    // Get ID from URL
    const urlParams = new URLSearchParams(window.location.search);
    const memberId = urlParams.get('id');

    if (!memberId) {
        showToast('Üye ID bulunamadı', 'error');
        setTimeout(() => window.location.href = 'dashboard.html#members', 1500);
        return;
    }

    // Check session
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) {
        window.location.href = 'login.html';
        return;
    }

    // Load Member Data
    try {
        const { data: member, error } = await supabaseClient
            .from('members')
            .select('*, auth_profile:profiles!id(password_changed)')
            .eq('id', memberId)
            .single();

        if (error) throw error;

        // Fill Form
        const nameParts = member.name.split(' ');
        const lastName = nameParts.pop(); // Last part is last name
        const firstName = nameParts.join(' '); // Remainder is first name

        document.getElementById('member-id').value = member.id;
        document.getElementById('member-firstname').value = firstName;
        document.getElementById('member-lastname').value = lastName;
        document.getElementById('member-email').value = member.email;
        document.getElementById('member-phone').value = member.phone || '';
        document.getElementById('member-sessions').value = member.session_count || 0;
        document.getElementById('emergency-contact').value = member.emergency_contact || '';
        document.getElementById('emergency-phone').value = member.emergency_phone || '';
        document.getElementById('member-active').checked = member.is_active;

        // Handle Package (add if not in list)
        const packageSelect = document.getElementById('member-package');
        if (member.subscription_package) {
            const exists = [...packageSelect.options].some(o => o.value === member.subscription_package);
            if (!exists) {
                const opt = document.createElement('option');
                opt.value = member.subscription_package;
                opt.text = member.subscription_package;
                packageSelect.add(opt);
            }
            packageSelect.value = member.subscription_package;
        }

        // Load Trainers and set selected
        await loadTrainers(member.trainer_id);

        // Show Password Reset Section if eligible
        const passwordSection = document.getElementById('password-change-section');
        // Check if auth_profile exists and password_changed is false
        const passwordChanged = member.auth_profile?.password_changed;
        if (passwordChanged === false) { // Explicit check for false
            passwordSection.style.display = 'block';

            // Handle Password Update
            const updatePassBtn = document.getElementById('update-password-btn');
            updatePassBtn.addEventListener('click', async () => {
                const newPassInput = document.getElementById('new-temp-password');
                const newPass = newPassInput.value.trim();

                if (newPass.length < 6) {
                    showToast('Şifre en az 6 karakter olmalıdır', 'error');
                    return;
                }

                try {
                    updatePassBtn.textContent = 'Güncelleniyor...';
                    updatePassBtn.disabled = true;

                    const { error } = await supabaseClient.functions.invoke('update-user-password', {
                        body: { userId: memberId, newPassword: newPass }
                    });

                    if (error) throw error;

                    showToast('Geçici şifre başarıyla güncellendi', 'success');
                    newPassInput.value = ''; // operations security

                } catch (error) {
                    console.error('Password update error:', error);
                    showToast('Şifre güncellenemedi: ' + error.message, 'error');
                } finally {
                    updatePassBtn.textContent = 'Şifreyi Güncelle';
                    updatePassBtn.disabled = false;
                }
            });
        }

    } catch (error) {
        console.error('Error loading member:', error);
        showToast('Üye bilgileri yüklenemedi', 'error');
    }

    // Handle Save
    const form = document.getElementById('edit-member-form');
    const saveBtn = document.getElementById('save-member-btn');

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const firstname = document.getElementById('member-firstname').value.trim();
        const lastname = document.getElementById('member-lastname').value.trim();
        const phone = document.getElementById('member-phone').value.trim();
        const packageInfo = document.getElementById('member-package').value;
        const sessions = document.getElementById('member-sessions').value;
        const trainerId = document.getElementById('member-trainer').value;
        const emergencyContact = document.getElementById('emergency-contact').value.trim();
        const emergencyPhone = document.getElementById('emergency-phone').value.trim();
        const isActive = document.getElementById('member-active').checked;

        if (!firstname || !lastname) {
            showToast('Ad ve Soyad zorunludur', 'error');
            return;
        }

        saveBtn.disabled = true;
        saveBtn.querySelector('.btn-text').style.display = 'none';
        saveBtn.querySelector('.btn-loader').style.display = 'inline';

        try {
            const { error } = await supabaseClient
                .from('members')
                .update({
                    name: `${firstname} ${lastname}`.trim(),
                    phone: phone || null,
                    subscription_package: packageInfo || null,
                    session_count: parseInt(sessions) || 0,
                    trainer_id: trainerId || null,
                    emergency_contact: emergencyContact || null,
                    emergency_phone: emergencyPhone || null,
                    is_active: isActive
                })
                .eq('id', memberId);

            if (error) throw error;

            showToast('Üye bilgileri güncellendi!', 'success');
            setTimeout(() => {
                window.location.href = 'dashboard.html#members';
            }, 1000);

        } catch (error) {
            console.error('Error updating member:', error);
            showToast('Güncelleme hatası: ' + error.message, 'error');
        } finally {
            saveBtn.disabled = false;
            saveBtn.querySelector('.btn-text').style.display = 'inline';
            saveBtn.querySelector('.btn-loader').style.display = 'none';
        }
    });

});
