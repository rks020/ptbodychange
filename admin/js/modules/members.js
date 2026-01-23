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

        <!-- Add Member Modal -->
        <div id="add-member-modal" class="modal">
            <div class="modal-content" style="max-width: 500px;">
                <h2>Yeni Üye Ekle</h2>
                <form id="add-member-form">
                    <div class="form-group">
                        <label>Ad</label>
                        <input type="text" id="member-firstname" required>
                    </div>
                    <div class="form-group">
                        <label>Soyad</label>
                        <input type="text" id="member-lastname" required>
                    </div>
                    <div class="form-group">
                        <label>Email</label>
                        <input type="email" id="member-email" required>
                    </div>
                    <div class="form-group">
                        <label>Geçici Şifre</label>
                        <input type="text" id="member-password" required minlength="6" placeholder="En az 6 karakter">
                    </div>
                    <div class="form-actions">
                        <button type="button" class="btn btn-secondary" id="cancel-member-btn">İptal</button>
                        <button type="submit" class="btn btn-primary" id="save-member-btn">
                            <span class="btn-text">Kaydet</span>
                            <span class="btn-loader" style="display:none;">⏳</span>
                        </button>
                    </div>
                </form>
            </div>
        </div>

    /* Styles removed: using admin/css/styles.css */
    `;

    // Load members
    await loadMembersList();

    // Setup search
    document.getElementById('member-search').addEventListener('input', (e) => {
        const query = e.target.value.toLowerCase();
        document.querySelectorAll('.member-card').forEach(card => {
            const name = card.querySelector('h3').textContent.toLowerCase();
            card.style.display = name.includes(query) ? 'flex' : 'none';
        });
    });

    // Add member interactions
    const modal = document.getElementById('add-member-modal');
    const form = document.getElementById('add-member-form');

    document.getElementById('add-member-btn').addEventListener('click', () => {
        modal.classList.add('active');
    });

    document.getElementById('cancel-member-btn').addEventListener('click', () => {
        modal.classList.remove('active');
        form.reset();
    });

    form.addEventListener('submit', handleAddMember);
}

async function loadMembersList() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        const { data: members, error } = await supabaseClient
            .from('profiles')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .eq('role', 'member')
            .order('created_at', { ascending: false });

        if (error) throw error;

        const listContainer = document.getElementById('members-list');

        if (!members || members.length === 0) {
            listContainer.innerHTML = '<p>Henüz üye eklenmemiş.</p>';
            return;
        }

        listContainer.innerHTML = members.map(member => `
            <div class="member-card">
                <div class="member-header">
                    <div class="member-avatar">
                        ${(member.first_name?.[0] || 'M').toUpperCase()}
                    </div>
                    <div class="member-info">
                        <h3>${member.first_name || ''} ${member.last_name || ''}</h3>
                        <p>${member.profession || 'Üye'}</p>
                        <p style="font-size: 12px; opacity: 0.7;">${member.id.slice(0, 8)}...</p>
                    </div>
                </div>
                <div class="member-actions">
                    <button class="btn btn-small" onclick="viewMember('${member.id}')">
                        Detaylar
                    </button>
                    <!-- <button class="btn btn-small" style="color: var(--error); border-color: rgba(255,59,48,0.3);" onclick="deleteMember('${member.id}')">Sil</button> -->
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading members:', error);
        showToast('Üyeler yüklenirken hata oluştu', 'error');
    }
}

async function handleAddMember(e) {
    e.preventDefault();

    const firstname = document.getElementById('member-firstname').value.trim();
    const lastname = document.getElementById('member-lastname').value.trim();
    const email = document.getElementById('member-email').value.trim();
    const password = document.getElementById('member-password').value.trim();
    const saveBtn = document.getElementById('save-member-btn');

    if (!firstname || !lastname || !email || !password) {
        showToast('Lütfen tüm alanları doldurun', 'error');
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
            throw new Error('Organizasyon bilgisi bulunamadı');
        }

        // Call Edge Function
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
        document.getElementById('add-member-modal').classList.remove('active');
        document.getElementById('add-member-form').reset();
        await loadMembersList();

    } catch (error) {
        console.error('Error adding member:', error);
        showToast('Üye eklenirken hata: ' + (error.message || 'Bilinmeyen hata'), 'error');
    } finally {
        saveBtn.disabled = false;
        saveBtn.querySelector('.btn-text').style.display = 'inline';
        saveBtn.querySelector('.btn-loader').style.display = 'none';
    }
}

window.viewMember = (id) => {
    showToast('Üye detayları yakında eklenecek', 'info');
};
