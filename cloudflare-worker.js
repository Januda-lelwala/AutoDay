// Cloudflare Worker for AutoDay App
// Deploy this to your Cloudflare Workers account
// Set OPENAI_API_KEY as an environment variable in Cloudflare Workers settings

export default {
  async fetch(request, env) {
    return handleRequest(request, env)
  }
}

async function handleRequest(request, env) {
  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    })
  }

  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const { userInput, currentDate, currentTime } = await request.json()

    // Get OpenAI API key from environment variable (set in Cloudflare Workers settings)
    const OPENAI_API_KEY = env.OPENAI_API_KEY

    if (!OPENAI_API_KEY) {
      return new Response(JSON.stringify({ error: 'OpenAI API key not configured' }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      })
    }

    // Build system prompt with current date/time
    const systemPrompt = `You are an AI scheduling assistant. Parse the user's natural language input and create a structured schedule.

Rules:
- Extract all tasks from the user's input
- If a specific time is mentioned, use it (format: "HH:mm" in 24-hour format)
- If no time is mentioned but it's a task, suggest a reasonable time based on context
- Duration should be in minutes (default: 60 for most tasks, 30 for quick tasks, 90-120 for longer tasks)
- Priority can be: "high", "medium", "low" (infer from context)
- Date format should be "YYYY-MM-DD" (use today's date if not specified)
- If multiple tasks mentioned without times, schedule them in logical order throughout the day

Return ONLY a valid JSON object with this structure:
{
    "tasks": [
        {
            "title": "Task name",
            "date": "YYYY-MM-DD or null",
            "time": "HH:mm or null",
            "duration": 60,
            "priority": "medium or null"
        }
    ]
}

Current date: ${currentDate}
Current time: ${currentTime}`

    const openAIRequest = {
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: systemPrompt
        },
        {
          role: 'user',
          content: `Parse this schedule request and create structured tasks:\n\n"${userInput}"\n\nReturn ONLY the JSON object, no additional text.`
        }
      ],
      temperature: 0.7,
      response_format: { type: 'json_object' }
    }

    const openAIResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(openAIRequest)
    })

    if (!openAIResponse.ok) {
      const error = await openAIResponse.text()
      return new Response(JSON.stringify({ error: 'OpenAI API error', details: error }), {
        status: openAIResponse.status,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      })
    }

    const data = await openAIResponse.json()
    const content = data.choices[0].message.content

    // Parse and return the tasks
    const tasksResponse = JSON.parse(content)

    return new Response(JSON.stringify(tasksResponse), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    })
  }
}
