import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai@0.3.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    Deno.env.get("GEMINI_API_KEY"),
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401 });

  // Get profile and wellness twin data
  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  const { data: latestCycle } = await supabase
    .from("cycles")
    .select("*")
    .eq("user_id", user.id)
    .order("start_date", { ascending: false })
    .limit(1)
    .single();

  if (!latestCycle) {
    return new Response(
      JSON.stringify({ message: "No cycle data found. Log a period to get predictions." }),
      { headers: corsHeaders }
    );
  }

  const twinData = profile?.wellness_twin_data ?? {};
  const phaseStats = twinData.phaseStats ?? {};

  // Phase default fallbacks (used if no historical data)
  const phaseDefaults: Record<string, any> = {
    menstrual:  { avgEnergy: 4.5, avgMood: 5.0, topSymptoms: ["cramps", "fatigue"] },
    follicular: { avgEnergy: 7.0, avgMood: 7.5, topSymptoms: [] },
    ovulation:  { avgEnergy: 8.5, avgMood: 8.5, topSymptoms: [] },
    luteal:     { avgEnergy: 5.5, avgMood: 6.0, topSymptoms: ["bloating", "mood_swings"] },
  };

  // Build 7-day predictions
  const startDate = new Date(latestCycle.start_date);
  const avgCycleLength = profile?.avg_cycle_length ?? 28;
  const periodDuration = profile?.avg_period_duration ?? 5;

  const predictions = [];
  for (let i = 1; i <= 7; i++) {
    const date = new Date();
    date.setDate(date.getDate() + i);

    const daysSinceStart = Math.floor(
      (date.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)
    );
    let cycleDay = (daysSinceStart % avgCycleLength) + 1;
    if (cycleDay < 1) cycleDay = 1;

    let phase = "luteal";
    if (cycleDay <= periodDuration) phase = "menstrual";
    else if (cycleDay <= 13) phase = "follicular";
    else if (cycleDay <= 16) phase = "ovulation";

    const stats = phaseStats[phase] ?? phaseDefaults[phase];
    const isProductivityWindow = phase === "follicular" || phase === "ovulation";

    predictions.push({
      date: date.toISOString().split("T")[0],
      cycle_day: cycleDay,
      phase,
      predicted_energy: Math.round(stats.avgEnergy * 10) / 10,
      predicted_mood: Math.round(stats.avgMood * 10) / 10,
      likely_symptoms: stats.topSymptoms ?? [],
      is_productivity_window: isProductivityWindow,
      narrative: null, // filled by Gemini below
    });
  }

  // Ask Gemini for short narratives
  const genAI = new GoogleGenerativeAI(Deno.env.get("GEMINI_API_KEY")!);
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const narrativePrompt = `
For these 7-day wellness predictions, write a one-sentence narrative for each day.
Make each sentence specific, warm, and actionable. Reference the phase and energy level.

Predictions:
${JSON.stringify(predictions, null, 2)}

Return a JSON array of 7 strings only, no markdown.
`;

  try {
    const narrativeResult = await model.generateContent(narrativePrompt);
    const narratives = JSON.parse(
      narrativeResult.response.text().replace(/```json|```/g, "").trim()
    );
    predictions.forEach((p, i) => { p.narrative = narratives[i] ?? null; });
  } catch {
    // Narratives are optional; continue without them
  }

  return new Response(
    JSON.stringify({ predictions }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});