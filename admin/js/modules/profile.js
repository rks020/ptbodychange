import { supabaseClient } from '../supabase-config.js';
import { showToast, formatDate } from '../utils.js';

export async function loadProfile() {
    const contentArea = document.getElementById('content-area');
    contentArea.innerHTML = `
        <div class="profile-container">
            <div id="profile-content" class="fade-in">
                <div class="loading-spinner"></div>
            </div>
        </div>

        <!-- Edit Profile Modal -->
        <div id="edit-profile-modal" class="modal">
            <div class="modal-content">
                <div class="modal-header" style="display: flex; justify-content: space-between; align-items: center;">
                    <h3>Profili Düzenle</h3>
                    <span class="close-modal" style="cursor: pointer; font-size: 28px; color: var(--text-secondary);">&times;</span>
                </div>
                <div class="modal-body">
                    <form id="edit-profile-form">
                        <div class="form-group">
                            <label>Ad</label>
                            <input type="text" id="edit-first-name" required>
                        </div>
                        <div class="form-group">
                            <label>Soyad</label>
                            <input type="text" id="edit-last-name" required>
                        </div>
                        <div class="form-group">
                            <label>Meslek</label>
                            <input type="text" id="edit-profession" placeholder="Mesleğiniz">
                        </div>
                        <div class="form-group">
                            <label>Yaş</label>
                            <input type="number" id="edit-age" placeholder="Yaşınız">
                        </div>
                        <div class="form-group">
                            <label>Hobiler</label>
                            <input type="text" id="edit-hobbies" placeholder="Örn: Futbol, yüzme">
                        </div>
                        <div class="form-actions">
                            <button type="button" class="btn btn-secondary close-modal-btn">İptal</button>
                            <button type="submit" class="btn btn-primary">Kaydet</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <!-- Pro Upgrade Modal -->
        <div id="pro-upgrade-modal" class="modal" style="overflow-y: auto; padding: 20px;">
            <div class="modal-content" style="max-width: 480px; max-height: 90vh; overflow-y: auto;">
                <div class="modal-header" style="position: relative; padding: 20px;">
                    <span class="close-modal close-pro-modal" style="position: absolute; right: 15px; top: 15px; cursor: pointer; font-size: 28px; color: #999; transition: color 0.3s;">&times;</span>
                    <h2 style="margin: 0; color: var(--neon-cyan); text-align: center;">Pro'ya Yükselt 🏆</h2>
                </div>
                <div class="modal-body" style="padding: 20px;">
                    <div style="background: linear-gradient(135deg, rgba(255, 215, 0, 0.1), rgba(33, 150, 243, 0.1)); padding: 15px; border-radius: 10px; margin-bottom: 20px; border: 2px solid rgba(255, 215, 0, 0.3); text-align: center;">
                        <div style="font-size: 36px; margin-bottom: 8px;">📱</div>
                        <h3 style="color: var(--neon-cyan); margin: 0 0 8px 0; font-size: 18px;">Mobil Uygulama Üzerinden Abone Olun</h3>
                        <p style="margin: 0; color: #ccc; line-height: 1.5; font-size: 14px;">Pro'ya geçmek için FitFlow mobil uygulamasını indirin ve abonelik satın alın. Web panelinden abonelik satın alınamaz.</p>
                    </div>

                    <h3 style="color: var(--primary-yellow); margin: 0 0 15px 0; text-align: center; font-size: 18px;">Pro vs Ücretsiz Karşılaştırma</h3>
                    
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                        <!-- Free Plan -->
                        <div style="background: rgba(33, 150, 243, 0.1); padding: 15px; border-radius: 10px; border: 2px solid rgba(33, 150, 243, 0.3);">
                            <div style="text-align: center; margin-bottom: 12px;">
                                <div style="font-size: 28px; margin-bottom: 6px;">🏅</div>
                                <h4 style="margin: 0; color: #2196F3; font-size: 16px;">Ücretsiz Paket</h4>
                                <p style="margin: 4px 0 0 0; color: #999; font-size: 12px;">30 Gün Deneme</p>
                            </div>
                            <ul style="list-style: none; padding: 0; margin: 0; color: #ccc; font-size: 13px;">
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ 10 Üye Limiti</li>
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ 2 Antrenör Limiti</li>
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ Temel Özellikler</li>
                                <li style="padding: 6px 0; color: #666;">✗ Sınırsız Üye</li>
                                <li style="padding: 6px 0; color: #666;">✗ Sınırsız Antrenör</li>
                                <li style="padding: 6px 0; color: #666;">✗ Gelişmiş Raporlar</li>
                                <li style="padding: 6px 0; color: #666;">✗ Öncelikli Destek</li>
                            </ul>
                        </div>

                        <!-- Pro Plan -->
                        <div style="background: linear-gradient(135deg, rgba(255, 215, 0, 0.1), rgba(33, 150, 243, 0.1)); padding: 15px; border-radius: 10px; border: 2px solid var(--primary-yellow); position: relative;">
                            <div style="position: absolute; top: -10px; right: 15px; background: var(--primary-yellow); color: #000; padding: 3px 10px; border-radius: 10px; font-size: 11px; font-weight: bold;">ÖNERİLEN</div>
                            <div style="text-align: center; margin-bottom: 12px;">
                                <div style="font-size: 28px; margin-bottom: 6px;">🏆</div>
                                <h4 style="margin: 0; color: var(--primary-yellow); font-size: 16px;">Pro Paket</h4>
                                <p style="margin: 4px 0 0 0; color: #999; font-size: 12px;">Aylık/Yıllık</p>
                            </div>
                            <ul style="list-style: none; padding: 0; margin: 0; color: #ccc;">
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ <strong style="color: var(--primary-yellow);">Sınırsız Üye</strong></li>
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ <strong style="color: var(--primary-yellow);">Sınırsız Antrenör</strong></li>
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ Tüm Temel Özellikler</li>
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ Gelişmiş Raporlar</li>
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ Öncelikli Destek</li>
                                <li style="padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05);">✓ Özel Antrenman Planları</li>
                                <li style="padding: 6px 0;">✓ API Erişimi</li>
                            </ul>
                        </div>
                    </div>

                    <div style="margin-top: 18px; padding: 12px; background: rgba(255, 215, 0, 0.05); border-left: 3px solid var(--primary-yellow); border-radius: 6px;">
                        <p style="margin: 0; color: #ccc; font-size: 13px; line-height: 1.5;">
                            <strong style="color: var(--primary-yellow);">💡 İpucu:</strong> Mobil uygulamayı App Store veya Google Play Store'dan indirerek hemen Pro'ya geçebilir ve tüm özelliklerin keyfini çıkarabilirsiniz.
                        </p>
                    </div>
                </div>
            </div>
        </div>

        <!-- Hidden File Input for Avatar Upload -->
        <input type="file" id="avatar-input" hidden accept="image/*">

        <style>
            .profile-container {
                max-width: 500px;
                margin: 0 auto;
                padding-bottom: 40px;
            }

            .profile-header {
                text-align: center;
                margin-bottom: 24px;
                position: relative;
            }

            .profile-avatar-large {
                width: 120px;
                height: 120px;
                background: linear-gradient(135deg, rgba(255, 215, 0, 0.2), rgba(0, 0, 0, 0.4));
                border: 2px solid var(--primary-yellow);
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 40px;
                color: var(--primary-yellow);
                margin: 0 auto 16px;
                position: relative;
            }
            
            .edit-badge {
                position: absolute;
                bottom: 0;
                right: 0;
                background: var(--primary-yellow);
                color: #000;
                width: 32px;
                height: 32px;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 16px;
                cursor: pointer;
            }

            .profile-name {
                font-size: 24px;
                font-weight: 700;
                color: var(--text-primary);
                margin-bottom: 4px;
            }

            .profile-role-badge {
                display: inline-block;
                background: rgba(33, 150, 243, 0.2);
                color: #2196F3;
                padding: 4px 12px;
                border-radius: 12px;
                font-size: 12px;
                font-weight: 600;
                margin-bottom: 8px;
            }

            .profile-subtitle {
                color: var(--primary-yellow);
                font-size: 14px;
                margin-bottom: 4px;
            }

            .profile-email {
                color: var(--text-secondary);
                font-size: 14px;
            }

            .profile-card {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 16px;
                padding: 20px;
                margin-bottom: 16px;
            }

            .info-row {
                display: flex;
                justify-content: space-between;
                padding: 12px 0;
                border-bottom: 1px solid rgba(255, 255, 255, 0.05);
            }

            .info-row:last-child {
                border-bottom: none;
            }

            .info-label {
                display: flex;
                align-items: center;
                gap: 8px;
                color: var(--text-secondary);
            }

            .info-value {
                color: var(--text-primary);
                font-weight: 500;
            }

            .package-header {
                display: flex;
                align-items: center;
                gap: 12px;
                margin-bottom: 12px;
            }

            .package-title {
                font-weight: 600;
                font-size: 16px;
            }

            .package-expiry {
                color: var(--text-secondary);
                font-size: 13px;
            }

            .stats-grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 16px;
                margin-top: 16px;
            }

            .stat-box {
                background: rgba(255, 255, 255, 0.05);
                border-radius: 12px;
                padding: 16px;
                text-align: center;
            }

            .stat-box-icon {
                font-size: 24px;
                margin-bottom: 8px;
                color: var(--primary-yellow);
            }

            .stat-box-label {
                font-size: 12px;
                color: var(--text-secondary);
                margin-bottom: 4px;
            }

            .stat-box-value {
                font-size: 20px;
                font-weight: 700;
                color: var(--text-primary);
            }

            .pro-upgrade-btn {
                width: 100%;
                background: var(--primary-yellow);
                color: #000;
                border: none;
                padding: 16px;
                border-radius: 12px;
                font-weight: 700;
                font-size: 16px;
                margin-top: 16px;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
                transition: transform 0.2s;
            }

            .pro-upgrade-btn:hover {
                transform: translateY(-2px);
            }

            .delete-account-link {
                display: block;
                text-align: center;
                color: #ff4444;
                margin-top: 24px;
                font-size: 12px;
                text-decoration: underline;
                cursor: pointer;
                background: none;
                border: none;
                width: 100%;
            }

            .edit-btn-top {
                position: absolute;
                top: 0;
                right: 0;
                background: rgba(255,255,255,0.1);
                border: none;
                color: var(--primary-yellow);
                width: 36px;
                height: 36px;
                border-radius: 12px;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
            }
        </style>
    `;

    await loadProfileData();
    setupEditModal();
}

