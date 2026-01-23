import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';

// Check session
async function checkSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) {
        window.location.href = 'login.html';
        return;
    }

    // Check role/org
    const { data: profile } = await supabaseClient
        .from('profiles')
        .select('role, organization_id')
        .eq('id', session.user.id)
        .single();

    return profile;
}

document.addEventListener('DOMContentLoaded', async () => {
    const profile = await checkSession();
    if (!profile) return;

    const form = document.getElementById('add-member-form');
    const saveBtn = document.getElementById('save-member-btn');

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const firstname = document.getElementById('member-firstname').value.trim();
        const lastname = document.getElementById('member-lastname').value.trim();
        const email = document.getElementById('member-email').value.trim();
        const password = document.getElementById('member-password').value.trim();

        if (!firstname || !lastname || !email || !password) {
            showToast('Lütfen tüm alanları doldurun', 'error');
            return;
        }

        saveBtn.disabled = true;
        saveBtn.querySelector('.btn-text').style.display = 'none';
        saveBtn.querySelector('.btn-loader').style.display = 'inline';

        try {
            const { data, error } = await supabaseClient.functions.invoke('create-member', {
                body: {
                    email,
                    password,
                    first_name: firstname,
                    last_name: lastname,
                    organization_id: profile.organization_id
                }
            });

            if (error) throw error;
            if (data?.error) throw new Error(data.error);

            showToast('Üye başarıyla oluşturuldu!', 'success');
            setTimeout(() => {
                window.location.href = 'dashboard.html#members';
            }, 1000);

        } catch (error) {
            console.error('Error adding member:', error);
            const errorMessage = error.message || error.toString();

            if (errorMessage.includes('already') ||
                errorMessage.includes('duplicate') ||
                errorMessage.includes('exists') ||
                errorMessage.includes('unique') ||
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
