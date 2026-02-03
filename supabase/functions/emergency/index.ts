// Supabase Edge Function for Emergency QR Code Access
// Deploy with: supabase functions deploy emergency

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const pathParts = url.pathname.split("/");
    const qrCodeId = pathParts[pathParts.length - 1];

    if (!qrCodeId || qrCodeId === "emergency") {
      return new Response(
        generateHTML({
          error: true,
          message: "Invalid QR code",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "text/html" },
        }
      );
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Fetch emergency data
    const { data, error } = await supabase.rpc("get_emergency_data", {
      p_qr_code_id: qrCodeId,
    });

    if (error || !data) {
      return new Response(
        generateHTML({
          error: true,
          message: "Patient not found",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "text/html" },
        }
      );
    }

    // Log access
    await supabase.from("emergency_access_logs").insert({
      patient_id: data.patient_id,
      access_type: "web",
      ip_address: req.headers.get("x-forwarded-for") || "unknown",
      user_agent: req.headers.get("user-agent") || "unknown",
    });

    return new Response(generateHTML(data), {
      headers: { ...corsHeaders, "Content-Type": "text/html" },
    });
  } catch (err) {
    return new Response(
      generateHTML({
        error: true,
        message: "An error occurred",
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "text/html" },
      }
    );
  }
});