async function loadProfileData() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        // 1. Fetch Profile & Org
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('*, organizations(*)')
            .eq('id', user.id)
            .single();

        // 2. Fetch Stats
        const orgId = profile.organization_id;

        // Members count (using members table for active programs/assigned)
        const { count: membersCount } = await supabaseClient
            .from('members') // Total members in org
            .select('id', { count: 'exact', head: true })
            .eq('organization_id', orgId);

        const { count: trainersCount } = await supabaseClient
            .from('profiles')
            .select('id', { count: 'exact', head: true })
            .eq('organization_id', orgId)
            .eq('role', 'trainer');

        renderProfile(user, profile, membersCount || 0, trainersCount || 0);

    } catch (error) {
        console.error('Error loading profile:', error);
        showToast('Profil yüklenirken hata oluştu', 'error');
    }
}

function renderProfile(user, profile, membersCount, trainersCount) {
    const container = document.getElementById('profile-content');
    const org = profile.organizations || {};
    const trialDaysLeft = getDaysLeft(org.trial_end_date);
    const initials = `${profile.first_name?.[0] || ''}${profile.last_name?.[0] || ''}`.toUpperCase();

    container.innerHTML = `
        <div class="profile-header">
            <button class="edit-btn-top" id="open-edit-modal">✏️</button>
            <div class="profile-avatar-large" style="${profile.avatar_url ? `background-image: url('${profile.avatar_url}'); background-size: cover; background-position: center; border: 2px solid var(--primary-yellow);` : ''}">
                ${profile.avatar_url ? '' : (initials || '👤')}
                <div class="edit-badge" id="edit-avatar-btn">📷</div>
            </div>
            <h1 class="profile-name">${profile.first_name || ''} ${profile.last_name || ''}</h1>
            <span class="profile-role-badge">${org.name || 'Admin'}</span>
            <div class="profile-subtitle">Salon Sahibi</div>
            <div class="profile-email">${user.email}</div>
        </div>

        <div class="profile-card">
            <div class="info-row">
                <div class="info-label">
                    <span>🎂</span> Yaş
                </div>
                <div class="info-value">${profile.age || '-'}</div>
            </div>
            <div class="info-row">
                <div class="info-label">
                    <span>🔍</span> Hobiler
                </div>
                <div class="info-value">${profile.hobbies || '-'}</div>
            </div>
        </div>

        <div class="profile-card">
            <div class="package-header">
                <div style="
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    width: 40px;
                    height: 40px;
                    border-radius: 12px;
                    background: ${org.subscription_tier === 'pro' ? 'linear-gradient(135deg, #FFD700, #2196F3)' : 'rgba(33, 150, 243, 0.2)'};
                    border: 2px solid ${org.subscription_tier === 'pro' ? '#FFD700' : '#2196F3'};
                ">
                    <span style="font-size: 20px;">${org.subscription_tier === 'pro' ? '🏆' : '🏅'}</span>
                </div>
                <div>
                    <div class="package-title">${org.subscription_tier === 'free' ? 'Ücretsiz Paket' : 'Pro Paket'}</div>
                    <div class="package-expiry">${trialDaysLeft > 0 ? `Deneme ${trialDaysLeft} gün sonra bitiyor` : 'Süre doldu'}</div>
                </div>
            </div>
            
            <div class="stats-grid">
                <div class="stat-box">
                    <div class="stat-box-icon">👥</div>
                    <div class="stat-box-label">Üye</div>
                    <div class="stat-box-value">${membersCount} <span style="font-size: 12px; color: #666;">/ 10</span></div>
                </div>
                <div class="stat-box">
                    <div class="stat-box-icon">💪</div>
                    <div class="stat-box-label">Antrenör</div>
                    <div class="stat-box-value">${trainersCount} <span style="font-size: 12px; color: #666;">/ 2</span></div>
                </div>
            </div>
        </div>

        <button class="pro-upgrade-btn">
            ⬆ Pro'ya Yükselt
        </button>

        <button id="delete-account-btn" class="delete-account-link">
            Hesabı Sil
        </button>
    `;

    // Attach User Data to Edit Form for easy access
    document.getElementById('edit-first-name').value = profile.first_name || '';
    document.getElementById('edit-last-name').value = profile.last_name || '';
    document.getElementById('edit-profession').value = profile.profession || '';
    document.getElementById('edit-age').value = profile.age || '';
    document.getElementById('edit-hobbies').value = profile.hobbies || '';

    // Setup Delete Listener
    document.getElementById('delete-account-btn').addEventListener('click', () => handleDeleteAccount(user.id));

    // Setup Pro Upgrade Modal
    setupProUpgradeModal();

    // Setup Edit Button Listener
    document.getElementById('open-edit-modal').addEventListener('click', () => {
        const modal = document.getElementById('edit-profile-modal');
        modal.style.display = 'flex';
        setTimeout(() => modal.classList.add('show'), 10);
    });

    // Setup Avatar Upload - moved here from setupEditModal
    const avatarInput = document.getElementById('avatar-input');
    const avatarBtn = document.getElementById('edit-avatar-btn');

    if (avatarBtn && avatarInput) {
        avatarBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            avatarInput.click();
        });

        avatarInput.addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if (!file) return;

            try {
                showToast('Fotoğraf yükleniyor...', 'info');

                const fileExt = file.name.split('.').pop();
                const fileName = `${user.id}-${Math.random()}.${fileExt}`;
                const filePath = `${fileName}`;

                const { error: uploadError } = await supabaseClient.storage
                    .from('avatars')
                    .upload(filePath, file);

                if (uploadError) throw uploadError;

                const { data: { publicUrl } } = supabaseClient.storage
                    .from('avatars')
                    .getPublicUrl(filePath);

                const { error: updateError } = await supabaseClient
                    .from('profiles')
                    .update({ avatar_url: publicUrl })
                    .eq('id', user.id);

                if (updateError) throw updateError;

                showToast('Profil fotoğrafı güncellendi', 'success');
                loadProfileData(); // Refresh UI
            } catch (error) {
                console.error('Avatar upload error:', error);
                showToast('Fotoğraf yüklenirken hata oluştu', 'error');
            }
        });
    }
}

