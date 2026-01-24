import { supabaseClient } from './supabase-config.js';
import { showToast } from './utils.js';
import { loadDashboard } from './modules/dashboard.js';

// Initialize Auth
export function initAuth() {
    console.log('Initializing Auth...');
    checkSession();
}

// Check Session
async function checkSession() {
    try {
        const { data: { session }, error: sessionError } = await supabaseClient.auth.getSession();
        if (sessionError) throw sessionError;

        if (session) {
            // Verify user role
            const { data: profile, error: profileError } = await supabaseClient
                .from('profiles')
                .select('role, organization_id, first_name, last_name, avatar_url')
                .eq('id', session.user.id)
                .single();

            if (profileError) throw profileError;

            if (profile && (profile.role === 'owner' || profile.role === 'trainer') && profile.organization_id) {
                // Fetch Organization Name
                const { data: orgData } = await supabaseClient
                    .from('organizations')
                    .select('name')
                    .eq('id', profile.organization_id)
                    .single();

                if (orgData) profile.org_name = orgData.name;

                setupUserInterface(session.user, profile);

            } else {
                // Invalid role
                console.warn('Invalid role or missing organization');
                await supabaseClient.auth.signOut();
                window.location.href = 'login.html';
            }
        } else {
            // No session
            window.location.href = 'login.html';
        }
    } catch (error) {
        console.error('Auth Check Error:', error);
        // If error suggests missing data (JSON object requested ... empty etc) or 406/404, force logout
        // Or simpler: any critical auth check error should probably force re-login for safety
        await supabaseClient.auth.signOut();
        window.location.href = 'login.html';
    }
}

// Setup User Interface
function setupUserInterface(user, profile) {
    // Set user info
    const userNameElement = document.getElementById('user-name');
    if (userNameElement) {
        const userName = `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || user.email;
        userNameElement.textContent = userName;
    }

    // Set organization info
    const orgNameElement = document.getElementById('org-name');
    if (orgNameElement && profile.org_name) {
        orgNameElement.textContent = profile.org_name;
    }

    // Set avatar
    const avatarElement = document.getElementById('user-avatar');
    if (avatarElement) {
        if (profile.avatar_url) {
            avatarElement.style.backgroundImage = `url('${profile.avatar_url}')`;
            avatarElement.style.backgroundSize = 'cover';
            avatarElement.style.backgroundPosition = 'center';
            avatarElement.textContent = ''; // Clear emoji
            avatarElement.style.border = '2px solid var(--primary-yellow)';
        } else {
            const initials = `${profile.first_name?.[0] || ''}${profile.last_name?.[0] || ''}`.toUpperCase();
            avatarElement.textContent = initials || '👤';
            avatarElement.style.backgroundImage = 'none';
        }
    }
}

// Logout
export async function logout() {
    await supabaseClient.auth.signOut();
    window.location.href = 'login.html';
}
