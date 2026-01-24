import { supabaseClient } from './supabase-config.js';
import { getCityNames, getDistricts } from './cities.js';

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
        window.location.href = 'dashboard.html';
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkSession();

    const registerForm = document.getElementById('register-form-element');
    const registerBtn = document.getElementById('register-btn');
    const registerEmail = document.getElementById('register-email');
    const registerPassword = document.getElementById('register-password');
    const registerFirstname = document.getElementById('register-firstname');
    const registerLastname = document.getElementById('register-lastname');
    const registerGymname = document.getElementById('register-gymname');
    const registerCity = document.getElementById('register-city');
    const registerDistrict = document.getElementById('register-district');

    // Populate cities
    const cities = getCityNames();
    cities.forEach(city => {
        const option = document.createElement('option');
        option.value = city;
        option.textContent = city;
        registerCity.appendChild(option);
    });

    // City change handler
    registerCity.addEventListener('change', (e) => {
        const selectedCity = e.target.value;
        registerDistrict.disabled = !selectedCity;
        registerDistrict.innerHTML = '<option value="">Seçiniz</option>';

        if (selectedCity) {
            const districts = getDistricts(selectedCity);
            districts.forEach(district => {
                const option = document.createElement('option');
                option.value = district;
                option.textContent = district;
                registerDistrict.appendChild(option);
            });
        }
    });

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

    // Handle registration
    registerForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const email = registerEmail.value.trim();
        const password = registerPassword.value.trim();
        const firstname = registerFirstname.value.trim();
        const lastname = registerLastname.value.trim();
        const gymname = registerGymname.value.trim();
        const city = registerCity.value;
        const district = registerDistrict.value;

        // Validation
        if (!email || !password || !firstname || !lastname || !gymname || !city || !district) {
            showToast('Lütfen tüm alanları doldurun', 'error');
            return;
        }

        if (password.length < 6) {
            showToast('Şifre en az 6 karakter olmalıdır', 'error');
            return;
        }

        if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
            showToast('Şifre en az bir özel karakter içermelidir', 'error');
            return;
        }

        // Show loading
        registerBtn.disabled = true;
        registerBtn.querySelector('.btn-text').style.display = 'none';
        registerBtn.querySelector('.btn-loader').style.display = 'inline';

        try {
            // Check gym name availability
            const { data: isAvailable } = await supabaseClient.rpc('check_organization_name_availability', {
                org_name: gymname
            });

            if (isAvailable === false) {
                showToast('Bu salon adı zaten kullanımda', 'error');
                registerBtn.disabled = false;
                registerBtn.querySelector('.btn-text').style.display = 'inline';
                registerBtn.querySelector('.btn-loader').style.display = 'none';
                return;
            }

            // Sign up
            const { data, error } = await supabaseClient.auth.signUp({
                email,
                password,
                options: {
                    emailRedirectTo: `${window.location.origin}/confirm.html?platform=web`,
                    data: {
                        first_name: firstname,
                        last_name: lastname,
                        role: 'owner',
                        gym_name: gymname,
                        city,
                        district,
                        password_changed: true
                    }
                }
            });

            if (error) throw error;

            // Check if user already exists (Supabase returns fake success for existing users if user enumeration protection is on)
            if (data.user && data.user.identities && data.user.identities.length === 0) {
                throw new Error('User already registered');
            }

            // Complete registration
            if (data.session) {
                await supabaseClient.rpc('complete_owner_registration', {
                    gym_name: gymname,
                    city,
                    district,
                    first_name: firstname,
                    last_name: lastname
                });

                showToast('Kayıt başarılı!', 'success');

                setTimeout(() => {
                    window.location.href = 'dashboard.html';
                }, 1000);
            } else {
                showToast('Kayıt başarılı! Lütfen email adresinizi kontrol edin ve hesabınızı onaylayın.', 'success');

                setTimeout(() => {
                    window.location.href = 'login.html';
                }, 2000);
            }

        } catch (error) {
            console.error('Register error:', error);

            if (error.message === 'User already registered' || error.message.includes('already registered')) {
                showToast('Bu email adresi sistemde kayıtlıdır.', 'error');
            } else {
                showToast('Kayıt hatası: ' + error.message, 'error');
            }
        } finally {
            registerBtn.disabled = false;
            registerBtn.querySelector('.btn-text').style.display = 'inline';
            registerBtn.querySelector('.btn-loader').style.display = 'none';
        }
    });
});
