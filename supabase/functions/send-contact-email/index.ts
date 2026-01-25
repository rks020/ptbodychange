
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
    // Handle CORS preflight requests
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        if (!RESEND_API_KEY) {
            throw new Error("RESEND_API_KEY is not set in environment variables");
        }

        const { full_name, email, message } = await req.json();

        if (!email || !message) {
            return new Response(
                JSON.stringify({ error: "Email and message are required" }),
                {
                    status: 400,
                    headers: { ...corsHeaders, "Content-Type": "application/json" },
                }
            );
        }

        const res = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${RESEND_API_KEY}`,
            },
            body: JSON.stringify({
                from: "FitFlow İletişim <noreply@fitflow.com.tr>", // Updated to match the restricted API Key domain
                to: ["info.fitflowtr@gmail.com"],
                reply_to: email,
                subject: `Yeni İletişim Mesajı: ${full_name || 'İsimsiz'}`,
                html: `
          <h3>Yeni İletişim Formu Mesajı</h3>
          <p><strong>Gönderen:</strong> ${full_name} (${email})</p>
          <p><strong>Mesaj:</strong></p>
          <div style="background:#f4f4f4; padding:15px; border-radius:5px;">
            ${message.replace(/\n/g, "<br>")}
          </div>
        `,
            }),
        });

        const data = await res.json();

        if (!res.ok) {
            console.error("Resend API Error:", data);
            throw new Error(data.message || "Failed to send email");
        }

        return new Response(JSON.stringify(data), {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    } catch (error) {
        console.error("Error:", error);
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});
