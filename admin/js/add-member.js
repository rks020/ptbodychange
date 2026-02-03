import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';

// Load trainers for dropdown
async function loadTrainers() {
    try {
        const { data: trainers, error } = await supabaseClient
            .from('profiles')
            .select('id, first_name, last_name')
            .or('role.eq.trainer,role.eq.admin,role.eq.owner')
            .order('first_name');

        if (error) throw error;

        const trainerSelect = document.getElementById('member-trainer');
        trainers.forEach(trainer => {
            const option = document.createElement('option');
            option.value = trainer.id;
            option.textContent = `${trainer.first_name} ${trainer.last_name}`;
            trainerSelect.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading trainers:', error);
    }
}

// Check session
async function checkSession() {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session) {
        window.location.href = 'login.html';
        return;
    }

    // Check role/org
    const { data: profile } = await supabaseClient
        .from('profiles')
        .select('role, organization_id')
        .eq('id', session.user.id)
        .single();

    return profile;
}

document.addEventListener('DOMContentLoaded', async () => {
    const profile = await checkSession();
    if (!profile) return;

    // Load trainers for dropdown
    await loadTrainers();

    // Package Change Listener
    const packageSelect = document.getElementById('member-package');
    packageSelect.addEventListener('change', (e) => {
        const manualGroup = document.getElementById('manual-sessions-group');
        const sessionInput = document.getElementById('member-sessions');

        if (e.target.value === 'Manuel') {
            manualGroup.style.display = 'block';
            sessionInput.required = true;
            sessionInput.value = '';
        } else {
            manualGroup.style.display = 'none';
            sessionInput.required = false;
        }
    });

    const form = document.getElementById('add-member-form');
    const saveBtn = document.getElementById('save-member-btn');

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const firstname = document.getElementById('member-firstname').value.trim();
        const lastname = document.getElementById('member-lastname').value.trim();
        const email = document.getElementById('member-email').value.trim();
        const password = document.getElementById('member-password').value.trim();
        const selectedPackage = document.getElementById('member-package').value.trim();
        const trainerId = document.getElementById('member-trainer').value.trim();

        let sessionCount = null;
        if (selectedPackage === 'Manuel') {
            sessionCount = parseInt(document.getElementById('member-sessions').value);
            if (isNaN(sessionCount)) {
                showToast('Lütfen geçerli bir ders sayısı girin', 'error');
                return;
            }
        } else if (selectedPackage) {
            const match = selectedPackage.match(/\((\d+)\s+Ders\)/);
            if (match) sessionCount = parseInt(match[1]);
        }

        if (!firstname || !lastname || !email || !password) {
            showToast('Lütfen tüm alanları doldurun', 'error');
            return;
        }

        // Strict Email Validation
        const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
        if (!emailRegex.test(email)) {
            showToast('Lütfen geçerli bir e-posta adresi girin', 'error');
            return;
        }

        if (email.toLowerCase() === 'test@test.com' || email.endsWith('@test.com')) {
            showToast('Test e-posta adresleri kabul edilmemektedir.', 'error');
            return;
        }

        saveBtn.disabled = true;
        saveBtn.querySelector('.btn-text').style.display = 'none';
        saveBtn.querySelector('.btn-loader').style.display = 'inline';

        try {
            // Check subscription limits
            const { data: orgData } = await supabaseClient
                .from('profiles')
                .select('organizations!inner(subscription_tier)')
                .eq('id', (await supabaseClient.auth.getUser()).data.user.id)
                .single();

            const subscriptionTier = orgData?.organizations?.subscription_tier || 'free';

            // Count existing members
            const { count: memberCount } = await supabaseClient
                .from('profiles')
                .select('*', { count: 'exact', head: true })
                .eq('organization_id', profile.organization_id)
                .eq('role', 'member');

            // Check limits for free tier
            if (subscriptionTier === 'free') {
                if (memberCount >= 10) {
                    showToast('Ücretsiz pakette en fazla 10 üye ekleyebilirsiniz. Pro\'ya yükseltin!', 'error');
                    saveBtn.disabled = false;
                    saveBtn.querySelector('.btn-text').style.display = 'inline';
                    saveBtn.querySelector('.btn-loader').style.display = 'none';
                    return;
                }
            }

            const { data, error } = await supabaseClient.functions.invoke('create-member', {
                body: {
                    email,
                    password,
                    first_name: firstname,
                    last_name: lastname,
                    organization_id: profile.organization_id,
                    subscription_package: selectedPackage || null,
                    trainer_id: trainerId || null,
                    session_count: sessionCount // Pass session count if edge function supports it
                }
            });

            if (error) throw error;
            if (data?.error) throw new Error(data.error);

            // Explicitly update session count just in case Edge Function doesn't handle it yet
            if (data?.user?.id && sessionCount !== null) {
                await supabaseClient
                    .from('members')
                    .update({ session_count: sessionCount })
                    .eq('id', data.user.id);
            }

            showToast('Üye başarıyla oluşturuldu!', 'success');
            setTimeout(() => {
                window.location.href = 'dashboard.html#members';
            }, 1000);

        } catch (error) {
            console.error('Error adding member:', error);
            const errorMessage = error.message || error.toString();

            if (errorMessage.includes('already') ||
                errorMessage.includes('duplicate') ||
                errorMessage.includes('exists') ||
                errorMessage.includes('unique') ||
                errorMessage.includes('Edge Function returned a non-2xx status code')) {
                showToast('Bu email adresi sistemimizde kayıtlıdır. Lütfen farklı bir email kullanın.', 'error');
            } else {
                showToast('Hata: ' + errorMessage, 'error');
            }
        } finally {
            saveBtn.disabled = false;
            saveBtn.querySelector('.btn-text').style.display = 'inline';
            saveBtn.querySelector('.btn-loader').style.display = 'none';
        }
    });
});
