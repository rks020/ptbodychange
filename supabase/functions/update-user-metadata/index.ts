
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        );

        // 1. Verify Caller is Admin/Owner
        const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders });
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        const { data: callerProfile } = await supabaseAdmin
            .from('profiles')
            .select('role, organization_id')
            .eq('id', user.id)
            .single();

        if (!callerProfile || !['admin', 'owner'].includes(callerProfile.role)) {
            return new Response(JSON.stringify({ error: 'Unauthorized access' }), { status: 403, headers: corsHeaders });
        }

        // 2. Parse Request
        const { userId, email, firstName, lastName } = await req.json();
        if (!userId) {
            return new Response(JSON.stringify({ error: 'Missing userId' }), { status: 400, headers: corsHeaders });
        }

        // 3. Verify Target User and Organization Match
        const { data: targetProfile, error: targetError } = await supabaseAdmin
            .from('profiles')
            .select('organization_id')
            .eq('id', userId)
            .single();

        if (targetError || !targetProfile) {
            return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: corsHeaders });
        }

        if (targetProfile.organization_id !== callerProfile.organization_id) {
            return new Response(JSON.stringify({ error: 'User belongs to different organization' }), { status: 403, headers: corsHeaders });
        }

        // 4. Update Auth User
        const updateParams: any = {
            user_metadata: {}
        };

        if (email) updateParams.email = email;
        if (firstName) updateParams.user_metadata.first_name = firstName;
        if (lastName) updateParams.user_metadata.last_name = lastName;
        if (firstName || lastName) {
            updateParams.user_metadata.full_name = `${firstName ?? ''} ${lastName ?? ''}`.trim();
            updateParams.user_metadata.display_name = updateParams.user_metadata.full_name;
        }

        const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(userId, updateParams);

        if (updateError) throw updateError;

        return new Response(JSON.stringify({ message: 'User metadata updated successfully' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
    }
});
