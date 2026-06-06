import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  GoogleGenerativeAI,
  HarmBlockThreshold,
  HarmCategory,
} from "https://esm.sh/@google/generative-ai@0.3.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize clients
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      Deno.env.get("GEMINI_API_KEY"),
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
    );

    // Verify JWT and get user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { message, conversation_id } = await req.json();

    // ─── Build user context ───────────────────────────────────
    const [profileRes, latestCycleRes, latestMoodRes, tasksRes] =
      await Promise.all([
        supabase.from("profiles").select("*").eq("id", user.id).single(),
        supabase.from("cycles").select("*").eq("user_id", user.id)
          .order("start_date", { ascending: false }).limit(1).single(),
        supabase.from("moods").select("*").eq("user_id", user.id)
          .order("logged_date", { ascending: false }).limit(1).single(),
        supabase.from("tasks").select("*").eq("user_id", user.id)
          .in("status", ["pending", "in_progress"]).order("due_date"),
      ]);

    const profile = profileRes.data;
    const latestCycle = latestCycleRes.data;
    const latestMood = latestMoodRes.data;
    const tasks = tasksRes.data ?? [];

    // Calculate cycle day and phase
    let cycleDay = null;
    let currentPhase = "unknown";
    if (latestCycle?.start_date) {
      const startDate = new Date(latestCycle.start_date);
      const today = new Date();
      cycleDay = Math.floor(
        (today.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24)
      ) + 1;

      const periodDuration = profile?.avg_period_duration ?? 5;
      if (cycleDay <= periodDuration) currentPhase = "menstrual";
      else if (cycleDay <= 13) currentPhase = "follicular";
      else if (cycleDay <= 16) currentPhase = "ovulation";
      else currentPhase = "luteal";
    }

    // ─── Load conversation history ────────────────────────────
    let conversationHistory: any[] = [];
    let currentConvId = conversation_id;

    if (conversation_id) {
      const { data: conv } = await supabase
        .from("conversations")
        .select("messages")
        .eq("id", conversation_id)
        .single();
      conversationHistory = conv?.messages ?? [];
    }

    // ─── Build system prompt ──────────────────────────────────
    const systemPrompt = `You are Luna, an empathetic AI wellness copilot for women.

## User Context (as of ${new Date().toISOString()})
- Name: ${profile?.full_name || "User"}
- Cycle day: ${cycleDay ?? "unknown"} of ~${profile?.avg_cycle_length ?? 28}
- Current phase: ${currentPhase}
- Today's mood: ${latestMood?.mood ?? "not yet logged"}
- Energy: ${latestMood?.energy_level ?? "unknown"}/10
- Stress: ${latestMood?.stress_level ?? "unknown"}/10
- Sleep last night: ${latestMood?.sleep_hours ?? "unknown"} hours
- Active tasks: ${tasks.length} tasks
- Overdue tasks: ${tasks.filter((t: any) => t.status === "overdue").length}
- User goals: ${profile?.goals?.join(", ") ?? "not set"}

## Phase Context
${phaseGuidance(currentPhase)}

## Your Behavioral Rules
1. Be proactive: volunteer insights when you notice patterns.
2. CRITICAL: When the user mentions any task, deadline, assignment, meeting, or workload,
   you MUST call the create_task_suggestion tool. Do NOT skip this.
3. Never create tasks directly — only call create_task_suggestion.
4. Extract mood, sleep, stress mentions and note them for journaling.
5. Tailor all advice to the current cycle phase.
6. Be warm, direct, and science-informed. Never clinical or cold.
7. Keep responses concise (2-4 sentences) unless asked for more.
8. Always respond in the same language the user writes in.

## Response Format
Return ONLY this JSON (no markdown, no extra text):
{
  "message": "Your conversational response here",
  "extracted_insights": {
    "mood": "string or null",
    "energy": "number 1-10 or null",
    "stress": "number 1-10 or null",
    "sleep": "number in hours or null",
    "symptoms": ["array", "of", "strings"] or []
  }
}`;

    function phaseGuidance(phase: string): string {
      const guidance: Record<string, string> = {
        menstrual: "Rest phase. Recommend gentle tasks, self-care. Warn against overcommitting. Validate if user feels low energy.",
        follicular: "Rising energy. Encourage tackling new projects, learning, planning. Great for creative work.",
        ovulation: "Peak phase. Encourage important meetings, presentations, social activities. User at their best.",
        luteal: "Declining energy. Help with organization, finishing existing work. Watch for PMS symptoms. Avoid adding new big tasks.",
        unknown: "Encourage user to log their period to get personalized phase insights.",
      };
      return guidance[phase] ?? guidance.unknown;
    }

    // ─── Gemini with tool calling ─────────────────────────────
    const genAI = new GoogleGenerativeAI(Deno.env.get("GEMINI_API_KEY")!);
    const model = genAI.getGenerativeModel({
      model: "gemini-2.5-flash",
      systemInstruction: systemPrompt,
      tools: [{
        functionDeclarations: [
          {
            name: "create_task_suggestion",
            description: "Called when user mentions tasks, deadlines, assignments, or workload. Creates a suggestion batch for user approval.",
            parameters: {
              type: "object",
              properties: {
                tasks: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      title: { type: "string" },
                      description: { type: "string" },
                      priority: { type: "string", enum: ["low", "medium", "high", "urgent"] },
                      suggested_due_date: { type: "string" },
                      category: { type: "string", enum: ["study", "work", "health", "social", "personal"] },
                      phase_rationale: { type: "string" },
                    },
                    required: ["title", "priority", "category"],
                  },
                },
                reasoning: { type: "string" },
              },
              required: ["tasks", "reasoning"],
            },
          },
        ],
      }],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 800,
      },
      safetySettings: [
        { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE },
        { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE },
      ],
    });

    // Build chat history for Gemini
    const history = conversationHistory.map((m: any) => ({
      role: m.is_user ? "user" : "model",
      parts: [{ text: m.content }],
    }));

    const chat = model.startChat({ history });
    const result = await chat.sendMessage(message);
    const response = result.response;

    // ─── Handle tool calls ────────────────────────────────────
    let suggestionId: string | null = null;

    for (const part of response.candidates?.[0]?.content?.parts ?? []) {
      if (part.functionCall?.name === "create_task_suggestion") {
        const args = part.functionCall.args as any;

        // Save suggestion to DB
        const { data: suggestion } = await supabase
          .from("task_suggestions")
          .insert({
            user_id: user.id,
            conversation_id: currentConvId,
            suggested_tasks: args.tasks,
            ai_reasoning: args.reasoning,
            cycle_phase: currentPhase,
            status: "pending",
          })
          .select()
          .single();

        suggestionId = suggestion?.id ?? null;
      }
    }

    // ─── Extract text response ────────────────────────────────
    let responseText = response.text();
    let messageContent = responseText;
    let extractedInsights = {};

    try {
      const parsed = JSON.parse(responseText);
      messageContent = parsed.message;
      extractedInsights = parsed.extracted_insights ?? {};
    } catch {
      // If not valid JSON, use raw text
      messageContent = responseText;
    }

    // ─── Save/update conversation ─────────────────────────────
    const newMessages = [
      ...conversationHistory,
      { content: message, is_user: true, created_at: new Date().toISOString() },
      { content: messageContent, is_user: false, created_at: new Date().toISOString() },
    ];

    if (currentConvId) {
      await supabase.from("conversations").update({
        messages: newMessages,
        extracted_insights: extractedInsights,
        updated_at: new Date().toISOString(),
      }).eq("id", currentConvId);
    } else {
      const { data: newConv } = await supabase
        .from("conversations")
        .insert({
          user_id: user.id,
          messages: newMessages,
          extracted_insights: extractedInsights,
          cycle_phase_at_time: currentPhase,
        })
        .select()
        .single();
      currentConvId = newConv?.id ?? null;
    }

    return new Response(
      JSON.stringify({
        message: messageContent,
        conversation_id: currentConvId,
        has_suggestions: suggestionId !== null,
        suggestion_id: suggestionId,
        extracted_insights: extractedInsights,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Chat function error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});