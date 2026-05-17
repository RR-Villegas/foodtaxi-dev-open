import { serve } from "std/http/server.ts";
import { createClient } from "@supabase/supabase-js";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type EmailPayload = {
  toEmail?: string;
  toName?: string;
  subject?: string;
  htmlContent?: string;
  textContent?: string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const brevoApiKey = Deno.env.get("BREVO_API_KEY");
  const senderEmail = Deno.env.get("BREVO_SENDER_EMAIL");
  const senderName = Deno.env.get("BREVO_SENDER_NAME") ?? "FoodTaxi";

  if (!supabaseUrl || !serviceRoleKey || !brevoApiKey || !senderEmail) {
    return json({ error: "Email service is not configured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) {
    return json({ error: "Missing authorization token" }, 401);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser(
    token,
  );
  if (userError || !userData.user) {
    return json({ error: "Invalid authorization token" }, 401);
  }

  const { data: account, error: accountError } = await supabase
    .from("account")
    .select("account_type")
    .eq("auth_id", userData.user.id)
    .maybeSingle();
  if (accountError || account?.account_type !== "Admin") {
    return json({ error: "Only admins can send application emails" }, 403);
  }

  const payload = (await req.json()) as EmailPayload;
  const toEmail = payload.toEmail?.trim();
  const subject = payload.subject?.trim();
  const htmlContent = payload.htmlContent?.trim();
  const textContent = payload.textContent?.trim();

  if (!toEmail || !subject || (!htmlContent && !textContent)) {
    return json({ error: "Missing email recipient, subject, or body" }, 400);
  }

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      accept: "application/json",
      "api-key": brevoApiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      sender: { name: senderName, email: senderEmail },
      to: [{ email: toEmail, name: payload.toName ?? toEmail }],
      subject,
      ...(htmlContent ? { htmlContent } : {}),
      ...(textContent ? { textContent } : {}),
      tags: ["foodtaxi-application"],
    }),
  });

  const responseBody = await response.json().catch(() => ({}));
  if (!response.ok) {
    return json({ error: "Brevo rejected the email", details: responseBody }, 502);
  }

  return json({ ok: true, brevo: responseBody });
});
