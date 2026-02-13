import type { PluginInput, Hooks } from "@opencode-ai/plugin";
import type { Event, OpencodeClient, Permission } from "@opencode-ai/sdk";

import process from "node:process";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";

interface Context {
  bunShell: PluginInput["$"],
  projectName: string;
  projectPath: string,
  client: OpencodeClient,
}

interface Info {
  title?: string,
  body: string,
}

type SendNotification = (ctx: Context, info: Info) => Promise<void>;

let sendNotificationImpl: SendNotification = bellNotification;

if (process.env.OPENCODE_NOTIFY?.toLowerCase() === "false") {
  sendNotificationImpl = async () => {};
}
else if (process.env.TERM?.includes("kitty")) {
  sendNotificationImpl = kittyNotification;
}
else if (process.platform === "linux" && os.release().includes("microsoft")) {
  sendNotificationImpl = wslNotification;
}
else if (process.platform === "darwin") {
  sendNotificationImpl = macosNotification;
}

async function bellNotification(): Promise<void> {
  await Bun.write(Bun.stdout, "\x07");
}

const KITTY_ALLOWED_CHARS = /[a-zA-Z0-9\-_\/+.,(){}[\]*&^%$#@!\`~]/;
const NOTIFICATION_GROUP = "OpenCode";
const THROTTLE_MS = 5000;
/**
 * Timer for already triggered notifications, to avoid spam.
 */
const timers: Record<string, NodeJS.Timeout> = {};

async function sendNotification(ctx: Context, info: Info): Promise<void> {
  if (timers[ctx.projectPath]) {
    // We are throttled
    return;
  }

  timers[ctx.projectPath] = setTimeout(() => {
    delete timers[ctx.projectPath];
  }, THROTTLE_MS);

  await sendNotificationImpl(ctx, info);
}

/**
 * Sends a desktop notification for the Kitty Terminal.
 *
 * @see https://sw.kovidgoyal.net/kitty/desktop-notifications/
 */
async function kittyNotification(ctx: Context, info: Info): Promise<void> {
  const identifier = crypto.randomUUID();
  const title = info.title ?? ctx.projectName;
  // a=focus is default
  const props = `i=${identifier}:g=${btoa(NOTIFICATION_GROUP)}:o=unfocused`
  const titleEscape = `\x1b]99;${props}:d=0:p=title;${title}\x1b\\`;
  const bodyEscape = `\x1b]99;${props}:d=1:p=body;${info.body}\x1b\\`;

  await Bun.write(Bun.stdout, titleEscape + bodyEscape);
}

/**
 * Uses an exe calling PowerShell from inside WSL2. Has similar drawbacks
 * as the AppleScript solution; no clicking on notification, and no indication
 * of which window/tab is the source.
 *
 * @see https://github.com/stuartleeks/wsl-notify-send
 */
async function wslNotification(ctx: Context, info: Info): Promise<void> {
  const title = info.title ?? ctx.projectName;

  try {
    // console.error(`~/.config/opencode/wsl-notify-send.exe --appId "OpenCode" --category ${info.title ?? ctx.title} ${info.body}`);
    // --icon does not seem to work
    await ctx.bunShell`~/.config/opencode/wsl-notify-send.exe --appId "${NOTIFICATION_GROUP}" --category '${title}' '${info.body}'`.quiet();
  }
  catch (e) {
    console.error("Failed to run wsl-notify-send.exe", e);
  }
}

/**
 * Uses AppleScript to trigger a notification, the biggest drawbacks here is
 * that you cannot click the notification or figure out which window/tab it
 * belongs to.
 *
 * Mainly used as a fallback in case we are not using Kitty.
 */
async function macosNotification(ctx: Context, info: Info): Promise<void> {
  // Also send bell to make it easier to find
  bellNotification();

  try {
    const title = (info.title ?? ctx.projectName).replace(/'/g, `"'"`);
    const body = info.body.replace(/'/g, `"'"`);

    await ctx.bunShell`osascript -e 'display notification "${body}" with title "${title}"'`.quiet()
  }
  catch (e) {
    console.error("Failed to run osascript", e);
  }
}

// Missing event from the `Event` type
interface EventPermissionAsk {
  type: "permission.asked";
  properties: {
    sessionID: string;
  }
}

async function onEvent(ctx: Context, event: Event | EventPermissionAsk): Promise<void> {
  let session;

  switch (event.type) {
    case "session.idle":
      session = await ctx.client.session.get({ path: { id: event.properties.sessionID } });

      if (session.data?.parentID) {
        // Subagent
        return;
      }

      sendNotification(ctx, {
        body: "Done",
        title: session.data?.title
      })

      break;
    case "session.error":
      if (event.properties.error?.name === "MessageAbortedError") {
        return;
      }

      if (event.properties.sessionID) {
        session = await ctx.client.session.get({ path: { id: event.properties.sessionID } });
      }

      sendNotification(ctx, {
        body: "Error",
        title: session?.data?.title,
      })

      break;
    case "permission.asked":
      // This actually happens
      if (event.properties.sessionID) {
        session = await ctx.client.session.get({ path: { id: event.properties.sessionID } });
      }

      sendNotification(ctx, {
        body: `Permission required ask`,
        title: session?.data?.title,
      });
  }
}

async function onToolExecuteBefore(ctx: Context, { tool, sessionID }: { tool: string, sessionID: string }): Promise<void> {
  if (tool === "question") {
    const session = await ctx.client.session.get({ path: { id: sessionID } });

    sendNotification(ctx, {
      body: `Input required`,
      title: session?.data?.title,
    });
  }
}

async function onPermissionAsk(ctx: Context, input: Permission): Promise<void> {
  const session = await ctx.client.session.get({ path: { id: input.sessionID } });

  sendNotification(ctx, {
    body: `Permission required: ${input.title}`,
    title: session?.data?.title,
  });
}

export async function NotificationPlugin({ project, client, $, directory, worktree }: PluginInput): Promise<Hooks> {
  const projectName = path.basename(directory);
  const context = {
    projectName,
    bunShell: $,
    client,
    projectPath: directory,
  };

  return {
    event: ({ event }) => onEvent(context, event),
    "permission.ask": (input) => onPermissionAsk(context, input),
    "tool.execute.before": (input) => onToolExecuteBefore(context, input),
  };
}
