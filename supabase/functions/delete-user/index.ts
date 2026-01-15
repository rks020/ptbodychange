
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
    // CORS Headers
    const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    };

    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        );

        // 1. Check Auth (Caller must be logged in)
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // 2. Get Request Data
        const body = await req.json();
        const targetUserId = body.user_id;
        const deleteOrganization = body.delete_organization === true;

        if (!targetUserId && !deleteOrganization) {
            return new Response(JSON.stringify({ error: 'User ID or delete_organization flag is required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // 3. Admin Client (Service Role)
        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // 3.1 Fetch Caller's Profile
        const { data: callerProfile, error: profileError } = await supabaseAdmin
            .from('profiles')
            .select('organization_id, role')
            .eq('id', user.id)
            .single();

        if (profileError || !callerProfile?.organization_id) {
            return new Response(JSON.stringify({ error: 'Caller has no organization' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        const organizationId = callerProfile.organization_id;

        // ==========================================
        // SCENARIO 1: DELETE ENTIRE ORGANIZATION
        // ==========================================
        if (deleteOrganization) {
            console.log(`[DELETE-USER] Full Organization Delete requested by ${user.id} for Org ${organizationId}`);

            if (callerProfile.role !== 'owner') {
                return new Response(JSON.stringify({ error: 'Only owners can delete organization' }), {
                    status: 403,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }

            // 1. Get ALL users in organization (Members + Trainers + Owner)
            const { data: orgUsers, error: usersError } = await supabaseAdmin
                .from('profiles')
                .select('id')
                .eq('organization_id', organizationId);

            if (usersError) throw usersError;

            console.log(`[DELETE-USER] Found ${orgUsers?.length} users to delete.`);

            // 2. Delete each user completely
            const errors: any[] = [];
            for (const profile of orgUsers || []) {
                try {
                    await deleteSingleUser(supabaseAdmin, profile.id);
                } catch (e) {
                    console.error(`Error deleting user ${profile.id}:`, e);
                    errors.push(e);
                }
            }

            // 3. Delete Organization Record (Finally)
            // Note: If 'profiles' table has FK to organization without cascade, we must ensure profiles are gone first.
            // Our deleteSingleUser deletes profile row, so it should be fine.
            const { error: orgDeleteError } = await supabaseAdmin
                .from('organizations')
                .delete()
                .eq('id', organizationId);

            if (orgDeleteError) {
                console.error('Error deleting organization record:', orgDeleteError);
                // Try hard delete if FK constraints persist? Usually manual cleaning works.
                throw orgDeleteError;
            }

            return new Response(JSON.stringify({
                message: 'Organization and all users deleted',
                count: orgUsers?.length,
                errors: errors.length > 0 ? errors : undefined
            }), {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // ==========================================
        // SCENARIO 2: DELETE SINGLE USER
        // ==========================================

        // Caller checks
        if (callerProfile.role !== 'owner' && callerProfile.role !== 'admin') {
            return new Response(JSON.stringify({ error: 'Insufficient permissions' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        // Verify Target User authorization (Must happen before deleting!)
        const { data: targetProfile } = await supabaseAdmin
            .from('profiles')
            .select('organization_id')
            .eq('id', targetUserId)
            .single();

        // Check for orphaned users via metadata fallback
        const { data: targetAuthData } = await supabaseAdmin.auth.admin.getUserById(targetUserId);
        const userOrgFromProfile = targetProfile?.organization_id;
        const userOrgFromMeta = targetAuthData?.user?.app_metadata?.organization_id;

        const isOrphaned = !userOrgFromProfile && !userOrgFromMeta;
        const belongsToCallerOrg = userOrgFromProfile === organizationId || userOrgFromMeta === organizationId;

        if (!isOrphaned && !belongsToCallerOrg) {
            return new Response(JSON.stringify({ error: 'User belongs to another organization' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }

        await deleteSingleUser(supabaseAdmin, targetUserId);

        return new Response(JSON.stringify({ message: 'User deleted successfully' }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });

    } catch (error) {
        console.error('Exception:', error);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }
});

// Helper Function: Deletes all traces of a user
async function deleteSingleUser(supabaseAdmin: SupabaseClient, userId: string) {
    console.log(`[DELETE-USER] Deleting user: ${userId}`);

    // 1. FCM Tokens
    await supabaseAdmin.from('fcm_tokens').delete().eq('user_id', userId);

    // 2. Members Table (If exists)
    await supabaseAdmin.from('members').delete().eq('id', userId);

    // 3. Profiles Table
    // This is critical to release the FK on Organization owner_id if this user is an owner, 
    // OR release FK on Organization if profile points to it.
    await supabaseAdmin.from('profiles').delete().eq('id', userId);

    // 4. Auth User (The login)
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (error) {
        console.error(`Failed to delete auth user ${userId}:`, error);
        throw error;
    }
}
