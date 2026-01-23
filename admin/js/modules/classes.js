import { supabaseClient } from '../supabase-config.js';
import { showToast, formatDate } from '../utils.js';

export async function loadClasses() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Ders Programı (Hoca-Üye Takibi)</h2>
        </div>
        
        <div class="schedule-container">
            <div class="table-responsive">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Üye</th>
                            <th>Antrenör</th>
                            <th>Program Durumu</th>
                            <th>İletişim</th>
                        </tr>
                    </thead>
                    <tbody id="schedule-list">
                        <tr><td colspan="4" class="text-center">Yükleniyor...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <style>
            .schedule-container {
                background: var(--surface-color);
                border: 1px solid var(--glass-border);
                border-radius: 16px;
                padding: 24px;
                overflow: hidden;
            }

            .data-table {
                width: 100%;
                border-collapse: collapse;
                margin-top: 10px;
            }

            .data-table th {
                text-align: left;
                padding: 16px;
                color: var(--text-secondary);
                font-size: 14px;
                font-weight: 500;
                border-bottom: 1px solid var(--glass-border);
            }

            .data-table td {
                padding: 16px;
                color: var(--text-primary);
                border-bottom: 1px solid rgba(255,255,255,0.05);
            }

            .data-table tr:last-child td {
                border-bottom: none;
            }

            .user-cell {
                display: flex;
                align-items: center;
                gap: 12px;
            }

            .user-avatar-small {
                width: 32px;
                height: 32px;
                border-radius: 8px;
                background: rgba(255,215,0,0.1);
                color: var(--primary-yellow);
                display: flex;
                align-items: center;
                justify-content: center;
                font-weight: 600;
                font-size: 14px;
            }

            .trainer-badge {
                display: inline-flex;
                align-items: center;
                gap: 6px;
                padding: 6px 12px;
                background: rgba(6,182,212,0.1);
                color: var(--neon-cyan);
                border-radius: 20px;
                font-size: 13px;
                font-weight: 500;
            }

            .status-badge {
                display: inline-flex;
                padding: 4px 10px;
                border-radius: 6px;
                font-size: 12px;
                background: rgba(16, 185, 129, 0.1);
                color: #10b981;
            }
        </style>
    `;

    await loadScheduleData();
}

async function loadScheduleData() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        // Fetch members with assigned trainers
        // Note: This relies on members having a 'trainer_id' relation
        // If not joined directly, we might need a separate query, but 'profiles' usually self-references for trainer_id if it's a flat table
        // Let's check available columns again. Assuming 'profiles' table has 'trainer_id' or 'members' table is used.
        // Based on previous 'members.js', we query 'profiles' for role='member'. Does 'profiles' have 'trainer_id'?
        // The list_tables output earlier showed 'members' table has 'trainer_id'. But 'members.js' uses 'from("profiles")'.
        // This suggests 'profiles' is the main user table. Let's assume 'profiles' has 'trainer_id' or logical equivalent.
        // If 'profiles' doesn't have it, we might need to query 'members' table if it exists separately.
        // Wait, list_tables showed BOTH 'members' table AND 'profiles' table? 
        // Let's re-read list_tables output.
        // It showed "public.members" and "public.profiles" (implied by previous code using it).
        // members.js uses 'supabaseClient.from("profiles")' (Line 55 of members.js).
        // This is confusing. If 'members.js' uses 'profiles', then member data is in 'profiles'.
        // But list_tables showed a 'members' table.
        // Let's stick to 'profiles' since the working app uses it. 
        // Does 'profiles' have 'trainer_id'? I'll try to select it.

        let query = supabaseClient
            .from('profiles')
            .select(`
                id, first_name, last_name, email,
                trainer:trainer_id (first_name, last_name)
            `)
            .eq('organization_id', profile.organization_id)
            .eq('role', 'member')
            .not('trainer_id', 'is', null);

        const { data: assignments, error } = await query;

        const listContainer = document.getElementById('schedule-list');

        if (error) {
            console.error('Data fetch error', error);
            // Fallback if relation fails (maybe trainer_id column doesn't exist on profiles?)
            listContainer.innerHTML = '<tr><td colspan="4" class="text-center text-danger">Veri yüklenemedi. İlişki hatası.</td></tr>';
            return;
        }

        if (!assignments || assignments.length === 0) {
            listContainer.innerHTML = '<tr><td colspan="4" class="text-center">Henüz ders programı oluşturulmuş (hocası olan) üye yok.</td></tr>';
            return;
        }

        listContainer.innerHTML = assignments.map(item => `
            <tr>
                <td>
                    <div class="user-cell">
                        <div class="user-avatar-small">
                            ${(item.first_name?.[0] || 'U').toUpperCase()}
                        </div>
                        <div>
                            <div style="font-weight: 500;">${item.first_name} ${item.last_name}</div>
                            <div style="font-size: 12px; color: var(--text-secondary);">${item.email}</div>
                        </div>
                    </div>
                </td>
                <td>
                    ${item.trainer
                ? `<div class="trainer-badge">
                             <span>🎯</span> ${item.trainer.first_name} ${item.trainer.last_name}
                           </div>`
                : '<span style="color:var(--text-secondary)">Atanmamış</span>'}
                </td>
                <td>
                    <span class="status-badge">Aktif Program</span>
                </td>
                <td>
                    <button class="btn btn-small btn-secondary" onclick="window.location.href='mailto:${item.email}'">Mail Gönder</button>
                </td>
            </tr>
        `).join('');

    } catch (error) {
        console.error('Error loading schedule:', error);
        document.getElementById('schedule-list').innerHTML = '<tr><td colspan="4" class="text-center text-danger">Hata oluştu.</td></tr>';
    }
}