function generateHTML(data: any): string {
  if (data.error) {
    return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CareSync - Error</title>
  <style>${getStyles()}</style>
</head>
<body>
  <div class="container error-container">
    <div class="error-icon">⚠️</div>
    <h1>Error</h1>
    <p>${data.message}</p>
    <a href="/" class="button">Go Home</a>
  </div>
</body>
</html>`;
  }

  const patient = data.patient || {};
  const conditions = data.conditions || [];
  const medications = data.medications || [];

  const conditionsHTML = conditions.length
    ? conditions
        .map(
          (c: any) => `
        <div class="condition-card ${c.type}">
          <span class="condition-type">${c.type?.toUpperCase() || "OTHER"}</span>
          ${c.severity ? `<span class="severity ${c.severity}">${c.severity}</span>` : ""}
          <p class="condition-desc">${c.description}</p>
        </div>
      `
        )
        .join("")
    : '<p class="empty">No conditions listed</p>';

  const medicationsHTML = medications.length
    ? medications
        .map(
          (m: any) => `
        <div class="medication-card">
          <div class="med-name">${m.medicine}</div>
          <div class="med-details">${m.dosage} • ${m.frequency}</div>
        </div>
      `
        )
        .join("")
    : '<p class="empty">No current medications</p>';

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CareSync - Emergency Medical Data</title>
  <style>${getStyles()}</style>
</head>
<body>
  <header class="emergency-header">
    <div class="header-content">
      <span class="emergency-badge">🚨 EMERGENCY MEDICAL DATA</span>
    </div>
  </header>

  <main class="container">
    <section class="patient-card">
      <div class="patient-icon">👤</div>
      <div class="patient-info">
        <span class="label">PATIENT</span>
        <h1 class="patient-name">${patient.full_name || "Unknown"}</h1>
      </div>
      ${
        patient.blood_type
          ? `
        <div class="blood-type">
          <span class="blood-icon">🩸</span>
          <span class="blood-label">BLOOD TYPE</span>
          <span class="blood-value">${patient.blood_type}</span>
        </div>
      `
          : ""
      }
    </section>

    <section class="section">
      <h2>⚠️ Medical Conditions & Allergies</h2>
      <div class="conditions-list">
        ${conditionsHTML}
      </div>
    </section>

    <section class="section">
      <h2>💊 Current Medications</h2>
      <div class="medications-list">
        ${medicationsHTML}
      </div>
    </section>

    ${
      patient.emergency_contact
        ? `
      <section class="section">
        <h2>📞 Emergency Contact</h2>
        <div class="contact-card">
          <div class="contact-name">${patient.emergency_contact.name}</div>
          ${patient.emergency_contact.relationship ? `<div class="contact-relation">${patient.emergency_contact.relationship}</div>` : ""}
          <a href="tel:${patient.emergency_contact.phone}" class="call-button">
            📱 Call ${patient.emergency_contact.phone}
          </a>
        </div>
      </section>
    `
        : ""
    }
  </main>

  <footer>
    <p>Powered by <strong>CareSync</strong></p>
    <p class="disclaimer">This data was shared by the patient for emergency use.</p>
  </footer>
</body>
</html>`;
}

function getStyles(): string {
  return `
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
      background: #f8fafc;
      color: #0f172a;
      line-height: 1.5;
    }

    .container {
      max-width: 600px;
      margin: 0 auto;
      padding: 16px;
    }

    .emergency-header {
      background: linear-gradient(135deg, #ef4444, #dc2626);
      color: white;
      padding: 16px;
      text-align: center;
    }

    .emergency-badge {
      font-weight: bold;
      font-size: 14px;
      letter-spacing: 1px;
    }

    .patient-card {
      background: linear-gradient(135deg, #ef4444, #dc2626);
      border-radius: 20px;
      padding: 24px;
      color: white;
      margin-top: 16px;
    }

    .patient-icon {
      font-size: 32px;
      margin-bottom: 12px;
    }

    .patient-info .label {
      font-size: 12px;
      opacity: 0.8;
      letter-spacing: 1px;
    }

    .patient-name {
      font-size: 28px;
      font-weight: bold;
      margin-top: 4px;
    }

    .blood-type {
      background: white;
      border-radius: 12px;
      padding: 12px 16px;
      margin-top: 16px;
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .blood-icon {
      font-size: 24px;
    }

    .blood-label {
      color: #64748b;
      font-size: 12px;
    }

    .blood-value {
      color: #ef4444;
      font-size: 24px;
      font-weight: bold;
      margin-left: auto;
    }

    .section {
      margin-top: 24px;
    }

    .section h2 {
      font-size: 18px;
      margin-bottom: 12px;
      color: #334155;
    }

    .condition-card {
      background: white;
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 12px;
      border-left: 4px solid #94a3b8;
    }

    .condition-card.allergy {
      border-left-color: #ef4444;
      background: #fef2f2;
    }

    .condition-card.chronic {
      border-left-color: #f59e0b;
      background: #fffbeb;
    }

    .condition-type {
      font-size: 11px;
      font-weight: 600;
      color: #64748b;
      letter-spacing: 0.5px;
    }

    .severity {
      font-size: 10px;
      padding: 2px 8px;
      border-radius: 4px;
      margin-left: 8px;
      font-weight: 600;
      color: white;
    }

    .severity.critical { background: #ef4444; }
    .severity.severe { background: #f97316; }
    .severity.moderate { background: #f59e0b; }
    .severity.mild { background: #22c55e; }

    .condition-desc {
      margin-top: 8px;
      font-weight: 500;
    }

    .medication-card {
      background: white;
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 12px;
    }

    .med-name {
      font-weight: 600;
      font-size: 16px;
    }

    .med-details {
      color: #64748b;
      font-size: 14px;
      margin-top: 4px;
    }

    .contact-card {
      background: white;
      border-radius: 12px;
      padding: 16px;
    }

    .contact-name {
      font-weight: 600;
      font-size: 18px;
    }

    .contact-relation {
      color: #64748b;
      font-size: 14px;
    }

    .call-button {
      display: block;
      background: #22c55e;
      color: white;
      text-align: center;
      padding: 14px;
      border-radius: 10px;
      margin-top: 12px;
      text-decoration: none;
      font-weight: 600;
      font-size: 16px;
    }

    .empty {
      color: #94a3b8;
      font-style: italic;
      padding: 16px;
      text-align: center;
      background: white;
      border-radius: 12px;
    }

    footer {
      text-align: center;
      padding: 24px;
      color: #64748b;
      font-size: 14px;
    }

    .disclaimer {
      font-size: 12px;
      margin-top: 8px;
      opacity: 0.7;
    }

    .error-container {
      text-align: center;
      padding: 48px 24px;
    }

    .error-icon {
      font-size: 64px;
      margin-bottom: 16px;
    }

    .button {
      display: inline-block;
      background: #0d9488;
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      text-decoration: none;
      margin-top: 16px;
      font-weight: 600;
    }
  `;
}

