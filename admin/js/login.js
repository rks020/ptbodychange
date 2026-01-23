import { supabaseClient } from './supabase-config.js';

// Show toast notification
function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
        toast.remove();
    }, 4000);
}

// Check if already logged in
async function checkSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();

    if (session) {
        // Already logged in, redirect to dashboard
        window.location.href = 'dashboard.html';
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkSession();

    const loginForm = document.getElementById('login-form-element');
    const loginBtn = document.getElementById('login-btn');
    const loginEmail = document.getElementById('login-email');
    const loginPassword = document.getElementById('login-password');

    // Password toggle
    document.querySelectorAll('.toggle-password').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = btn.getAttribute('data-target');
            const input = document.getElementById(targetId);
            const eyeOpen = btn.querySelector('.eye-open');
            const eyeClosed = btn.querySelector('.eye-closed');

            if (input) {
                if (input.type === 'password') {
                    input.type = 'text';
                    eyeOpen.style.display = 'none';
                    eyeClosed.style.display = 'block';
                } else {
                    input.type = 'password';
                    eyeOpen.style.display = 'block';
                    eyeClosed.style.display = 'none';
                }
            }
        });
    });

    // Handle login
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const email = loginEmail.value.trim();
        const password = loginPassword.value.trim();

        if (!email || !password) {
            showToast('Lütfen email ve şifre girin', 'error');
            return;
        }

        // Show loading
        loginBtn.disabled = true;
        loginBtn.querySelector('.btn-text').style.display = 'none';
        loginBtn.querySelector('.btn-loader').style.display = 'inline';

        try {
            const { data, error } = await supabaseClient.auth.signInWithPassword({
                email,
                password
            });

            if (error) throw error;

            // Verify role
            const { data: profile } = await supabaseClient
                .from('profiles')
                .select('role, organization_id, first_name, last_name')
                .eq('id', data.user.id)
                .single();

            if (!profile || (profile.role !== 'owner' && profile.role !== 'trainer')) {
                await supabaseClient.auth.signOut();
                showToast('Bu panel sadece salon sahipleri ve antrenörler içindir.', 'error');
                return;
            }

            if (!profile.organization_id) {
                await supabaseClient.auth.signOut();
                showToast('Organizasyon bilgisi bulunamadı.', 'error');
                return;
            }

            showToast('Giriş başarılı!', 'success');

            // Redirect to dashboard
            setTimeout(() => {
                window.location.href = 'dashboard.html';
            }, 500);

        } catch (error) {
            console.error('Login error:', error);

            if (error.message.includes('Email not confirmed')) {
                showToast('Lütfen mailinizden hesabınızı onaylayın', 'error');
            } else if (error.message.includes('Invalid login credentials')) {
                showToast('Email veya şifre hatalı', 'error');
            } else {
                showToast('Giriş hatası: ' + error.message, 'error');
            }
        } finally {
            loginBtn.disabled = false;
            loginBtn.querySelector('.btn-text').style.display = 'inline';
            loginBtn.querySelector('.btn-loader').style.display = 'none';
        }
    });
});