function setupEditModal() {
    const modal = document.getElementById('edit-profile-modal');
    const closeBtns = document.querySelectorAll('.close-modal, .close-modal-btn');
    const form = document.getElementById('edit-profile-form');

    const closeModal = () => {
        modal.classList.remove('show');
        setTimeout(() => modal.style.display = 'none', 300);
    };

    closeBtns.forEach(btn => btn.onclick = closeModal);
    window.onclick = (e) => { if (e.target == modal) closeModal(); };

    form.onsubmit = async (e) => {
        e.preventDefault();
        const btn = form.querySelector('button[type="submit"]');
        btn.textContent = 'Kaydediliyor...';
        btn.disabled = true;

        try {
            const firstName = document.getElementById('edit-first-name').value;
            const lastName = document.getElementById('edit-last-name').value;
            const profession = document.getElementById('edit-profession').value;
            const age = document.getElementById('edit-age').value;
            const hobbies = document.getElementById('edit-hobbies').value;

            const { data: { user } } = await supabaseClient.auth.getUser();

            const { error } = await supabaseClient
                .from('profiles')
                .update({
                    first_name: firstName,
                    last_name: lastName,
                    profession: profession,
                    age: age ? parseInt(age) : null,
                    hobbies: hobbies
                })
                .eq('id', user.id);

            if (error) throw error;

            showToast('Profil başarıyla güncellendi', 'success');
            closeModal();
            loadProfileData(); // Refresh UI

            // Update Header Name immediately
            const headerName = document.getElementById('user-name');
            if (headerName) headerName.textContent = `${firstName} ${lastName}`;

        } catch (error) {
            console.error(error);
            showToast('Güncelleme hatası: ' + error.message, 'error');
        } finally {
            btn.textContent = 'Kaydet';
            btn.disabled = false;
        }
    };
}

