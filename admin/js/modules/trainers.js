import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

export async function loadTrainers() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Antrenörler</h2>
            <button class="btn btn-primary" id="add-trainer-btn">+ Yeni Antrenör Ekle</button>
        </div>
        
        <div class="trainers-list" id="trainers-list">
            <p>Yükleniyor...</p>
        </div>

        <!-- Add Trainer Modal -->
        <div id="add-trainer-modal" class="modal">
            <div class="modal-content" style="max-width: 500px;">
                <h2>Yeni Antrenör Ekle</h2>
                <form id="add-trainer-form">
                    <div class="form-group">
                        <label>Ad</label>
                        <input type="text" id="trainer-firstname" required>
                    </div>
                    <div class="form-group">
                        <label>Soyad</label>
                        <input type="text" id="trainer-lastname" required>
                    </div>
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="trainer-email" required>
                    </div>
                    <div class="form-group">
                        <label>Geçici Şifre</label>
                        <input type="text" id="trainer-password" required minlength="6" placeholder="En az 6 karakter">
                    </div>
                    <div class="form-group">
                        <label>Uzmanlık (opsiyonel)</label>
                        <input type="text" id="trainer-specialty" placeholder="Örn: PT, Diyetisyen">
                    </div>
                    <div class="form-actions">
                        <button type="button" class="btn btn-secondary" id="cancel-trainer-btn">İptal</button>
                        <button type="submit" class="btn btn-primary" id="save-trainer-btn">
                            <span class="btn-text">Kaydet</span>
                            <span class="btn-loader" style="display:none;">⏳</span>
                        </button>
                    </div>
                </form>
            </div>
        </div>

    /* Styles removed: using admin/css/styles.css */
    `;

    // Load trainers
    await loadTrainersList();

    // Setup event listeners
    document.getElementById('add-trainer-btn').addEventListener('click', () => {
        document.getElementById('add-trainer-modal').classList.add('active');
    });

    document.getElementById('cancel-trainer-btn').addEventListener('click', () => {
        document.getElementById('add-trainer-modal').classList.remove('active');
        document.getElementById('add-trainer-form').reset();
    });

    document.getElementById('add-trainer-form').addEventListener('submit', handleAddTrainer);
}

async function loadTrainersList() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        const { data: trainers, error } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .eq('role', 'trainer')
            .order('created_at', { ascending: false });

        if (error) throw error;

        const listContainer = document.getElementById('trainers-list');

        if (!trainers || trainers.length === 0) {
            listContainer.innerHTML = '<p>Henüz antrenör eklenmemiş.</p>';
            return;
        }

        listContainer.innerHTML = trainers.map(trainer => `
            <div class="trainer-card">
                <div class="trainer-header">
                    <div class="trainer-avatar">
                        ${(trainer.first_name?.[0] || 'T').toUpperCase()}
                    </div>
                    <div class="trainer-info">
                        <h3>${trainer.first_name} ${trainer.last_name}</h3>
                        <p>${trainer.specialty || 'Antrenör'}</p>
                    </div>
                </div>
                <div class="trainer-details" style="flex: 1;">
                    <p style="font-size: 14px; color: var(--text-secondary);">
                        📧 ${trainer.id.slice(0, 8)}...
                    </p>
                </div>
                <div class="trainer-actions">
                    <button class="btn btn-small btn-secondary" onclick="editTrainer('${trainer.id}')">
                        Düzenle
                    </button>
                    <button class="btn btn-small btn-danger" onclick="deleteTrainer('${trainer.id}')">
                        Sil
                    </button>
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading trainers:', error);
        showToast('Antrenörler yüklenirken hata oluştu', 'error');
    }
}

async function handleAddTrainer(e) {
    e.preventDefault();

    const firstname = document.getElementById('trainer-firstname').value.trim();
    const lastname = document.getElementById('trainer-lastname').value.trim();
    const email = document.getElementById('trainer-email').value.trim();
    const password = document.getElementById('trainer-password').value.trim();
    const specialty = document.getElementById('trainer-specialty').value.trim();
    const saveBtn = document.getElementById('save-trainer-btn');

    if (!firstname || !lastname || !email || !password) {
        showToast('Lütfen gerekli alanları doldurun', 'error');
        return;
    }

    if (password.length < 6) {
        showToast('Şifre en az 6 karakter olmalıdır', 'error');
        return;
    }

    // Set loading
    saveBtn.disabled = true;
    saveBtn.querySelector('.btn-text').style.display = 'none';
    saveBtn.querySelector('.btn-loader').style.display = 'inline';

    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) {
            showToast('Organizasyon bilgisi bulunamadı', 'error');
            return;
        }

        // Call Edge Function
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
        document.getElementById('add-trainer-modal').classList.remove('active');
        document.getElementById('add-trainer-form').reset();
        await loadTrainersList();

    } catch (error) {
        console.error('Error adding trainer:', error);
        showToast('Antrenör eklenirken hata: ' + (error.message || 'Bilinmeyen hata'), 'error');
    } finally {
        saveBtn.disabled = false;
        saveBtn.querySelector('.btn-text').style.display = 'inline';
        saveBtn.querySelector('.btn-loader').style.display = 'none';
    }
}

// Global functions for edit/delete (could be improved with event delegation)
window.editTrainer = async (id) => {
    showToast('Düzenleme özelliği yakında eklenecek', 'info');
};

window.deleteTrainer = async (id) => {
    if (!confirm('Bu antrenörü silmek istediğinizden emin misiniz?')) return;

    try {
        const { error } = await supabaseClient
            .from('profiles')
            .delete()
            .eq('id', id);

        if (error) throw error;

        showToast('Antrenör silindi', 'success');
        await loadTrainersList();

    } catch (error) {
        console.error('Error deleting trainer:', error);
        showToast('Antrenör silinirken hata oluştu', 'error');
    }
};
