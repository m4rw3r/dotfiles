import type { PluginInput, Hooks } from "@opencode-ai/plugin";
import type { Event, OpencodeClient, Permission } from "@opencode-ai/sdk";

import process from "node:process";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";

interface Context {
  bunShell: PluginInput["$"],
  projectName: string;
  client: OpencodeClient,
  title: string,
}

interface Info {
  title?: string,
  body: string,
}

type SendNotification = (ctx: Context, info: Info) => Promise<void>;

let sendNotification: SendNotification = bellNotification;

if (process.env.OPENCODE_NOTIFY?.toLowerCase() === "false") {
  sendNotification = async () => {};
}
else if (process.env.TERM?.includes("kitty")) {
  sendNotification = kittyNotification;
}
else if (process.platform === "linux" && os.release().includes("microsoft")) {
  sendNotification = wslNotification;
}
else if (process.platform === "darwin") {
  sendNotification = macosNotification;
}

async function bellNotification(): Promise<void> {
  await Bun.write(Bun.stdout, "\x07");
}

const KITTY_ALLOWED_CHARS = /[a-zA-Z0-9\-_\/+.,(){}[\]*&^%$#@!\`~]/;

/**
 * Sends a desktop notification for the Kitty Terminal.
 *
 * @see https://sw.kovidgoyal.net/kitty/desktop-notifications/
 */
async function kittyNotification(ctx: Context, info: Info): Promise<void> {
  const identifier = crypto.randomUUID();
  const title = info.title ?? ctx.title;
  // a=focus is default
  const props = `i=${identifier}:g=${btoa("OpenCode")}:o=unfocused`
  const titleEscape = `\x1b]99;${props}:d=0:p=title;${title}\x1b\\`;
  const bodyEscape = `\x1b]99;${props}:d=1:p=body;${info.body}\x1b\\`;

  await Bun.write(Bun.stdout, titleEscape + bodyEscape);
}

/**
 * @see https://github.com/stuartleeks/wsl-notify-send
 */
async function wslNotification(ctx: Context, info: Info): Promise<void> {
  try {
    console.error(`~/.config/opencode/wsl-notify-send.exe --appId "OpenCode" --category ${info.title ?? ctx.title} ${info.body}`);
    // --icon does not seem to work
    await ctx.bunShell`~/.config/opencode/wsl-notify-send.exe --appId "OpenCode" --category ${info.title ?? ctx.title} ${info.body}`.quiet();
  }
  catch (e) {
    console.error("Failed to run wsl-notify-send.exe", e);
  }
}

async function macosNotification(ctx: Context, info: Info): Promise<void> {
  // Also send bell to make it easier to find
  bellNotification();

  try {
    const title = (info.title ?? ctx.title).replace(/'/g, `"'"`);
    const body = info.body.replace(/'/g, `"'"`);

    await ctx.bunShell`osascript -e 'display notification "${body}" with title "${title}"'`.quiet()
  }
  catch (e) {
    console.error("Failed to run osascript", e);
  }
}

async function onEvent(ctx: Context, event: Event): Promise<void> {
  console.error(`event (event=${event.type})`, event)

  switch (event.type) {
    case "session.idle":
      const session = await ctx.client.session.get({ path: { id: event.properties.sessionID } });

      if (session.data?.parentID) {
        // Subagent
        return;
      }

      sendNotification(ctx, {
        body: "Done",
      })

      break;
    case "session.error":
      if (event.properties.error?.name === "MessageAbortedError") {
        return;
      }

      sendNotification(ctx, {
        body: "Error",
      })

      break;
    case "permission.asked":
      console.error("We got event for asked");
      sendNotification(ctx, {
        body: `Permission required ask`,
      });
  }
}

async function onToolExecuteBefore(ctx: Context, tool: string): Promise<void> {
  if (tool === "question") {
    sendNotification(ctx, {
      body: `Input required`,
    });
  }
}

async function onPermissionAsk(ctx: Context, input: Permission): Promise<void> {
  console.error("We ask");

  sendNotification(ctx, {
    body: `Permission required: ${input.title}`,
  });
}

export async function NotificationPlugin({ project, client, $, directory, worktree }: PluginInput): Promise<Hooks> {
  const projectName = path.basename(directory);
  const context = {
    projectName,
    bunShell: $,
    client,
    title: `OpenCode(${projectName})`,
  };

  return {
    event: ({ event }) => onEvent(context, event),
    "permission.ask": (input) => onPermissionAsk(context, input),
    "tool.execute.before": ({ tool }) => onToolExecuteBefore(context, tool),
  };
}
