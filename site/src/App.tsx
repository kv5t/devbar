import {
  ArrowDown,
  Check,
  Copy,
  Github,
  Link2,
  Mail,
  Menu,
  Square,
  Terminal,
} from "lucide-react";
import { useState } from "react";
import type { PointerEvent } from "react";

const flowSteps = [
  {
    label: "Scan",
    title: "Detect running servers",
    copy: "DevBar runs lsof to find every TCP port in LISTEN state. Filters system ports, identifies process names, git branches, and project directories.",
    code: "lsof -iTCP -sTCP:LISTEN -n -P",
  },
  {
    label: "Flare",
    title: "Create a Cloudflare tunnel",
    copy: "Hover a server, click Flare. DevBar locates cloudflared, launches it, and captures the trycloudflare.com URL from stdout.",
    code: "cloudflared tunnel --url http://localhost:3000",
  },
  {
    label: "Share",
    title: "Copy the public URL",
    copy: "The public URL is copied to your clipboard instantly. Share it with clients, teammates, or test on mobile.",
    code: "https://brisk-river-demo.trycloudflare.com",
  },
];

const featureRows = [
  ["Port scanning", "lsof-based detection with configurable 2s/5s/10s/30s refresh intervals."],
  ["Cloudflare tunnels", "One-click trycloudflare.com URLs. Auto-installs cloudflared via Homebrew."],
  ["Docker containers", "Detects running containers and their exposed ports for tunneling."],
  ["Git integration", "Shows current branch next to each server. Identifies project names from git root."],
];

const activeTunnels = [
  {
    port: 3000,
    uptime: "2m 15s",
    local: "localhost:3000",
    public: "brisk-river-demo.trycloudflare.com",
  },
  {
    port: 8000,
    uptime: "5m 30s",
    local: "localhost:8000",
    public: "amber-meadow-123.trycloudflare.com",
  },
];

const servers = [
  {
    name: "my-project",
    branch: "main",
    port: 3000,
    uptime: "<1m",
  },
  {
    name: "api-server",
    branch: "develop",
    port: 8000,
    uptime: "5m 30s",
  },
];

const faqItems = [
  {
    id: "pricing",
    question: "How much does DevBar cost?",
    answer:
      "DevBar is free and open source under the MIT license. No account, no usage limits, no paid plan.",
  },
  {
    id: "how-it-works",
    question: "How does DevBar detect dev servers?",
    answer:
      "DevBar runs lsof -iTCP -sTCP:LISTEN -n -P to find all TCP ports in LISTEN state. It filters out system ports (<1024) and ephemeral ports (>=49152), then resolves each process's working directory, git branch, and project name. A whitelist filters out non-dev processes like Spotlight or AirPlayReceiver.",
  },
  {
    id: "cloudflare",
    question: "Do I need a Cloudflare account?",
    answer:
      "No. DevBar uses Cloudflare's temporary tunnel flow via cloudflared. The binary is auto-installed on first use via Homebrew or direct download. No DNS config, no dashboard, no login.",
  },
  {
    id: "docker",
    question: "Does DevBar work with Docker?",
    answer:
      "Yes. DevBar detects running Docker containers and their exposed ports. You can create Cloudflare tunnels for containerized services just like local servers.",
  },
  {
    id: "processes",
    question: "Which dev servers does DevBar detect?",
    answer:
      "Node, npm, bun, deno, python, python3, gunicorn, uvicorn, ruby, puma, go, cargo, elixir, erl, mix, java, php, dotnet, swift, http-server, serve, vite, webpack-dev-server, and more.",
  },
  {
    id: "lifetime",
    question: "How long does a tunnel URL stay live?",
    answer:
      "A tunnel URL stays live while your Mac is awake, your server is running, and the tunnel is active in DevBar. Stop the tunnel, quit the app, or shut down the server and the URL stops working immediately.",
  },
];

function StatusDot({ tone = "accent" }: { tone?: "accent" | "ember" | "cyan" }) {
  const color = {
    accent: "bg-accent",
    ember: "bg-ember",
    cyan: "bg-cyanic",
  }[tone];

  return <span className={`size-2 rounded-full ${color}`} aria-hidden="true" />;
}

function AppleLogoIcon() {
  return (
    <svg className="size-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701" />
    </svg>
  );
}

function updateGlowPosition(event: PointerEvent<HTMLDivElement>) {
  const rect = event.currentTarget.getBoundingClientRect();
  event.currentTarget.style.setProperty("--glow-x", `${event.clientX - rect.left}px`);
  event.currentTarget.style.setProperty("--glow-y", `${event.clientY - rect.top}px`);
}

