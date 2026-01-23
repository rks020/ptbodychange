import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';

// Check session
async function checkSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) {
        window.location.href = 'login.html';
        return;
    }

    // Check role
    const { data: profile } = await supabaseClient
        .from('profiles')
        .select('role, organization_id')
        .eq('id', session.user.id)
        .single();

    if (!profile || (profile.role !== 'owner' && profile.role !== 'admin')) {
        showToast('Yetkiniz yok', 'error');
        setTimeout(() => window.location.href = 'dashboard.html', 1000);
    }

    return profile;
}

document.addEventListener('DOMContentLoaded', async () => {
    const profile = await checkSession();
    if (!profile) return;

    const form = document.getElementById('add-trainer-form');
    const saveBtn = document.getElementById('save-trainer-btn');

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const firstname = document.getElementById('trainer-firstname').value.trim();
        const lastname = document.getElementById('trainer-lastname').value.trim();
        const email = document.getElementById('trainer-email').value.trim();
        const password = document.getElementById('trainer-password').value.trim();
        const specialty = document.getElementById('trainer-specialty').value.trim();

        if (!firstname || !lastname || !email || !password) {
            showToast('Lütfen zorunlu alanları doldurun', 'error');
            return;
        }

        saveBtn.disabled = true;
        saveBtn.querySelector('.btn-text').style.display = 'none';
        saveBtn.querySelector('.btn-loader').style.display = 'inline';

        try {
            const { data, error } = await supabaseClient.functions.invoke('create-trainer', {
                body: {
                    email,
                    password,
                    first_name: firstname,
                    last_name: lastname,
                    specialty: specialty || null,
                    organization_id: profile.organization_id
                }
            });

            if (error) throw error;
            if (data?.error) throw new Error(data.error);

            showToast('Antrenör başarıyla oluşturuldu!', 'success');
            setTimeout(() => {
                window.location.href = 'dashboard.html#trainers';
            }, 1000);

        } catch (error) {
            console.error('Error adding trainer:', error);

            const errorMessage = error.message || error.toString();

            // Check for specific error types including generic Edge Function error (usually implies validation/dup failure)
            if (errorMessage.includes('already') ||
                errorMessage.includes('duplicate') ||
                errorMessage.includes('exists') ||
                errorMessage.includes('unique') ||
                errorMessage.includes('User already registered') ||
                errorMessage.includes('Edge Function returned a non-2xx status code')) {
                showToast('Bu email adresi sistemimizde kayıtlıdır. Lütfen farklı bir email kullanın.', 'error');
            } else {
                showToast('Hata: ' + errorMessage, 'error');
            }
        } finally {
            saveBtn.disabled = false;
            saveBtn.querySelector('.btn-text').style.display = 'inline';
            saveBtn.querySelector('.btn-loader').style.display = 'none';
        }
    });
});
