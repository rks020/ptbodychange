import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';
import { loadDashboard } from './modules/dashboard.js';

// Turkey Cities Data
const TURKEY_CITIES = {
    "İstanbul": ["Adalar", "Arnavutköy", "Ataşehir", "Avcılar", "Bağcılar", "Bahçelievler", "Bakırköy", "Başakşehir", "Bayrampaşa", "Beşiktaş", "Beykoz", "Beylikdüzü", "Beyoğlu", "Büyükçekmece", "Çatalca", "Çekmeköy", "Esenler", "Esenyurt", "Eyüpsultan", "Fatih", "Gaziosmanpaşa", "Güngören", "Kadıköy", "Kağıthane", "Kartal", "Küçükçekmece", "Maltepe", "Pendik", "Sancaktepe", "Sarıyer", "Silivri", "Sultanbeyli", "Sultangazi", "Şile", "Şişli", "Tuzla", "Ümraniye", "Üsküdar", "Zeytinburnu"],
    "Ankara": ["Akyurt", "Altındağ", "Ayaş", "Bala", "Beypazarı", "Çamlıdere", "Çankaya", "Çubuk", "Elmadağ", "Etimesgut", "Evren", "Gölbaşı", "Güdül", "Haymana", "Kahramankazan", "Kalecik", "Keçiören", "Kızılcahamam", "Mamak", "Nallıhan", "Polatlı", "Pursaklar", "Sincan", "Şereflikoçhisar", "Yenimahalle"],
    "İzmir": ["Aliağa", "Balçova", "Bayındır", "Bayraklı", "Bergama", "Beydağ", "Bornova", "Buca", "Çeşme", "Çiğli", "Dikili", "Foça", "Gaziemir", "Güzelbahçe", "Karabağlar", "Karaburun", "Karşıyaka", "Kemalpaşa", "Kınık", "Kiraz", "Konak", "Menderes", "Menemen", "Narlıdere", "Ödemiş", "Seferihisar", "Selçuk", "Tire", "Torbalı", "Urla"],
    // Add more cities as needed...
};

// DOM Elements
let loginForm, registerForm, loginBtn, registerBtn;
let loginEmail, loginPassword, registerEmail, registerPassword;
let registerFirstname, registerLastname, registerGymname, registerCity, registerDistrict;

// Initialize Auth
export function initAuth() {
    // Get DOM elements
    loginForm = document.getElementById('login-form-element');
    registerForm = document.getElementById('register-form-element');
    loginBtn = document.getElementById('login-btn');
    registerBtn = document.getElementById('register-btn');

    loginEmail = document.getElementById('login-email');
    loginPassword = document.getElementById('login-password');
    registerEmail = document.getElementById('register-email');
    registerPassword = document.getElementById('register-password');
    registerFirstname = document.getElementById('register-firstname');
    registerLastname = document.getElementById('register-lastname');
    registerGymname = document.getElementById('register-gymname');
    registerCity = document.getElementById('register-city');
    registerDistrict = document.getElementById('register-district');

    // Populate cities dropdown
    Object.keys(TURKEY_CITIES).forEach(city => {
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

        if (selectedCity && TURKEY_CITIES[selectedCity]) {
            TURKEY_CITIES[selectedCity].forEach(district => {
                const option = document.createElement('option');
                option.value = district;
                option.textContent = district;
                registerDistrict.appendChild(option);
            });
        }
    });

    // Toggle password visibility
    document.querySelectorAll('.toggle-password').forEach(btn => {
        btn.addEventListener('click', () => {
            const targetId = btn.getAttribute('data-target');
            const input = document.getElementById(targetId);
            if (input.type === 'password') {
                input.type = 'text';
                btn.querySelector('.icon').textContent = '🙈';
            } else {
                input.type = 'password';
                btn.querySelector('.icon').textContent = '👁️';
            }
        });
    });

    // Form toggle
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

    // Form submissions
    loginForm.addEventListener('submit', handleLogin);
    registerForm.addEventListener('submit', handleRegister);

    // Check existing session
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