function FaqAccordion() {
  const [openItem, setOpenItem] = useState<string | null>(faqItems[0].id);

  return (
    <div className="overflow-hidden rounded-lg border border-line bg-[#080907] shadow-2xl shadow-black/30 outline-1 -outline-offset-1 outline-white/10">
      {faqItems.map((item, index) => {
        const isOpen = openItem === item.id;
        const contentId = `faq-${item.id}`;

        return (
          <div key={item.id} className={index > 0 ? "border-t border-line" : undefined}>
            <h3>
              <button
                type="button"
                className="group flex w-full items-center justify-between gap-6 px-4 py-5 text-left focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-accent sm:px-5"
                aria-expanded={isOpen}
                aria-controls={contentId}
                onClick={() => setOpenItem(isOpen ? null : item.id)}
              >
                <span className="min-w-0 text-pretty font-mono text-base font-medium text-ink sm:text-sm">
                  {item.question}
                </span>
                <span className="relative grid size-7 shrink-0 place-items-center rounded-md border border-line bg-ink/5 text-accent">
                  <span className="absolute h-px w-3 bg-current" />
                  <span
                    className={`absolute h-3 w-px bg-current transition-[opacity,transform] duration-200 ${
                      isOpen ? "rotate-90 opacity-0" : "rotate-0 opacity-100"
                    }`}
                  />
                </span>
              </button>
            </h3>
            <div
              id={contentId}
              className={`grid transition-[grid-template-rows,opacity] duration-300 ease-out ${
                isOpen ? "grid-rows-[1fr] opacity-100" : "grid-rows-[0fr] opacity-0"
              }`}
            >
              <div className="overflow-hidden">
                <p className="max-w-[78ch] px-4 pb-5 text-pretty text-base text-ink/64 sm:px-5 sm:text-sm">
                  {item.answer}
                </p>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

export default function App() {
  return (
    <main className="isolate min-h-dvh overflow-x-hidden bg-paper font-sans text-ink">
      <div className="fixed inset-0 -z-10 bg-[radial-gradient(circle_at_50%_0%,rgba(59,130,246,0.10),transparent_34%),linear-gradient(180deg,rgba(255,255,255,0.04),transparent_42%)]" />
      <div className="fixed inset-0 -z-10 bg-[linear-gradient(rgba(244,241,232,0.035)_1px,transparent_1px),linear-gradient(90deg,rgba(244,241,232,0.035)_1px,transparent_1px)] bg-[size:48px_48px] [mask-image:linear-gradient(to_bottom,black,transparent_78%)]" />

      <header className="mx-auto flex w-full max-w-7xl items-center justify-between px-5 py-5 sm:px-8">
        <a href="#top" className="flex items-center" aria-label="DevBar home">
          <span className="brand-terminal-mark font-mono text-sm font-semibold text-ink">
            <span aria-hidden="true" className="inline-flex items-center gap-1.5">
              <svg className="size-4 text-accent" viewBox="0 0 24 24" fill="currentColor"><path d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
              devbar
            </span>
            <span className="brand-terminal-cursor" aria-hidden="true" />
          </span>
        </a>

        <nav className="hidden items-center gap-6 font-mono text-sm sm:flex">
          <a className="text-ink/62 hover:text-ink" href="#flow">
            <span className="text-ink/40">~/</span>
            flow
          </a>
          <a className="text-ink/62 hover:text-ink" href="#details">
            <span className="text-ink/40">~/</span>
            details
          </a>
        </nav>
      </header>

      <section id="top" className="mx-auto grid w-full max-w-7xl gap-10 px-5 pb-16 pt-8 sm:px-8 lg:grid-cols-[15fr_17fr] lg:items-center lg:pb-24 lg:pt-14">
        <div className="flex flex-col gap-8">
          <div className="flex w-fit items-center gap-2 rounded-full border border-line bg-ink/4 px-3 py-1.5 font-mono text-base text-ink/72 sm:text-sm">
            <StatusDot />
            native macOS menu bar
          </div>

          <div className="flex flex-col gap-5">
            <h1
              className="inline-flex w-fit flex-col items-start font-heading text-5xl font-semibold text-ink sm:text-6xl lg:text-7xl"
              aria-label="Dev Servers to Public URLs"
            >
              <span className="block">dev servers</span>
              <span className="flex h-12 -translate-x-[0.18em] items-center self-center sm:h-14 lg:h-16" aria-hidden="true">
                <ArrowDown className="size-9 shrink-0 stroke-accent sm:size-10 lg:size-11" strokeWidth={3.25} />
              </span>
              <span className="block">public URLs</span>
            </h1>
            <p className="max-w-[58ch] text-pretty text-lg text-ink/68 sm:text-base">
              DevBar lives in your menu bar. Scans your ports, identifies dev servers, and creates Cloudflare tunnels in one click. No config needed.
            </p>
          </div>

          <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
            <a
              href="https://github.com/kv5t/devbar/releases/latest"
              rel="noreferrer"
              className="inline-flex items-center justify-center gap-2 rounded-md border border-line bg-ink/5 px-4 py-3 text-base font-medium text-ink hover:border-accent/50 hover:text-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent sm:text-sm"
            >
              <AppleLogoIcon />
              Download for Mac
            </a>
            <p className="font-mono text-base text-ink/62 sm:text-sm">
              No Sign Up.
              <br />
              Free Forever.
            </p>
          </div>

        </div>

        <div className="relative min-w-0">
          <div className="absolute -inset-6 -z-10 rounded-[min(2vw,24px)] bg-accent/8 blur-3xl" />
          <div className="overflow-hidden rounded-[min(2vw,18px)] border border-ink/10 bg-[#171816] shadow-2xl shadow-black/50 outline-1 -outline-offset-1 outline-white/10">
            {/* macOS title bar */}
            <div className="flex items-center justify-between border-b border-white/10 bg-[#1a1a1a] px-4 py-3 font-mono text-base text-ink/70 sm:text-sm">
              <div className="flex items-center gap-2">
                <span className="size-3 rounded-full bg-[#ff5f57]" />
                <span className="size-3 rounded-full bg-[#ffbd2e]" />
                <span className="size-3 rounded-full bg-[#28c840]" />
              </div>
              <div className="flex items-center gap-4">
                <span>Sun 10:55 AM</span>
                <span className="flex items-center gap-2 text-ink">
                  <Menu className="size-4" aria-hidden="true" />
                  DevBar
                </span>
              </div>
            </div>

            <div className="relative bg-[linear-gradient(135deg,rgba(255,255,255,0.03),transparent_45%),#10110f] p-4 sm:p-6">
              <div className="mx-auto max-w-md overflow-hidden rounded-xl border border-white/10 bg-[#0d0d0d]/95 shadow-2xl shadow-black/70">

                {/* Header: devbar brand + counters + buttons */}
                <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-sm font-bold text-white">devbar</span>
                    <span className="size-1.5 rounded-full bg-green-500" />
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="flex items-center gap-1 rounded-full bg-white/5 px-2 py-0.5 font-mono text-xs text-ink/70">
                      <svg className="size-3 text-accent" viewBox="0 0 24 24" fill="currentColor"><path d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
                      3
                    </span>
                    <span className="flex items-center gap-1 rounded-full bg-white/5 px-2 py-0.5 font-mono text-xs text-green-400">
                      <Link2 className="size-3" />
                      1
                    </span>
                    <span className="rounded-full bg-white/5 p-1 text-ink/40">
                      <svg className="size-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg>
                    </span>
                    <span className="rounded-full bg-white/5 p-1 text-ink/40">
                      <svg className="size-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/></svg>
                    </span>
                  </div>
                </div>

                {/* Tunnels section */}
                <div className="px-4 pt-3 pb-2">
                  <div className="mb-2 flex items-center gap-2">
                    <span className="size-1.5 rounded-full bg-green-500" />
                    <span className="font-mono text-[10px] font-semibold tracking-widest text-ink/50">TUNNELS</span>
                    <span className="ml-auto font-mono text-[10px] text-ink/30">1</span>
                  </div>
                  <div className="rounded-md border border-white/5 bg-white/[0.02] px-3 py-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="size-1.5 rounded-full bg-green-500" />
                        <span className="font-mono text-xs font-semibold text-ink">Port 3000</span>
                        <span className="font-mono text-[10px] text-ink/30">2m 15s</span>
                      </div>
                    </div>
                    <div className="mt-1.5 space-y-0.5">
                      <p className="font-mono text-[11px] text-ink/60">
                        <span className="text-orange-400">l:</span> localhost:3000
                      </p>
                      <p className="font-mono text-[11px] text-ink/60">
                        <span className="text-green-400">p:</span> brisk-river-demo.trycloudflare.com
                      </p>
                    </div>
                  </div>
                </div>

                {/* Divider */}
                <div className="mx-4 border-t border-white/5" />

                {/* Servers section */}
                <div className="px-4 pt-2 pb-3">
                  <div className="mb-2 flex items-center gap-2">
                    <span className="size-1.5 rounded-full bg-blue-500" />
                    <span className="font-mono text-[10px] font-semibold tracking-widest text-ink/50">SERVEURS</span>
                    <span className="ml-auto font-mono text-[10px] text-ink/30">2</span>
                  </div>

                  <div className="space-y-1">
                    {servers.map((s) => (
                      <div key={s.name} className="flex items-center justify-between rounded-md px-2 py-1.5 hover:bg-white/[0.02]">
                        <div className="flex items-center gap-2">
                          <span className="size-1.5 rounded-full bg-blue-500" />
                          <span className="font-mono text-xs font-medium text-ink">{s.name}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="flex items-center gap-1 font-mono text-[10px] text-ink/30">
                            <svg className="size-2.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M6 3v12"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M18 9a9 9 0 0 1-9 9"/></svg>
                            {s.branch}
                          </span>
                          <span className="font-mono text-[10px] text-ink/30">:{s.port}</span>
                          <span className="font-mono text-[10px] text-ink/20">{s.uptime}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>

              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="flow" className="border-y border-line bg-ink/[0.025]">
        <div className="mx-auto grid max-w-7xl gap-4 px-5 py-16 sm:px-8 lg:grid-cols-3">
          {flowSteps.map((step, index) => (
            <div
              key={step.title}
              className="flow-glow-card min-w-0 overflow-hidden rounded-lg border border-line bg-paper/88 p-5"
              onPointerMove={updateGlowPosition}
            >
              <div className="relative z-10 mb-8 flex items-center justify-between font-mono text-base sm:text-sm">
                <span className="text-accent">0{index + 1}</span>
                <span className="rounded-full border border-line px-2 py-1 text-ink/62">{step.label}</span>
              </div>
              <h2 className="relative z-10 max-w-[18ch] text-balance font-heading text-2xl font-semibold text-ink">
                {step.title}
              </h2>
              <p className="relative z-10 mt-3 text-pretty text-base text-ink/64 sm:text-sm">{step.copy}</p>
              <div className="relative z-20 mt-5 min-h-20 break-all rounded-md border border-line bg-[#070806] p-3 font-mono text-base text-ink/72 sm:text-sm">
                {step.code}
              </div>
            </div>
          ))}
        </div>
      </section>

      <section id="details" className="border-b border-line">
        <div className="mx-auto max-w-7xl px-5 py-20 sm:px-8">
          <div className="max-w-3xl">
            <div className="flex w-fit items-center gap-2 rounded-full border border-line bg-ink/4 px-3 py-1.5 font-mono text-base text-ink/72 sm:text-sm">
              <StatusDot tone="cyan" />
              built for developers
            </div>
            <h2 className="mt-5 max-w-[15ch] text-balance font-heading text-4xl font-semibold text-ink sm:text-5xl">
              No dashboard. No accounts.
            </h2>
            <p className="mt-5 max-w-[58ch] text-pretty text-lg text-ink/64 sm:text-base">
              DevBar scans your ports, shows your servers, and gives you public URLs. That's it. No web dashboard, no Cloudflare login, no config files.
            </p>
          </div>

          <div className="mt-9 overflow-hidden rounded-lg border border-line bg-[#080907] shadow-2xl shadow-black/30 outline-1 -outline-offset-1 outline-white/10">
            <div className="flex flex-col gap-3 border-b border-line bg-[#171816] px-4 py-3 font-mono text-base text-ink/70 sm:flex-row sm:items-center sm:justify-between sm:text-sm">
              <div className="flex items-center gap-2 text-ink">
                <Terminal className="size-4 text-accent" aria-hidden="true" />
                devbar rules
              </div>
              <div className="text-ink/52">scan &rarr; flare &rarr; share</div>
            </div>

            <dl className="grid divide-y divide-line sm:grid-cols-2 sm:divide-x sm:divide-y-0 lg:grid-cols-4">
              {featureRows.map(([title, copy], index) => (
                <div key={title} className="min-h-44 p-5">
                  <div className="mb-8 flex items-center justify-between font-mono text-base sm:text-sm">
                    <span className="text-ink/52">0{index + 1}</span>
                    <Check className="size-4 text-accent" aria-hidden="true" />
                  </div>
                  <dt className="font-mono text-base text-accent sm:text-sm">{title}</dt>
                  <dd className="mt-3 text-pretty text-base text-ink/64 sm:text-sm">{copy}</dd>
                </div>
              ))}
            </dl>
          </div>
        </div>
      </section>

      <section className="mx-auto grid max-w-7xl gap-6 px-5 pb-20 pt-14 sm:px-8 lg:grid-cols-[9fr_15fr] lg:items-center">
        <div className="flex flex-col gap-5">
          <div className="flex w-fit items-center gap-2 rounded-full border border-line bg-ink/4 px-3 py-1.5 font-mono text-base text-ink/72 sm:text-sm">
            <StatusDot />
            live tunnels
          </div>
          <h2 className="max-w-[12ch] text-balance font-heading text-4xl font-semibold text-ink sm:text-5xl">
            Tunnels live in the menu bar.
          </h2>
          <p className="max-w-[50ch] text-pretty text-lg text-ink/64 sm:text-base">
            Each tunnel shows its local and public URL. Copy the public link, open it, or stop the tunnel — all from the popover.
          </p>
        </div>

        <div className="overflow-hidden rounded-lg border border-line bg-[#080907] shadow-2xl shadow-black/40 outline-1 -outline-offset-1 outline-white/10">
          <div className="flex items-center justify-between border-b border-line bg-[#171816] px-4 py-3 font-mono text-base text-ink/70 sm:text-sm">
            <div className="flex items-center gap-2">
              <Link2 className="size-4 text-accent" aria-hidden="true" />
              active tunnels
            </div>
            <div className="flex items-center gap-2 text-ink/56">
              <Menu className="size-4" aria-hidden="true" />
              DevBar
            </div>
          </div>

          <div className="grid gap-3 p-4">
            {activeTunnels.map((tunnel, index) => (
              <div
                key={tunnel.port}
                className="rounded-md border border-line bg-paper/88 p-4"
              >
                <div className="mb-3 flex items-center gap-2 font-mono text-base text-ink sm:text-sm">
                  <span className="size-2 rounded-full bg-green-500" />
                  <span>Port {tunnel.port}</span>
                  <span className="rounded-full border border-line px-2 py-0.5 text-ink/56">
                    {tunnel.uptime}
                  </span>
                </div>
                <div className="grid gap-1.5 font-mono text-base sm:text-sm">
                  <p className="text-ink/40">
                    <span className="text-orange-400">l:</span> {tunnel.local}
                  </p>
                  <p className="text-green-400">
                    <span className="text-green-500">p:</span> {tunnel.public}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-t border-line bg-ink/[0.025]">
        <div className="mx-auto grid max-w-7xl gap-9 px-5 py-20 sm:px-8 lg:grid-cols-[9fr_15fr] lg:items-start">
          <div className="flex flex-col gap-5">
            <div className="flex w-fit items-center gap-2 rounded-full border border-line bg-ink/4 px-3 py-1.5 font-mono text-base text-ink/72 sm:text-sm">
              <StatusDot tone="cyan" />
              questions
            </div>
            <h2 className="max-w-[12ch] text-balance font-heading text-4xl font-semibold text-ink sm:text-5xl">
              Good to know before you share.
            </h2>
            <p className="max-w-[50ch] text-pretty text-lg text-ink/64 sm:text-base">
              DevBar is free, open source, and built for local development. No strings attached.
            </p>
          </div>

          <FaqAccordion />
        </div>
      </section>

      <section id="status" className="relative h-[clamp(8.75rem,20vw,17rem)] overflow-hidden border-t border-line">
        <div className="flex h-full w-full items-end justify-center px-5 sm:px-8">
          <p className="status-wordmark translate-y-[10px] whitespace-nowrap font-mono font-semibold flex items-center gap-1.5" aria-label="DevBar">
            <svg className="size-4 text-accent" viewBox="0 0 24 24" fill="currentColor"><path d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>
            devbar
          </p>
        </div>
      </section>

      <footer className="border-t border-line">
        <div className="mx-auto flex max-w-7xl flex-col gap-4 px-5 py-6 font-mono text-base text-ink/52 sm:flex-row sm:items-center sm:justify-between sm:px-8 sm:text-sm">
          <p>DevBar by kv5t</p>
          <div className="flex items-center gap-3">
            <a
              href="https://github.com/kv5t/devbar"
              target="_blank"
              rel="noreferrer"
              className="grid size-9 place-items-center rounded-md border border-line bg-ink/5 text-ink/72 hover:border-accent/50 hover:text-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
              aria-label="View DevBar on GitHub"
            >
              <Github className="size-4" aria-hidden="true" />
            </a>
            <a
              href="mailto:contact@devbar.app"
              className="grid size-9 place-items-center rounded-md border border-line bg-ink/5 text-ink/72 hover:border-accent/50 hover:text-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
              aria-label="Email DevBar"
            >
              <Mail className="size-4" aria-hidden="true" />
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
