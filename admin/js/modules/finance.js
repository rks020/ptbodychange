import { supabaseClient } from '../supabase-config.js';
import { showToast } from '../utils.js';

export async function loadFinance() {
    const contentArea = document.getElementById('content-area');

    contentArea.innerHTML = `
        <div class="module-header">
            <h2>Finans & Ödemeler</h2>
        </div>
        
        <div class="stats-row" style="display: flex; gap: 20px; margin-bottom: 20px;">
            <div class="stat-card" style="background: #333; padding: 20px; border-radius: 10px; flex: 1;">
                <h3 style="margin: 0; color: #888; font-size: 14px;">Bu Ay Toplam</h3>
                <p id="total-revenue" style="margin: 10px 0 0 0; font-size: 24px; font-weight: bold; color: #4ade80;">Yükleniyor...</p>
            </div>
             <div class="stat-card" style="background: #333; padding: 20px; border-radius: 10px; flex: 1;">
                <h3 style="margin: 0; color: #888; font-size: 14px;">Son İşlem</h3>
                <p id="last-payment" style="margin: 10px 0 0 0; font-size: 18px; color: #fff;">-</p>
            </div>
        </div>

        <div class="table-container" style="overflow-x: auto; background: #222; border-radius: 10px; padding: 10px;">
            <table style="width: 100%; border-collapse: collapse; color: #eee;">
                <thead>
                    <tr style="border-bottom: 1px solid #444; text-align: left;">
                        <th style="padding: 12px;">Tarih</th>
                        <th style="padding: 12px;">Üye</th>
                        <th style="padding: 12px;">Kategori</th>
                        <th style="padding: 12px;">Yöntem</th>
                        <th style="padding: 12px;">Tutar</th>
                         <th style="padding: 12px;">Not</th>
                    </tr>
                </thead>
                <tbody id="payments-table-body">
                    <tr><td colspan="6" style="padding: 20px; text-align: center;">Yükleniyor...</td></tr>
                </tbody>
            </table>
        </div>
    `;

    await loadPaymentsList();
}

async function loadPaymentsList() {
    try {
        const { data: { user } } = await supabaseClient.auth.getUser();

        // Admin check? Or trainers can see too? Assuming Organization scope.
        // We need organization_id.
        const { data: profile } = await supabaseClient
            .from('profiles')
            .select('organization_id')
            .eq('id', user.id)
            .single();

        if (!profile?.organization_id) return;

        // We need to join members to filter by organization?
        // Or RLS handles it? Assuming RLS handles it.
        // Also need member name.

        const { data: payments, error } = await supabaseClient
            .from('payments')
            .select('*, members(name, organization_id)')
            .order('date', { ascending: false })
            .limit(50);

        if (error) throw error;

        const tableBody = document.getElementById('payments-table-body');

        // Filter by frontend if RLS isn't perfect relation-wise, but members join should help check org
        // Ideally backend RLS ensures we only see our org's payments. 
        // Let's assume fetched payments are correct.

        const filteredPayments = payments.filter(p => p.members && p.members.organization_id === profile.organization_id);

        if (filteredPayments.length === 0) {
            tableBody.innerHTML = '<tr><td colspan="6" style="padding: 20px; text-align: center;">Henüz ödeme yok.</td></tr>';
            document.getElementById('total-revenue').textContent = '0.00 TL';
            return;
        }

        // Calculate Stats (Client side for this month)
        const now = new Date();
        const thisMonthTotal = filteredPayments
            .filter(p => {
                const d = new Date(p.date);
                return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
            })
            .reduce((sum, p) => sum + (p.amount || 0), 0);

        document.getElementById('total-revenue').textContent = `${thisMonthTotal.toLocaleString('tr-TR', { minimumFractionDigits: 2 })} TL`;

        if (filteredPayments.length > 0) {
            document.getElementById('last-payment').textContent = `${filteredPayments[0].members.name} (${filteredPayments[0].amount} TL)`;
        }

        tableBody.innerHTML = filteredPayments.map(p => `
            <tr style="border-bottom: 1px solid #333;">
                <td style="padding: 12px; color: #aaa;">${new Date(p.date).toLocaleDateString('tr-TR')}</td>
                <td style="padding: 12px; font-weight: bold;">${p.members.name}</td>
                <td style="padding: 12px;">
                    <span style="background: rgba(255, 215, 0, 0.1); color: #FFD700; padding: 2px 8px; border-radius: 4px; font-size: 12px;">
                        ${p.category || '-'}
                    </span>
                </td>
                <td style="padding: 12px; color: #ccc;">${p.payment_method || '-'}</td>
                 <td style="padding: 12px; color: #4ade80; font-weight: bold;">
                    ${(p.amount || 0).toLocaleString('tr-TR', { minimumFractionDigits: 2 })} TL
                </td>
                <td style="padding: 12px; color: #888; font-size: 12px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    ${p.notes || ''}
                </td>
            </tr>
        `).join('');

    } catch (error) {
        console.error('Error loading payments:', error);
        showToast('Ödemeler yüklenirken hata oluştu', 'error');
    }
}
