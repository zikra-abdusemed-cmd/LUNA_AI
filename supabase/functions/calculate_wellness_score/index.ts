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

  const { date } = await req.json();
  const scoreDate = date ?? new Date().toISOString().split("T")[0];

  // Use SQL function
  const { data: scoreData } = await supabase
    .rpc("calculate_wellness_score_for_date", {
      p_user_id: user.id,
      p_date: scoreDate,
    })
    .single();

  if (!scoreData) {
    return new Response(
      JSON.stringify({ message: "No mood logged for this date" }),
      { headers: corsHeaders }
    );
  }

  // Get yesterday's score for delta
  const yesterday = new Date(scoreDate);
  yesterday.setDate(yesterday.getDate() - 1);
  const { data: yesterdayScore } = await supabase
    .from("wellness_scores")
    .select("overall_score")
    .eq("user_id", user.id)
    .eq("score_date", yesterday.toISOString().split("T")[0])
    .single();

  // Gemini interprets score in context of cycle
  const genAI = new GoogleGenerativeAI(Deno.env.get("GEMINI_API_KEY")!);
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const delta = yesterdayScore
    ? scoreData.overall_score - yesterdayScore.overall_score
    : 0;

  const interpretationPrompt = `
User wellness score: ${scoreData.overall_score}/100
Score breakdown: mood ${scoreData.mood_score}/25, sleep ${scoreData.sleep_score}/25, hydration ${scoreData.hydration_score}/15, stress ${scoreData.stress_score}/20, activity ${scoreData.activity_score}/15
Delta from yesterday: ${delta > 0 ? "+" + delta : delta}

Write ONE sentence (max 15 words) interpreting this score. Be specific about the biggest factor.
Return only the sentence, no quotes.
`;

  let interpretation = "";
  try {
    const result = await model.generateContent(interpretationPrompt);
    interpretation = result.response.text().trim();
  } catch {
    interpretation = `Your wellness score is ${scoreData.overall_score}/100 today.`;
  }

  // Upsert score
  await supabase.from("wellness_scores").upsert({
    user_id: user.id,
    score_date: scoreDate,
    overall_score: scoreData.overall_score,
    mood_score: scoreData.mood_score,
    sleep_score: scoreData.sleep_score,
    hydration_score: scoreData.hydration_score,
    stress_score: scoreData.stress_score,
    activity_score: scoreData.activity_score,
    score_breakdown: scoreData.breakdown,
    ai_interpretation: interpretation,
  }, { onConflict: "user_id,score_date" });

  return new Response(
    JSON.stringify({
      score: scoreData.overall_score,
      breakdown: {
        mood: scoreData.mood_score,
        sleep: scoreData.sleep_score,
        hydration: scoreData.hydration_score,
        stress: scoreData.stress_score,
        activity: scoreData.activity_score,
      },
      interpretation,
      delta,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});