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

  // ─── Fetch 3 months of mood + cycle data ─────────────────
  const threeMonthsAgo = new Date();
  threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

  const { data: moods } = await supabase
    .from("moods")
    .select("*, cycles(start_date, end_date, cycle_length, period_duration)")
    .eq("user_id", user.id)
    .gte("logged_date", threeMonthsAgo.toISOString().split("T")[0])
    .order("logged_date");

  if (!moods || moods.length < 7) {
    return new Response(
      JSON.stringify({ message: "Not enough data yet. Keep logging!" }),
      { headers: corsHeaders }
    );
  }

  // ─── Rule-based pattern detection ────────────────────────

  // Compute phase for each mood entry
  const moodsWithPhase = moods.map((m: any) => {
    let phase = "unknown";
    if (m.cycles?.start_date) {
      const startDate = new Date(m.cycles.start_date);
      const moodDate = new Date(m.logged_date);
      const day = Math.floor(
        (moodDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)
      ) + 1;
      const pd = m.cycles.period_duration ?? 5;
      if (day <= pd) phase = "menstrual";
      else if (day <= 13) phase = "follicular";
      else if (day <= 16) phase = "ovulation";
      else phase = "luteal";
    }
    return { ...m, phase };
  });

  // Phase averages
  const phases = ["menstrual", "follicular", "ovulation", "luteal"];
  const phaseStats: Record<string, any> = {};

  for (const phase of phases) {
    const phaseMoods = moodsWithPhase.filter((m: any) => m.phase === phase);
    if (phaseMoods.length === 0) continue;

    const avg = (arr: number[]) =>
      arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : 0;

    const allSymptoms = phaseMoods.flatMap((m: any) => m.symptoms ?? []);
    const symptomCounts: Record<string, number> = {};
    allSymptoms.forEach((s: string) => {
      symptomCounts[s] = (symptomCounts[s] ?? 0) + 1;
    });
    const topSymptoms = Object.entries(symptomCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 3)
      .map(([s]) => s);

    phaseStats[phase] = {
      count: phaseMoods.length,
      avgEnergy: avg(phaseMoods.map((m: any) => m.energy_level)),
      avgStress: avg(phaseMoods.map((m: any) => m.stress_level)),
      avgSleep: avg(phaseMoods.map((m: any) => m.sleep_hours ?? 7)),
      avgMoodScore: avg(phaseMoods.map((m: any) => moodToScore(m.mood))),
      topSymptoms,
    };
  }

  // Correlations: sleep < 6 → symptom spikes
  const correlations: string[] = [];

  for (const phase of phases) {
    const phaseMoods = moodsWithPhase.filter((m: any) => m.phase === phase);
    if (phaseMoods.length < 3) continue;

    const lowSleep = phaseMoods.filter((m: any) => m.sleep_hours < 6);
    const normalSleep = phaseMoods.filter((m: any) => m.sleep_hours >= 6);

    if (lowSleep.length >= 2 && normalSleep.length >= 2) {
      const lowStress =
        lowSleep.reduce((a: number, m: any) => a + m.stress_level, 0) / lowSleep.length;
      const normalStress =
        normalSleep.reduce((a: number, m: any) => a + m.stress_level, 0) / normalSleep.length;

      if (lowStress - normalStress > 2) {
        correlations.push(
          `When you sleep under 6 hours during your ${phase} phase, stress is ${Math.round((lowStress - normalStress) * 10)}% higher.`
        );
      }

      // Symptom correlation
      const lowSleepSymptoms = lowSleep.flatMap((m: any) => m.symptoms ?? []);
      if (lowSleepSymptoms.includes("headache")) {
        const headacheRate = Math.round((lowSleepSymptoms.filter((s: string) => s === "headache").length / lowSleep.length) * 100);
        if (headacheRate > 50) {
          correlations.push(
            `Headaches appear ${headacheRate}% of the time when you sleep under 6 hours in your ${phase} phase.`
          );
        }
      }
    }
  }

  // ─── Ask Gemini to narrate insights ──────────────────────
  const genAI = new GoogleGenerativeAI(Deno.env.get("GEMINI_API_KEY")!);
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  const prompt = `
You are Luna AI's Wellness Twin engine. Based on this data, generate 4 personalized wellness insights.

Phase statistics:
${JSON.stringify(phaseStats, null, 2)}

Detected correlations:
${correlations.join("\n")}

Generate exactly 4 insights as a JSON array. Each insight:
- title: short (3-5 words)
- content: one specific, actionable sentence referencing actual numbers
- insight_type: one of: sleep_pattern, mood_pattern, energy_pattern, symptom_pattern, productivity_pattern, cycle_correlation
- confidence_score: 0.0 to 1.0 based on sample size

Return ONLY the JSON array, no markdown.
`;

  const result = await model.generateContent(prompt);
  let insights: any[] = [];
  try {
    insights = JSON.parse(result.response.text().replace(/```json|```/g, "").trim());
  } catch {
    insights = correlations.map((c, i) => ({
      title: `Pattern ${i + 1}`,
      content: c,
      insight_type: "cycle_correlation",
      confidence_score: 0.7,
    }));
  }

  // ─── Deactivate old insights and save new ones ────────────
  await supabase
    .from("wellness_insights")
    .update({ is_active: false })
    .eq("user_id", user.id);

  const insightsToInsert = insights.map((ins: any) => ({
    user_id: user.id,
    insight_type: ins.insight_type,
    title: ins.title,
    content: ins.content,
    supporting_data: { phaseStats, correlations },
    confidence_score: ins.confidence_score,
    insight_date: new Date().toISOString().split("T")[0],
    is_active: true,
  }));

  await supabase.from("wellness_insights").insert(insightsToInsert);

  // Update twin data on profile
  await supabase
    .from("profiles")
    .update({
      wellness_twin_data: {
        phaseStats,
        correlations,
        lastUpdated: new Date().toISOString(),
      },
    })
    .eq("id", user.id);

  return new Response(
    JSON.stringify({ success: true, insights_generated: insights.length }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});

function moodToScore(mood: string): number {
  const scores: Record<string, number> = {
    happy: 9, energetic: 9, hopeful: 8, calm: 8, content: 7,
    neutral: 6, sad: 4, fatigued: 4, anxious: 3,
    stressed: 3, irritable: 3, overwhelmed: 2,
  };
  return scores[mood] ?? 5;
}