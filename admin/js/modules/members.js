import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

export async function loadMembers() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Üyeler</h2>
            <button class="btn btn-primary" id="add-member-btn">+ Yeni Üye Ekle</button>
        </div>
        
        <div class="search-bar">
            <input type="text" id="member-search" placeholder="Üye ara...">
        </div>

        <div class="members-list" id="members-list">
            <p>Yükleniyor...</p>
        </div>
    `;

    // Load members
    await loadMembersList();

    // Setup event listeners
    document.getElementById('add-member-btn').addEventListener('click', () => {
        window.location.href = 'add-member.html';
    });

    // Search functionality
    const searchInput = document.getElementById('member-search');
    let debounceTimer;

    searchInput.addEventListener('input', (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
            loadMembersList(e.target.value);
        }, 500);
    });
}

async function loadMembersList(searchQuery = '') {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        let query = supabaseClient
            .from('members')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .order('created_at', { ascending: false });

        if (searchQuery) {
            query = query.or(`name.ilike.%${searchQuery}%,email.ilike.%${searchQuery}%`);
        }

        const { data: members, error } = await query;

        if (error) throw error;

        const listContainer = document.getElementById('members-list');
        if (!listContainer) return; // Stop if user navigated away

        if (!members || members.length === 0) {
            listContainer.innerHTML = '<p>Üye bulunamadı.</p>';
            return;
        }

        listContainer.innerHTML = members.map(member => `
            <div class="member-card" onclick="editMember('${member.id}')" style="cursor: pointer;">
                <div class="member-header">
                    <div class="member-avatar">
                        ${(member.name?.[0] || 'Ü').toUpperCase()}
                    </div>
                    <div class="member-info">
                        <h3>${member.name}</h3>
                        <p>${member.email || '-'}</p>
                        <p style="font-size: 11px; color: #888;">Paket: ${member.subscription_package || '-'}</p>
                        <p style="font-size: 11px; color: #888;">Ders: ${member.session_count || 0}</p>
                    </div>
                </div>

                <div class="member-actions">
                    <button class="btn btn-small btn-secondary" onclick="event.stopPropagation(); editMember('${member.id}')">
                        Düzenle
                    </button>
                    <button class="btn btn-small btn-danger" onclick="event.stopPropagation(); deleteMember('${member.id}')">
                        Sil
                    </button>
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading members:', error);
        showToast('Üyeler yüklenirken hata oluştu: ' + (error.message || 'Bilinmeyen hata'), 'error');
    }
}

// Global functions
window.editMember = async (id) => {
    window.location.href = `edit-member.html?id=${id}`;
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

window.deleteMember = async (id) => {
    showConfirmation('Üyeyi Sil', 'Bu üyeyi ve tüm verilerini kalıcı olarak silmek istediğinizden emin misiniz?', async () => {
        try {
            showToast('Siliniyor...', 'info');

            // Call Edge Function to delete Auth User + Profile
            const { data, error } = await supabaseClient.functions.invoke('delete-user', {
                body: { user_id: id }
            });

            if (error) {
                console.error('Edge Function Error:', error);
                // Fallback: Delete from profiles directly if function fails (might leave auth user orphan)
                const { error: dbError } = await supabaseClient
                    .from('profiles')
                    .delete()
                    .eq('id', id);

                if (dbError) throw dbError;
            }

            showToast('Üye başarıyla silindi', 'success');

            // Refresh list
            const searchInput = document.getElementById('member-search');
            await loadMembersList(searchInput ? searchInput.value : '');

        } catch (error) {
            console.error('Error deleting member:', error);
            showToast('Üye silinirken hata oluştu: ' + error.message, 'error');
        }
    });
};
