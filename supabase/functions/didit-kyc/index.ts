// Supabase Edge Function for DiDIt KYC Session Initialization
// Deploy with: supabase functions deploy didit-kyc

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface DiditSessionRequest {
  vendor_data: string;
  callback_url: string;
  features: string[];
}

interface DiditSessionResponse {
  url: string;
  session_id: string;
}

interface ErrorResponse {
  error: string;
  details?: string;
  status_code?: number;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({
          error: "Method not allowed",
          details: "Only POST requests are accepted",
        }),
        {
          status: 405,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Verify authorization
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          details: "Missing authorization header",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Create Supabase client to verify user
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    });

    // Get the authenticated user
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      console.error("[DIDIT-KYC] User verification failed:", userError);
      return new Response(
        JSON.stringify({
          error: "Unauthorized",
          details: "Invalid or expired token",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(`[DIDIT-KYC] Initializing session for user: ${user.id}`);

    // Get DiDIt credentials from environment
    const diditAppId = Deno.env.get("DIDIT_APP_ID");
    const diditApiKey = Deno.env.get("DIDIT_API_KEY");

    if (!diditAppId || !diditApiKey) {
      console.error("[DIDIT-KYC] Missing DiDIt credentials in environment");
      return new Response(
        JSON.stringify({
          error: "Configuration error",
          details: "DiDIt credentials not configured",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Parse request body (optional parameters from client)
    let callbackUrl = "https://caresync.app/verify-callback";
    let features = ["id_document", "face_match", "liveness"];

    try {
      const body = await req.json();
      if (body.callback_url) callbackUrl = body.callback_url;
      if (body.features && Array.isArray(body.features))
        features = body.features;
    } catch {
      // Use defaults if body parsing fails
    }

    // Prepare DiDIt API request
    const diditRequestBody: DiditSessionRequest = {
      vendor_data: user.id,
      callback_url: callbackUrl,
      features: features,
    };

    console.log(
      `[DIDIT-KYC] Creating DiDIt session with features: ${features.join(", ")}`
    );

    // Call DiDIt API to create session
    const diditResponse = await fetch(
      "https://verification.didit.me/api/v3/sessions",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${diditApiKey}`,
          "Content-Type": "application/json",
          "X-App-Id": diditAppId,
        },
        body: JSON.stringify(diditRequestBody),
      }
    );

    const responseText = await diditResponse.text();
    console.log(
      `[DIDIT-KYC] DiDIt API response status: ${diditResponse.status}`
    );
    console.log(`[DIDIT-KYC] DiDIt API response body: ${responseText}`);

    if (!diditResponse.ok) {
      // Parse error response
      let errorDetails = responseText;
      try {
        const errorJson = JSON.parse(responseText);
        errorDetails = errorJson.detail || errorJson.message || responseText;
      } catch {
        // Use raw text if not JSON
      }

      console.error(
        `[DIDIT-KYC] DiDIt API error (${diditResponse.status}): ${errorDetails}`
      );

      return new Response(
        JSON.stringify({
          error: "DiDIt API Error",
          details: errorDetails,
          status_code: diditResponse.status,
        }),
        {
          status: diditResponse.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Parse successful response
    const diditData: DiditSessionResponse = JSON.parse(responseText);

    console.log(
      `[DIDIT-KYC] Session created successfully: ${diditData.session_id}`
    );

    // Log KYC session creation to audit trail
    try {
      await supabase.from("audit_log").insert({
        user_id: user.id,
        action: "kyc_session_created",
        metadata: {
          session_id: diditData.session_id,
          features: features,
        },
      });
    } catch (auditError) {
      console.error("[DIDIT-KYC] Failed to log audit entry:", auditError);
      // Don't fail the request if audit logging fails
    }

    // Return success response to client
    return new Response(
      JSON.stringify({
        success: true,
        url: diditData.url,
        session_id: diditData.session_id,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("[DIDIT-KYC] Unexpected error:", error);

    return new Response(
      JSON.stringify({
        error: "Internal server error",
        details:
          error instanceof Error ? error.message : "Unknown error occurred",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
