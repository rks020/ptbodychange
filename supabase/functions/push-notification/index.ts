
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'


Deno.serve(async (req) => {
    const { record } = await req.json()

    // 1. Setup Supabase Client
    const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. record is the new message inserted
    const receiverId = record.receiver_id
    const senderId = record.sender_id
    const content = record.content

    if (!receiverId) return new Response('No receiver', { status: 200 })

    // 3. Get Receiver's FCM Tokens
    const { data: tokens } = await supabase
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', receiverId)

    if (!tokens || tokens.length === 0) {
        return new Response('No tokens found', { status: 200 })
    }

    // 4. Get Sender's Profile (for Notification Title)
    const { data: sender } = await supabase
        .from('profiles')
        .select('first_name, last_name, avatar_url')
        .eq('id', senderId)
        .single()

    const title = sender
        ? `${sender.first_name} ${sender.last_name}`
        : 'Yeni Mesaj'

    const body = content.length > 100 ? content.substring(0, 97) + '...' : content

    // 5. Send Notification via FCM using Google Auth Library manually or Firebase Admin
    // Using direct HTTP v1 API with Service Account

    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')

    const jwtClient = new JWT({
        email: serviceAccount.client_email,
        key: serviceAccount.private_key,
        scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    try {
        const accessToken = await jwtClient.getAccessToken()

        // Send to each token
        const results = await Promise.all(
            tokens.map(async (t) => {
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
                                token: t.token,
                                notification: {
                                    title: title,
                                    body: body,
                                },
                                data: {
                                    type: 'chat',  // ✅ Required for Flutter routing
                                    sender_id: senderId,  // ✅ Fixed: was 'senderId'
                                    sender_name: sender ? `${sender.first_name} ${sender.last_name}` : 'Kullanıcı',
                                    sender_avatar: sender?.avatar_url || '',
                                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                                },
                            },
                        }),
                    }
                )
                return res.json()
            })
        )

        return new Response(JSON.stringify(results), { headers: { 'Content-Type': 'application/json' } })
    } catch (error) {
        console.error(error)
        return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }
})
