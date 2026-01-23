import { supabaseClient } from '../supabase-config.js';
import { showToast, formatDate } from '../utils.js';

export async function loadAnnouncements() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Duyurular</h2>
            <button class="btn btn-primary" id="add-announcement-btn">
                <span class="icon">📢</span> Yeni Duyuru Yap
            </button>
        </div>

        <div class="announcements-container">
            <div id="announcements-list" class="announcements-list">
                <p class="loading-text">Duyurular yükleniyor...</p>
            </div>
        </div>

        <!-- Add Announcement Modal -->
        <div id="announcement-modal" class="modal">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Yeni Duyuru</h3>
                    <span class="close-modal">&times;</span>
                </div>
                <div class="modal-body">
                    <form id="announcement-form">
                        <div class="form-group">
                            <label>Başlık</label>
                            <input type="text" id="announcement-title" required placeholder="Duyuru başlığı">
                        </div>
                        <div class="form-group">
                            <label>İçerik</label>
                            <textarea id="announcement-content" rows="4" required placeholder="Duyuru içeriği..."></textarea>
                        </div>
                        <div class="form-actions">
                            <button type="button" class="btn btn-secondary close-modal-btn">İptal</button>
                            <button type="submit" class="btn btn-primary">Gönder</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <style>
            .announcements-list {
                display: grid;
                gap: 16px;
            }

            .announcement-card {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 12px;
                padding: 20px;
                transition: all 0.3s ease;
            }

            .announcement-card:hover {
                transform: translateY(-2px);
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }

            .announcement-header {
                display: flex;
                justify-content: space-between;
                align-items: flex-start;
                margin-bottom: 12px;
            }

            .announcement-title {
                font-size: 18px;
                font-weight: 600;
                color: var(--primary-yellow);
                margin: 0;
            }

            .announcement-date {
                font-size: 13px;
                color: var(--text-secondary);
            }

            .announcement-content {
                color: var(--text-primary);
                line-height: 1.5;
                font-size: 15px;
                white-space: pre-wrap;
            }

            .empty-state {
                text-align: center;
                padding: 40px;
                color: var(--text-secondary);
            }
        </style>
    `;

    // Initialize logic
    await fetchAnnouncements();
    setupModal();
}

async function fetchAnnouncements() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        // Get org id
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        const { data: announcements, error } = await supabaseClient
            .from('announcements')
            .select('*')
            .eq('organization_id', profile.organization_id)
            .order('created_at', { ascending: false });

        if (error) throw error;

        renderAnnouncements(announcements);

    } catch (error) {
        console.error('Error fetching announcements:', error);
        showToast('Duyurular yüklenirken hata oluştu', 'error');
    }
}

function renderAnnouncements(announcements) {
    const listContainer = document.getElementById('announcements-list');

    if (!announcements || announcements.length === 0) {
        listContainer.innerHTML = `
            <div class="empty-state">
                <span style="font-size: 48px; display: block; margin-bottom: 16px;">📭</span>
                <p>Henüz hiç duyuru yapılmamış.</p>
            </div>
        `;
        return;
    }

    listContainer.innerHTML = announcements.map(announcement => `
        <div class="announcement-card">
            <div class="announcement-header">
                <h3 class="announcement-title">${escapeHtml(announcement.title)}</h3>
                <span class="announcement-date">${formatDate(announcement.created_at)}</span>
            </div>
            <div class="announcement-content">${escapeHtml(announcement.content)}</div>
        </div>
    `).join('');
}

function setupModal() {
    const modal = document.getElementById('announcement-modal');
    const btn = document.getElementById('add-announcement-btn');
    const closeSpans = document.querySelectorAll('.close-modal, .close-modal-btn');
    const form = document.getElementById('announcement-form');

    btn.onclick = () => {
        modal.style.display = 'block';
        setTimeout(() => modal.classList.add('show'), 10);
    };

    const closeModal = () => {
        modal.classList.remove('show');
        setTimeout(() => {
            modal.style.display = 'none';
            form.reset();
        }, 300);
    };

    closeSpans.forEach(span => span.onclick = closeModal);

    window.onclick = (event) => {
        if (event.target == modal) closeModal();
    };

    form.onsubmit = async (e) => {
        e.preventDefault();

        const title = document.getElementById('announcement-title').value;
        const content = document.getElementById('announcement-content').value;
        const submitBtn = form.querySelector('button[type="submit"]');

        try {
            submitBtn.disabled = true;
            submitBtn.textContent = 'Gönderiliyor...';

            const { data: { user } } = await supabaseClient.auth.getUser();

            // Get org id
            const { data: profile } = await supabaseClient
                .from('profiles')
                .select('organization_id')
                .eq('id', user.id)
                .single();

            const { error } = await supabaseClient
                .from('announcements')
                .insert({
                    title,
                    content,
                    organization_id: profile.organization_id,
                    created_by: user.id
                });

            if (error) throw error;

            showToast('Duyuru başarıyla gönderildi', 'success');
            closeModal();
            fetchAnnouncements();

        } catch (error) {
            console.error('Error sending announcement:', error);
            showToast('Duyuru gönderilemedi: ' + error.message, 'error');
        } finally {
            submitBtn.disabled = false;
            submitBtn.textContent = 'Gönder';
        }
    };
}

function escapeHtml(text) {
    if (!text) return '';
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}
