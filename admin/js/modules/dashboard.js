import { supabaseClient } from '../supabase-config.js';
import { showToast, formatDate } from '../utils.js';

export async function loadDashboard() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="dashboard-grid">
            <div class="stat-card">
                <div class="stat-icon">👥</div>
                <div class="stat-content">
                    <h3>Toplam Üye</h3>
                    <p class="stat-value" id="total-members">-</p>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">💪</div>
                <div class="stat-content">
                    <h3>Toplam Antrenör</h3>
                    <p class="stat-value" id="total-trainers">-</p>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">📋</div>
                <div class="stat-content">
                    <h3>Aktif Programlar</h3>
                    <p class="stat-value" id="active-programs">-</p>
                </div>
            </div>
        </div>

        <div class="dashboard-actions">
            <h2>Hızlı İşlemler</h2>
            <div class="action-grid">
                <button class="action-btn" onclick="window.location.hash='members'">
                    <span class="icon">➕</span>
                    <span>Yeni Üye Ekle</span>
                </button>
                <button class="action-btn" onclick="window.location.hash='trainers'">
                    <span class="icon">➕</span>
                    <span>Yeni Antrenör Ekle</span>
                </button>
                <button class="action-btn" onclick="window.location.hash='announcements'">
                    <span class="icon">📢</span>
                    <span>Duyuru Yap</span>
                </button>
            </div>
        </div>

        <style>
            .dashboard-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 24px;
                margin-bottom: 32px;
            }

            .stat-card {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 16px;
                padding: 24px;
                display: flex;
                align-items: center;
                gap: 16px;
                transition: all 0.3s ease;
            }

            .stat-card:hover {
                transform: translateY(-4px);
                box-shadow: 0 8px 24px rgba(0, 0, 0, 0.3);
            }

            .stat-icon {
                font-size: 40px;
                width: 60px;
                height: 60px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: rgba(255, 215, 0, 0.1);
                border-radius: 12px;
            }

            .stat-content h3 {
                font-size: 14px;
                color: var(--text-secondary);
                margin-bottom: 8px;
                font-weight: 500;
            }

            .stat-value {
                font-size: 32px;
                font-weight: 700;
                color: var(--primary-yellow);
            }

            .dashboard-actions {
                margin-top: 32px;
            }

            .dashboard-actions h2 {
                margin-bottom: 16px;
                font-size: 20px;
            }

            .action-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 16px;
            }

            .action-btn {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 12px;
                padding: 20px;
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 12px;
                color: var(--text-primary);
                font-family: 'Outfit', sans-serif;
                font-size: 15px;
                font-weight: 600;
                cursor: pointer;
                transition: all 0.3s ease;
            }

            .action-btn:hover {
                background: rgba(255, 215, 0, 0.1);
                border-color: var(--primary-yellow);
                transform: translateY(-2px);
            }

            .action-btn .icon {
                font-size: 32px;
            }
        </style>
    `;

    // Load statistics
    await loadStatistics();
}

async function loadStatistics() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        // Get user's organization
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        const orgId = profile.organization_id;

        // Count members
        const { count: membersCount } = await supabaseClient
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .eq('organization_id', orgId)
            .eq('role', 'member');

        // Count trainers
        const { count: trainersCount } = await supabaseClient
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .eq('organization_id', orgId)
            .eq('role', 'trainer');

        // Count active programs (Members with assigned trainers)
        const { count: activeProgramsCount } = await supabaseClient
            .from('profiles')
            .select('*', { count: 'exact', head: true })
            .eq('organization_id', orgId)
            .eq('role', 'member')
            .not('trainer_id', 'is', null);

        // Update UI
        document.getElementById('total-members').textContent = membersCount || 0;
        document.getElementById('total-trainers').textContent = trainersCount || 0;
        document.getElementById('active-programs').textContent = activeProgramsCount || 0;

    } catch (error) {
        console.error('Error loading statistics:', error);
        showToast('İstatistikler yüklenirken hata oluştu', 'error');
    }
}
