import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';
import { loadDashboard } from './modules/dashboard.js';
import { getCityNames, getDistricts } from './cities.js';

// DOM Elements
let loginForm, registerForm, loginBtn, registerBtn;
let loginEmail, loginPassword, registerEmail, registerPassword;
let registerFirstname, registerLastname, registerGymname, registerCity, registerDistrict;

// Initialize Auth
export function initAuth() {
    console.log('Initializing Auth...');

    // 1. Critical: Get Login Elements & Attach Listeners FIRST
    try {
        loginForm = document.getElementById('login-form-element');
        loginBtn = document.getElementById('login-btn');
        loginEmail = document.getElementById('login-email');
        loginPassword = document.getElementById('login-password');

        if (loginForm) {
            loginForm.addEventListener('submit', handleLogin);
            console.log('Login listener attached.');
        } else {
            console.error('Login form element not found!');
        }

        // Toggle password visibility
        document.querySelectorAll('.toggle-password').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault(); // Prevent focus loss
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
            console.log('Password toggle attached.');
        });

    } catch (e) {
        console.error('Error initializing login:', e);
    }

    // 2. Register Elements (Wrap in try-catch so it doesn't kill login if it fails)
    try {
        registerForm = document.getElementById('register-form-element');
        registerBtn = document.getElementById('register-btn');
        registerEmail = document.getElementById('register-email');
        registerPassword = document.getElementById('register-password');
        registerFirstname = document.getElementById('register-firstname');
        registerLastname = document.getElementById('register-lastname');
        registerGymname = document.getElementById('register-gymname');
        registerCity = document.getElementById('register-city');
        registerDistrict = document.getElementById('register-district');

        if (registerForm) {
            registerForm.addEventListener('submit', handleRegister);
        }

        // City Logic
        if (registerCity && registerDistrict) {
            // Populate cities dropdown with all 81 cities
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
        }
    } catch (e) {
        console.error('Error initializing registration:', e);
    }

    // 3. Form Toggles
    try {
        document.getElementById('show-register')?.addEventListener('click', (e) => {
            e.preventDefault();
            document.getElementById('login-form').style.display = 'none';
            document.getElementById('register-form').style.display = 'block';
        });

        document.getElementById('show-login')?.addEventListener('click', (e) => {
            e.preventDefault();
            document.getElementById('register-form').style.display = 'none';
            document.getElementById('login-form').style.display = 'block';
        });
    } catch (e) {
        console.error('Error initializing form toggles:', e);
    }

    // 4. Check existing session
    checkSession();
}

// Check Session
async function checkSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();

    if (session) {
        // Verify user role
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('role, organization_id, first_name, last_name')
            .eq('id', session.user.id)
            .single();

        if (profile && (profile.role === 'owner' || profile.role === 'trainer') && profile.organization_id) {
            showDashboard(session.user, profile);
        } else {
            // Invalid role or incomplete profile
            await supabaseClient.auth.signOut();
            showToast('Bu panel sadece salon sahipleri ve antrenörler içindir.', 'error');
        }
    }
}

// Handle Login
// Handle Login
async function handleLogin(e) {
    e.preventDefault();

    const email = loginEmail.value.trim();
    const password = loginPassword.value.trim();

    // Reset previous errors
    removeError(loginEmail);
    removeError(loginPassword);

    if (!email || !password) {
        showToast('Lütfen email ve şifre girin', 'error');
        if (!email) showError(loginEmail);
        if (!password) showError(loginPassword);
        return;
    }

    setLoading(loginBtn, true);

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
        showDashboard(data.user, profile);

    } catch (error) {
        console.error('Login error:', error);

        // Visual feedback for error
        showError(loginEmail);
        showError(loginPassword);

        if (error.message.includes('Email not confirmed')) {
            showToast('Lütfen mailinizden hesabınızı onaylayın', 'error');
        } else if (error.message.includes('Invalid login credentials')) {
            showToast('Email veya şifre hatalı', 'error');
        } else {
            showToast('Giriş hatası: ' + error.message, 'error');
        }
    } finally {
        setLoading(loginBtn, false);
    }
}

// Helper: Show Input Error
function showError(input) {
    input.classList.add('input-error');
    // Remove error on next input
    input.addEventListener('input', () => {
        input.classList.remove('input-error');
    }, { once: true });
}

function removeError(input) {
    input.classList.remove('input-error');
}

// Handle Register
async function handleRegister(e) {
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

    setLoading(registerBtn, true);

    try {
        // Check gym name availability
        const { data: isAvailable } = await supabaseClient.rpc('check_organization_name_availability', {
            org_name: gymname
        });

        if (isAvailable === false) {
            showToast('Bu salon adı zaten kullanımda', 'error');
            setLoading(registerBtn, false);
            return;
        }

        // Sign up
        const { data, error } = await supabaseClient.auth.signUp({
            email,
            password,
            options: {
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

        // Complete registration (create organization)
        if (data.session) {
            await supabaseClient.rpc('complete_owner_registration', {
                gym_name: gymname,
                city,
                district,
                first_name: firstname,
                last_name: lastname
            });

            showToast('Kayıt başarılı!', 'success');

            // Get profile
            const { data: profile } = await supabaseClient
                .from('profiles')
                .select('role, organization_id, first_name, last_name')
                .eq('id', data.user.id)
                .single();

            showDashboard(data.user, profile);
        } else {
            // Email verification required
            showToast('Kayıt başarılı! Lütfen email adresinizi kontrol edin ve hesabınızı onaylayın.', 'success');
            document.getElementById('register-form').style.display = 'none';
            document.getElementById('login-form').style.display = 'block';
        }

    } catch (error) {
        console.error('Register error:', error);
        showToast('Kayıt hatası: ' + error.message, 'error');
    } finally {
        setLoading(registerBtn, false);
    }
}

// Show Dashboard
function showDashboard(user, profile) {
    document.getElementById('auth-modal').classList.remove('active');
    document.getElementById('dashboard').style.display = 'grid';

    // Set user info
    const userName = `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || user.email;
    document.getElementById('user-name').textContent = userName;

    // Load dashboard content
    loadDashboard();
}

// Logout
export async function logout() {
    await supabaseClient.auth.signOut();
    document.getElementById('dashboard').style.display = 'none';
    document.getElementById('auth-modal').classList.add('active');
    document.getElementById('register-form').style.display = 'none';
    document.getElementById('login-form').style.display = 'block';
    showToast('Çıkış yapıldı', 'success');
}

// Set Loading State
function setLoading(button, isLoading) {
    if (isLoading) {
        button.disabled = true;
        button.querySelector('.btn-text').style.display = 'none';
        button.querySelector('.btn-loader').style.display = 'inline';
    } else {
        button.disabled = false;
        button.querySelector('.btn-text').style.display = 'inline';
        button.querySelector('.btn-loader').style.display = 'none';
    }
}
