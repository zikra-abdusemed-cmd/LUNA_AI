import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    Deno.env.get("GEMINI_API_KEY"),
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } }
  );

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new Response("Unauthorized", { status: 401 });

  const { suggestion_id, selected_tasks } = await req.json();

  // Verify ownership
  const { data: suggestion } = await supabase
    .from("task_suggestions")
    .select("*")
    .eq("id", suggestion_id)
    .eq("user_id", user.id)
    .single();

  if (!suggestion) {
    return new Response(JSON.stringify({ error: "Suggestion not found" }), {
      status: 404, headers: corsHeaders,
    });
  }

  // Insert approved tasks
  const tasksToInsert = selected_tasks.map((task: any) => ({
    user_id: user.id,
    suggestion_id: suggestion_id,
    title: task.title,
    description: task.description ?? null,
    priority: task.priority ?? "medium",
    category: task.category ?? "personal",
    due_date: task.suggested_due_date ?? null,
    phase_rationale: task.phase_rationale ?? null,
    is_ai_generated: true,
    status: "pending",
  }));

  const { data: createdTasks } = await supabase
    .from("tasks")
    .insert(tasksToInsert)
    .select();

  // Update suggestion status
  const allApproved = selected_tasks.length === suggestion.suggested_tasks.length;
  await supabase
    .from("task_suggestions")
    .update({ status: allApproved ? "approved" : "partially_approved" })
    .eq("id", suggestion_id);

  return new Response(
    JSON.stringify({ success: true, tasks_created: createdTasks?.length }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});