async function handleDeleteAccount(userId) {
    if (confirm('Hesabınızı silmek istediğinize emin misiniz? Bu işlem geri alınamaz!')) {
        try {
            const { error } = await supabaseClient.functions.invoke('delete-user', {
                body: { user_id: userId }
            });

            if (error) throw error;

            showToast('Hesabınız başarıyla silindi.', 'success');
            setTimeout(() => {
                supabaseClient.auth.signOut();
                window.location.href = 'login.html';
            }, 1500);

        } catch (error) {
            console.error('Delete error:', error);
            showToast('Hesap silinirken hata oluştu', 'error');
        }
    }
}

function getDaysLeft(dateString) {
    if (!dateString) return 0;
    const end = new Date(dateString);
    const now = new Date();
    const diff = end - now;
    return Math.floor(diff / (1000 * 60 * 60 * 24));
}

function setupProUpgradeModal() {
    const modal = document.getElementById('pro-upgrade-modal');
    const proUpgradeBtn = document.querySelector('.pro-upgrade-btn');
    const closeBtns = document.querySelectorAll('.close-pro-modal');

    const closeModal = () => {
        modal.classList.remove('show');
        setTimeout(() => modal.style.display = 'none', 300);
    };

    // Open modal on button click
    if (proUpgradeBtn) {
        proUpgradeBtn.addEventListener('click', () => {
            modal.style.display = 'flex';
            setTimeout(() => modal.classList.add('show'), 10);
        });
    }

    // Close modal handlers
    closeBtns.forEach(btn => btn.onclick = closeModal);
    window.addEventListener('click', (e) => {
        if (e.target == modal) closeModal();
    });
}

