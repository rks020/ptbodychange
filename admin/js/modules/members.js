import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

let currentFilter = 'my_members'; // my_members, multisport, all

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

        <!-- Filter Buttons -->
        <div class="filter-tabs" style="display: flex; gap: 10px; margin-bottom: 20px;">
            <button class="btn btn-filter active" data-filter="my_members" style="flex:1;">Benim</button>
            <button class="btn btn-filter" data-filter="multisport" style="flex:1;">Multisport</button>
            <button class="btn btn-filter" data-filter="all" style="flex:1;">Tümü</button>
        </div>

        <div class="members-list" id="members-list">
            <p>Yükleniyor...</p>
        </div>
    `;

    // Filter Click Handlers
    document.querySelectorAll('.btn-filter').forEach(btn => {
        btn.addEventListener('click', (e) => {
            // Update UI
            document.querySelectorAll('.btn-filter').forEach(b => b.classList.remove('active', 'btn-primary'));
            document.querySelectorAll('.btn-filter').forEach(b => b.style.backgroundColor = '#333');

            e.target.classList.add('active');
            e.target.style.backgroundColor = '#FFD700';
            e.target.style.color = 'black';

            // Update Logic
            currentFilter = e.target.getAttribute('data-filter');
            loadMembersList(document.getElementById('member-search').value);
        });
    });

    // Initialize Filter UI (Default My Members)
    const defaultBtn = document.querySelector('[data-filter="my_members"]');
    if (defaultBtn) {
        defaultBtn.style.backgroundColor = '#FFD700';
        defaultBtn.style.color = 'black';
    }

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

    // Setup Modals
    setupPaymentModal();
}

async function loadMembersList(searchQuery = '') {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id, role')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        let query = supabaseClient
            .from('members')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .order('created_at', { ascending: false });

        // Apply Filters
        if (currentFilter === 'my_members') {
            query = query.eq('trainer_id', user.id);
        } else if (currentFilter === 'multisport') {
            query = query.eq('is_multisport', true);
            // If Trainer, verify visibility rule
            if (profile.role === 'trainer') {
                query = query.eq('trainer_id', user.id);
            }
        } else if (currentFilter === 'all') {
            // No extra filter, unless we want to enforce strict RLS (which Supabase does anyway)
            // But logic-wise "All" shows everyone.
        }

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
            <div class="member-card" style="position: relative; padding-bottom: 50px;">
                <div class="member-header" onclick="editMember('${member.id}')" style="cursor: pointer;">
                    <div class="member-avatar">
                        ${(member.name?.[0] || 'Ü').toUpperCase()}
                    </div>
                    <div class="member-info">
                        <h3>${member.name}</h3>
                        <p>${member.email || '-'}</p>
                        <p style="font-size: 11px; color: #888;">Paket: ${member.subscription_package || '-'}</p>
                        <p style="font-size: 11px; color: #888;">Ders: ${member.session_count || 0}</p>
                        ${member.is_multisport ? '<span style="font-size: 10px; color: #3b82f6; background: rgba(59,130,246,0.1); padding: 2px 4px; border-radius: 4px;">Multisport</span>' : ''}
                    </div>
                </div>

                <div class="member-actions" style="position: absolute; bottom: 10px; right: 10px; display: flex; gap: 8px;">
                    <button class="btn btn-small btn-success" onclick="event.stopPropagation(); showPaymentModal('${member.id}', '${member.name.replace(/'/g, "\\'")}')" title="Ödeme Al">
                        💰
                    </button>
                    <button class="btn btn-small btn-secondary" onclick="event.stopPropagation(); editMember('${member.id}')">
                        Düzenle
                    </button>
                    <button class="btn btn-small btn-danger" onclick="event.stopPropagation(); deleteMember('${member.id}')">
                        Sil
                    </button>
                </div>
            </div>
        `).join('');

        // Apply click restriction styling or logic?
        // Mobile said: Trainer can't click "All" members details.
        // Web: user clicks "editMember" typically.
        // We should add logic in editMember to check permission, but for now let's leave it as is or handle in edit-member.js.

    } catch (error) {
        console.error('Error loading members:', error);
        showToast('Üyeler yüklenirken hata oluştu: ' + (error.message || 'Bilinmeyen hata'), 'error');
    }
}

// Payment Modal Logic
function setupPaymentModal() {
    const modal = document.getElementById('payment-modal');
    const closeBtn = document.getElementById('close-payment-modal');
    const form = document.getElementById('payment-form');

    if (!modal) return;

    closeBtn.onclick = () => modal.classList.remove('active');

    // Close on outside click
    window.onclick = (event) => {
        if (event.target == modal) {
            modal.classList.remove('active');
        }
    };

    form.onsubmit = async (e) => {
        e.preventDefault();

        const submitBtn = form.querySelector('button[type="submit"]');
        submitBtn.disabled = true;
        submitBtn.textContent = 'Kaydediliyor...';

        try {
            const memberId = document.getElementById('payment-member-id').value;
            const amount = parseFloat(document.getElementById('payment-amount').value);
            const method = document.getElementById('payment-method').value;
            const category = document.getElementById('payment-category').value;
            const description = document.getElementById('payment-description').value;

            const { data: { user } } = await supabaseClient.auth.getUser();

            const { error } = await supabaseClient
                .from('payments')
                .insert({
                    member_id: memberId,
                    amount: amount,
                    payment_method: method,
                    category: category,
                    notes: description,
                    date: new Date(),
                    created_by: user.id
                });

            if (error) throw error;

            showToast('Ödeme başarıyla alındı', 'success');
            modal.classList.remove('active');
            form.reset();

        } catch (error) {
            console.error('Payment error:', error);
            showToast('Ödeme kaydedilemedi: ' + error.message, 'error');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Ödemeyi Kaydet';
        }
    };
}

// Global functions
window.editMember = async (id) => {
    window.location.href = `edit-member.html?id=${id}`;
};

window.showPaymentModal = (id, name) => {
    const modal = document.getElementById('payment-modal');
    document.getElementById('payment-member-id').value = id;

    // Optional: Set modal title to Include Name
    // document.querySelector('#payment-modal h2').textContent = `${name} - Ödeme Al`;

    modal.classList.add('active');
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
