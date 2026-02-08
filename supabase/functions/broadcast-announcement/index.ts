
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

console.log('Hello from broadcast-announcement!')

Deno.serve(async (req) => {
    // 1. Parse Request
    const { title, content, organization_id, sender_id } = await req.json()

    if (!organization_id || !title || !content) {
        return new Response('Missing required fields', { status: 400 })
    }

    // 2. Setup Supabase Client
    const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 3. Get All Profile IDs in Organization (except sender?)
    // actually we want to send to everyone in the org except maybe the sender, or include them too.
    // Let's exclude the sender to avoid sending notification to self.
    const { data: profiles, error: profileError } = await supabase
        .from('profiles')
        .select('id')
        .eq('organization_id', organization_id)
        .neq('id', sender_id)

    if (profileError || !profiles || profiles.length === 0) {
        return new Response('No users found to notify', { status: 200 })
    }

    const userIds = profiles.map(p => p.id)

    // 4. Get FCM Tokens for these users
    const { data: tokens } = await supabase
        .from('fcm_tokens')
        .select('token')
        .in('user_id', userIds)

    if (!tokens || tokens.length === 0) {
        return new Response('No valid FCM tokens found for users', { status: 200 })
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

    try {
        const accessToken = await jwtClient.getAccessToken()

        // 6. Send Notifications (Batch/Parallel)
        // Note: FCM v1 API only supports sending 1 message at a time (no multicast).
        // We have to loop. For huge numbers, we might need a different approach or queue,
        // but for a gym app, this loop should be fine.

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
                                    title: title,
                                    body: content.length > 100 ? content.substring(0, 97) + '...' : content,
                                },
                                data: {
                                    type: 'announcement', // Handle this in Flutter if needed, or default opens app
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
            { headers: { 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error(error)
        return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }
})
