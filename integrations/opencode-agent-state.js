export const WezTermAgentState = async ({ $ }) => {
  const setState = async (state) => {
    await $`wezterm-agent-state ${state}`
  }

  return {
    "tool.execute.before": async () => {
      await setState("running")
    },
    event: async ({ event }) => {
      if (event.type === "permission.asked") {
        await setState("attention")
      } else if (event.type === "permission.replied") {
        await setState("running")
      } else if (event.type === "session.error") {
        await setState("failed")
      } else if (event.type === "session.idle") {
        await setState("completed")
      }
    },
  }
}
