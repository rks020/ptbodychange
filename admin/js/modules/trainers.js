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
    `;

    // Load trainers
    await loadTrainersList();

    // Setup event listeners
    document.getElementById('add-trainer-btn').addEventListener('click', () => {
        window.location.href = 'add-trainer.html';
    });
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
        if (!listContainer) return; // Stop if user navigated away

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

// Global functions for edit/delete
window.editTrainer = async (id) => {
    window.location.href = `edit-trainer.html?id=${id}`;
};

// Custom Modal Helper
function showConfirmation(title, message, onConfirm) {
    const modal = document.getElementById('confirm-modal');
    if (!modal) return;

    document.getElementById('confirm-title').textContent = title;
    document.getElementById('confirm-message').textContent = message;

    modal.classList.add('active');

    // Clean up old listeners
    const yesBtn = document.getElementById('confirm-yes');
    const cancelBtn = document.getElementById('confirm-cancel');
    const newYesBtn = yesBtn.cloneNode(true);
    const newCancelBtn = cancelBtn.cloneNode(true);

    yesBtn.parentNode.replaceChild(newYesBtn, yesBtn);
    cancelBtn.parentNode.replaceChild(newCancelBtn, cancelBtn);

    newYesBtn.addEventListener('click', async () => {
        modal.classList.remove('active');
        await onConfirm();
    });

    newCancelBtn.addEventListener('click', () => {
        modal.classList.remove('active');
    });
}

window.deleteTrainer = async (id) => {
    showConfirmation('Antrenörü Sil', 'Bu antrenörü ve hesabını kalıcı olarak silmek istediğinizden emin misiniz?', async () => {
        try {
            showToast('Siliniyor...', 'info');

            const { data, error } = await supabaseClient.functions.invoke('delete-user', {
                body: { user_id: id }
            });

            if (error) {
                console.error('Edge Function Error:', error);
                throw error;
            }

            showToast('Antrenör başarıyla silindi', 'success');
            await loadTrainersList();

        } catch (error) {
            console.error('Error deleting trainer:', error);
            showToast('Antrenör silinirken hata oluştu: ' + error.message, 'error');
        }
    });
};
