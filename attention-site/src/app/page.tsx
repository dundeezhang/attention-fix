import { Download, Play, Monitor, Zap, FolderOpen, Settings } from "lucide-react";

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-zinc-900 to-black text-white">
      {/* Hero Section */}
      <header className="container mx-auto px-6 py-16 text-center">
        <div className="mb-8 flex justify-center">
          <div className="rounded-2xl bg-gradient-to-br from-purple-500 to-pink-500 p-4">
            <Monitor className="h-12 w-12" />
          </div>
        </div>
        <h1 className="mb-4 text-5xl font-bold tracking-tight md:text-6xl">
          AttentionApp
        </h1>
        <p className="mx-auto mb-8 max-w-2xl text-xl text-zinc-400">
          Play videos and images while you wait for builds, installs, and terminal commands to finish.
        </p>
        <div className="flex flex-col items-center justify-center gap-4 sm:flex-row">
          <a
            href="#download"
            className="flex items-center gap-2 rounded-full bg-white px-8 py-3 font-semibold text-black transition hover:bg-zinc-200"
          >
            <Download className="h-5 w-5" />
            Download for macOS
          </a>
          <a
            href="#features"
            className="flex items-center gap-2 rounded-full border border-zinc-700 px-8 py-3 font-semibold transition hover:bg-zinc-800"
          >
            Learn More
          </a>
        </div>
      </header>

      {/* Demo Section */}
      <section className="container mx-auto px-6 py-16">
        <div className="overflow-hidden rounded-2xl border border-zinc-800 bg-zinc-900/50 shadow-2xl">
          <div className="flex items-center gap-2 border-b border-zinc-800 px-4 py-3">
            <div className="h-3 w-3 rounded-full bg-red-500" />
            <div className="h-3 w-3 rounded-full bg-yellow-500" />
            <div className="h-3 w-3 rounded-full bg-green-500" />
          </div>
          <div className="flex aspect-video items-center justify-center bg-black/50">
            <div className="text-center">
              <Play className="mx-auto mb-4 h-16 w-16 text-zinc-600" />
              <p className="text-zinc-500">Demo video coming soon</p>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="container mx-auto px-6 py-16">
        <h2 className="mb-12 text-center text-3xl font-bold">Features</h2>
        <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-3">
          <FeatureCard
            icon={<Zap className="h-6 w-6" />}
            title="Auto-Detection"
            description="Automatically detects npm, cargo, brew, make, and 50+ build tools and package managers."
          />
          <FeatureCard
            icon={<Play className="h-6 w-6" />}
            title="Media Support"
            description="Play videos (mp4, mov, mkv) or show images (png, jpg, gif, webp) while you wait."
          />
          <FeatureCard
            icon={<Monitor className="h-6 w-6" />}
            title="DVD Bounce Mode"
            description="Classic DVD screensaver mode - watch your video bounce around the screen."
          />
          <FeatureCard
            icon={<FolderOpen className="h-6 w-6" />}
            title="Custom Media Folder"
            description="Use your own videos and images from any folder on your Mac."
          />
          <FeatureCard
            icon={<Settings className="h-6 w-6" />}
            title="Menu Bar App"
            description="Lives in your menu bar. Toggle features, skip videos, and access settings with a click."
          />
          <FeatureCard
            icon={<Zap className="h-6 w-6" />}
            title="Lightweight"
            description="Built with Swift. No Electron, no bloat. Uses minimal resources."
          />
        </div>
      </section>

      {/* Supported Tools Section */}
      <section className="container mx-auto px-6 py-16">
        <h2 className="mb-8 text-center text-3xl font-bold">Supported Tools</h2>
        <p className="mx-auto mb-8 max-w-2xl text-center text-zinc-400">
          AttentionApp detects when these tools are running and plays your media automatically.
        </p>
        <div className="flex flex-wrap justify-center gap-3">
          {[
            "npm", "yarn", "pnpm", "bun", "cargo", "rustc", "go", "pip", "brew",
            "make", "cmake", "gcc", "clang", "swift", "gradle", "mvn", "dotnet",
            "composer", "gem", "mix", "zig", "tsc"
          ].map((tool) => (
            <span
              key={tool}
              className="rounded-full bg-zinc-800 px-4 py-2 text-sm font-mono"
            >
              {tool}
            </span>
          ))}
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="container mx-auto px-6 py-16">
        <div className="rounded-2xl bg-gradient-to-r from-purple-900/50 to-pink-900/50 p-12 text-center">
          <h2 className="mb-4 text-3xl font-bold">Download AttentionApp</h2>
          <p className="mb-8 text-zinc-400">
            Free and open source. Requires macOS 12.0 or later.
          </p>
          <div className="flex flex-col items-center justify-center gap-4 sm:flex-row">
            <a
              href="https://github.com/yourusername/AttentionApp/releases/latest"
              className="flex items-center gap-2 rounded-full bg-white px-8 py-3 font-semibold text-black transition hover:bg-zinc-200"
            >
              <Download className="h-5 w-5" />
              Download .zip
            </a>
            <a
              href="https://github.com/yourusername/AttentionApp"
              className="flex items-center gap-2 rounded-full border border-zinc-600 px-8 py-3 font-semibold transition hover:bg-zinc-800"
            >
              View on GitHub
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-zinc-800 py-8">
        <div className="container mx-auto px-6 text-center text-zinc-500">
          <p>Built with Swift for macOS</p>
        </div>
      </footer>
    </div>
  );
}

function FeatureCard({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-6">
      <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-lg bg-zinc-800">
        {icon}
      </div>
      <h3 className="mb-2 text-xl font-semibold">{title}</h3>
      <p className="text-zinc-400">{description}</p>
    </div>
  );
}
