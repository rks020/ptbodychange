
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'


const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
    // 0. Handle CORS
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // 1. Parse Request
        const { title, content, organization_id, sender_id } = await req.json()

        if (!organization_id || !title || !content) {
            return new Response('Missing required fields', {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 2. Setup Supabase Client
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        )

        // 3. Get All Profile IDs in Organization
        const { data: profiles, error: profileError } = await supabase
            .from('profiles')
            .select('id')
            .eq('organization_id', organization_id)
            .neq('id', sender_id)

        if (profileError || !profiles || profiles.length === 0) {
            return new Response(JSON.stringify({ message: 'No users found to notify' }), {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const userIds = profiles.map(p => p.id)

        // 4. Get FCM Tokens for these users
        const { data: tokens } = await supabase
            .from('fcm_tokens')
            .select('token')
            .in('user_id', userIds)

        if (!tokens || tokens.length === 0) {
            return new Response(JSON.stringify({ message: 'No valid FCM tokens found' }), {
                status: 200,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Deduplicate tokens
        const uniqueTokens = [...new Set(tokens.map(t => t.token))]

        // 5. Setup Google Auth for FCM
        const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')

        const jwtClient = new JWT({
            email: serviceAccount.client_email,
            key: serviceAccount.private_key,
            scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
        })

        const accessToken = await jwtClient.getAccessToken()

        // 6. Send Notifications
        const results = await Promise.all(
            uniqueTokens.map(async (token) => {
                const res = await fetch(
                    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
                    {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            Authorization: `Bearer ${accessToken.token}`,
                        },
                        body: JSON.stringify({
                            message: {
                                token: token,
                                notification: {
                                    title: `Yeni Duyuru : ${title}`,
                                    body: content.length > 100 ? content.substring(0, 97) + '...' : content,
                                },
                                data: {
                                    type: 'announcement',
                                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                                    sender_id: sender_id,
                                },
                                android: {
                                    priority: 'HIGH',
                                    notification: {
                                        sound: 'default'
                                    }
                                },
                                apns: {
                                    payload: {
                                        aps: {
                                            sound: 'default',
                                            'content-available': 1
                                        }
                                    }
                                }
                            },
                        }),
                    }
                )
                return res.status
            })
        )

        const successCount = results.filter(s => s === 200).length

        return new Response(
            JSON.stringify({
                success: true,
                message: `Sent to ${successCount} devices`,
                total: uniqueTokens.length
            }),
            {
                headers: {
                    ...corsHeaders,
                    'Content-Type': 'application/json'
                }
            }
        )

    } catch (error) {
        console.error(error)
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
