#!/usr/bin/env bash
# Lays down a complete, runnable PopKult admin-frontend scaffold into
# <target_dir> for backend service <service>. Pure file generation — no
# npm install, no git, no interactive `npm create`; the SKILL.md phase
# that calls this does the install + verify + commit afterwards.
#
# Stack is fixed (see skills/init-frontend/SKILL.md for the rationale):
#   React + Vite + TypeScript + Apollo Client + GraphQL Code Generator
#   (client preset), served in prod as a static build behind nginx with
#   a runtime-substituted config.js so one image works across envs.
#
# The GraphQL schema is VENDORED: this copies
# ../schema/graphql/<service>.graphqls into schema/<service>.graphqls so
# codegen (and CI) never need the private schema repo checked out.
# scripts/sync-schema.sh in the generated repo refreshes that copy.
#
# Two modes, same as init-service's copy-and-rename.sh:
#   - <target_dir> doesn't exist        -> fresh scaffold, caller runs git init
#   - <target_dir> exists as a git repo -> merge scaffold in, leave .git
#     and .idea alone; refuse if it already has frontend code
#     (package.json or src/).
#
# Dependency versions below are FLOORS captured when this script was
# written — bump them to current stable before committing if they've
# aged, the same judgment call service-template's own deps get.
#
# Usage: scaffold-frontend.sh <target_dir> <service>
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <target_dir> <service>" >&2
  exit 1
fi

target_dir="$1"
service="$2"

if ! printf '%s' "$service" | grep -Eq '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
  echo "error: <service> must be lowercase kebab-case: $service" >&2
  exit 1
fi

if [ -e "$target_dir" ]; then
  if [ ! -d "$target_dir/.git" ]; then
    echo "error: $target_dir exists and is not a git repo, refusing to scaffold into it" >&2
    exit 1
  fi
  if [ -e "$target_dir/package.json" ] || [ -d "$target_dir/src" ]; then
    echo "error: $target_dir already contains frontend code (package.json / src/), refusing" >&2
    exit 1
  fi
  echo "destination exists as a git repo — merging scaffold into it: $target_dir"
else
  mkdir -p "$target_dir"
fi

cd "$target_dir"
mkdir -p src/app src/components src/pages src/graphql schema deployments/docker .github/workflows scripts public

# ---- package.json ---------------------------------------------------------
cat > package.json <<EOF
{
  "name": "${service}-frontend",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "codegen": "graphql-codegen --config codegen.ts",
    "typecheck": "tsc -b --noEmit",
    "lint": "eslint .",
    "schema:sync": "bash scripts/sync-schema.sh"
  },
  "dependencies": {
    "@apollo/client": "^3.12.0",
    "graphql": "^16.10.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^7.1.0"
  },
  "devDependencies": {
    "@graphql-codegen/cli": "^5.0.3",
    "@graphql-codegen/client-preset": "^4.5.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.3.4",
    "eslint": "^9.17.0",
    "eslint-plugin-react-hooks": "^5.1.0",
    "eslint-plugin-react-refresh": "^0.4.16",
    "typescript": "~5.7.2",
    "typescript-eslint": "^8.18.0",
    "vite": "^6.0.0"
  }
}
EOF

# ---- .gitignore (append missing lines, don't clobber) --------------------
touch .gitignore
for line in node_modules dist ".env" ".env.local" "*.local" "src/graphql/generated/"; do
  grep -qxF "$line" .gitignore || printf '%s\n' "$line" >> .gitignore
done

# ---- tsconfig ------------------------------------------------------------
cat > tsconfig.json <<'EOF'
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
EOF

cat > tsconfig.app.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noEmit": true,
    "skipLibCheck": true,
    "verbatimModuleSyntax": true
  },
  "include": ["src"]
}
EOF

cat > tsconfig.node.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["vite.config.ts", "codegen.ts"]
}
EOF

# ---- vite / eslint / prettier ------------------------------------------
cat > vite.config.ts <<'EOF'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
});
EOF

cat > eslint.config.js <<'EOF'
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

export default tseslint.config(
  { ignores: ["dist", "src/graphql/generated"] },
  {
    files: ["**/*.{ts,tsx}"],
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    plugins: { "react-hooks": reactHooks, "react-refresh": reactRefresh },
    rules: {
      ...reactHooks.configs.recommended.rules,
      "react-refresh/only-export-components": ["warn", { allowConstantExport: true }],
    },
  },
);
EOF

cat > .prettierrc.json <<'EOF'
{ "semi": true, "singleQuote": false, "trailingComma": "all", "printWidth": 100 }
EOF

# ---- codegen -----------------------------------------------------------
cat > codegen.ts <<EOF
import type { CodegenConfig } from "@graphql-codegen/cli";

// Schema is the VENDORED copy in schema/ — refresh it with
// \`npm run schema:sync\` (pulls from ../schema/graphql/${service}.graphqls).
// Codegen deliberately does NOT hit a live endpoint: CI has no access to
// the private schema repo or a running service.
const config: CodegenConfig = {
  schema: "schema/${service}.graphqls",
  documents: ["src/**/*.{ts,tsx}"],
  ignoreNoDocuments: true,
  generates: {
    "src/graphql/generated/": {
      preset: "client",
      config: { useTypeImports: true },
    },
  },
};

export default config;
EOF

# ---- env + runtime config --------------------------------------------
cat > .env.example <<'EOF'
# Dev-only fallback GraphQL endpoint. In a built image this is ignored —
# public/config.js is rendered at container start from GRAPHQL_ENDPOINT
# (see deployments/docker/). Copy to .env.local to override locally.
VITE_GRAPHQL_ENDPOINT=http://localhost:8080/query
EOF

cat > public/config.js <<'EOF'
// Dev default. Overwritten at container start by
// deployments/docker/40-render-config.sh from $GRAPHQL_ENDPOINT.
window.__CONFIG__ = { graphqlEndpoint: "http://localhost:8080/query" };
EOF

cat > index.html <<EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${service} · admin</title>
    <script src="/config.js"></script>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# ---- src -------------------------------------------------------------
cat > src/vite-env.d.ts <<'EOF'
/// <reference types="vite/client" />

interface Window {
  __CONFIG__?: { graphqlEndpoint: string };
}

interface ImportMetaEnv {
  readonly VITE_GRAPHQL_ENDPOINT?: string;
}
interface ImportMeta {
  readonly env: ImportMetaEnv;
}
EOF

cat > src/app/runtime-config.ts <<'EOF'
// Endpoint resolution order: window.__CONFIG__ (rendered into config.js
// at container start) -> Vite build-time env -> localhost dev default.
export const runtimeConfig = {
  graphqlEndpoint:
    window.__CONFIG__?.graphqlEndpoint ??
    import.meta.env.VITE_GRAPHQL_ENDPOINT ??
    "http://localhost:8080/query",
};
EOF

cat > src/app/apollo.ts <<'EOF'
import { ApolloClient, HttpLink, InMemoryCache } from "@apollo/client";
import { runtimeConfig } from "./runtime-config";

// Auth: left unconfigured on purpose. The init-frontend interview
// decides what the target service's GraphQL edge expects (JWT, static
// token, nothing) — wire it here with setContext / an auth link then.
export const apolloClient = new ApolloClient({
  link: new HttpLink({ uri: runtimeConfig.graphqlEndpoint }),
  cache: new InMemoryCache(),
});
EOF

cat > src/app/routes.tsx <<'EOF'
import { createBrowserRouter } from "react-router-dom";
import { Layout } from "../components/Layout";
import { Overview } from "../pages/Overview";

// Entity list/detail routes are added by the init-frontend implementation
// phase, one abstraction at a time.
export const router = createBrowserRouter([
  {
    path: "/",
    element: <Layout />,
    children: [{ index: true, element: <Overview /> }],
  },
]);
EOF

cat > src/components/Layout.tsx <<EOF
import { Link, Outlet } from "react-router-dom";

export function Layout() {
  return (
    <div style={{ display: "flex", minHeight: "100vh", fontFamily: "system-ui" }}>
      <nav style={{ width: 220, padding: 16, borderRight: "1px solid #ddd" }}>
        <strong>${service} admin</strong>
        <ul style={{ listStyle: "none", padding: 0, marginTop: 16 }}>
          <li>
            <Link to="/">Overview</Link>
          </li>
        </ul>
      </nav>
      <main style={{ flex: 1, padding: 24 }}>
        <Outlet />
      </main>
    </div>
  );
}
EOF

cat > src/pages/Overview.tsx <<EOF
import { useQuery } from "@apollo/client";
import { graphql } from "../graphql/generated";

// Placeholder landing page. The init-frontend implementation phase
// replaces this with the "abstractions overview" — one card per domain
// entity the ${service} GraphQL surface exposes, linking to its views.
//
// The __typename ping doubles as the scaffold's connectivity check and
// as the one operation that keeps codegen's output non-empty until real
// operations land. Keep at least one graphql() call in the tree.
const PingQuery = graphql(\`
  query AdminOverviewPing {
    __typename
  }
\`);

export function Overview() {
  const { data, loading, error } = useQuery(PingQuery);
  return (
    <div>
      <h1>${service} admin board</h1>
      <p>Scaffold is live. Entity views are added by the implementation phase.</p>
      <p>
        GraphQL endpoint:{" "}
        {loading ? "checking…" : error ? \`unreachable (\${error.message})\` : \`reachable (\${data?.__typename})\`}
      </p>
    </div>
  );
}
EOF

cat > src/main.tsx <<'EOF'
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { ApolloProvider } from "@apollo/client";
import { RouterProvider } from "react-router-dom";
import { apolloClient } from "./app/apollo";
import { router } from "./app/routes";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ApolloProvider client={apolloClient}>
      <RouterProvider router={router} />
    </ApolloProvider>
  </StrictMode>,
);
EOF

# ---- schema vendoring -----------------------------------------------
schema_src=""
for cand in "../schema/graphql/${service}.graphqls" "../../schema/graphql/${service}.graphqls"; do
  if [ -f "$cand" ]; then
    schema_src="$cand"
    break
  fi
done
if [ -n "$schema_src" ]; then
  cp "$schema_src" "schema/${service}.graphqls"
  echo "vendored schema from $schema_src"
else
  cat > "schema/${service}.graphqls" <<EOF
# Vendored copy of github.com/PopKult/schema :: graphql/${service}.graphqls
# Could not find ../schema locally at scaffold time — run
# \`npm run schema:sync\` once the schema repo is a sibling checkout.
type Query {
  _placeholder: Boolean
}
EOF
  echo "WARNING: ../schema/graphql/${service}.graphqls not found — wrote a placeholder schema" >&2
fi

cat > scripts/sync-schema.sh <<EOF
#!/usr/bin/env bash
# Refreshes the vendored GraphQL schema from the sibling schema repo.
set -euo pipefail
src="\$(dirname "\$0")/../../schema/graphql/${service}.graphqls"
if [ ! -f "\$src" ]; then
  echo "error: \$src not found — is github.com/PopKult/schema checked out as a sibling?" >&2
  exit 1
fi
cp "\$src" "\$(dirname "\$0")/../schema/${service}.graphqls"
echo "synced schema/${service}.graphqls from \$src"
EOF
chmod +x scripts/sync-schema.sh

# ---- deployments/docker -------------------------------------------
cat > deployments/docker/Dockerfile <<'EOF'
# syntax=docker/dockerfile:1

FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run codegen && npm run build

FROM nginx:1.27-alpine
COPY deployments/docker/nginx.conf /etc/nginx/conf.d/default.conf
# nginx:alpine runs every /docker-entrypoint.d/*.sh before starting.
COPY deployments/docker/40-render-config.sh /docker-entrypoint.d/40-render-config.sh
RUN chmod +x /docker-entrypoint.d/40-render-config.sh
COPY --from=build /app/dist /usr/share/nginx/html
EOF

cat > deployments/docker/nginx.conf <<'EOF'
server {
  listen 80;
  root /usr/share/nginx/html;
  index index.html;

  # SPA fallback — every unknown path serves the app shell.
  location / {
    try_files $uri /index.html;
  }

  # config.js is regenerated per-container; never let it be cached.
  location = /config.js {
    add_header Cache-Control "no-store";
  }
}
EOF

cat > deployments/docker/40-render-config.sh <<'EOF'
#!/bin/sh
set -e
: "${GRAPHQL_ENDPOINT:=/graphql}"
cat > /usr/share/nginx/html/config.js <<CFG
window.__CONFIG__ = { graphqlEndpoint: "${GRAPHQL_ENDPOINT}" };
CFG
echo "rendered config.js with graphqlEndpoint=${GRAPHQL_ENDPOINT}"
EOF
chmod +x deployments/docker/40-render-config.sh

# ---- CI -----------------------------------------------------------
cat > .github/workflows/ci.yml <<'EOF'
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      # Schema is vendored (schema/*.graphqls is committed), so codegen
      # runs with no access to the private schema repo.
      - run: npm run codegen
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run build
EOF

# ---- README ------------------------------------------------------
cat > README.md <<EOF
# ${service}-frontend

Admin board for the \`${service}\` PopKult service — a GraphQL client that
lets an operator inspect and manage the abstractions \`${service}\` owns.

> **Scaffold status.** This section is a placeholder. The \`init-frontend\`
> skill's interview phase replaces it with the real admin-board
> requirements: which abstractions get views, what each view shows, which
> mutations are exposed as actions, and the auth model. Delete this
> blockquote when that lands.

## Stack

React + Vite + TypeScript, Apollo Client, GraphQL Code Generator (client
preset). Served in production as a static build behind nginx.

## GraphQL schema

The schema is **vendored** at \`schema/${service}.graphqls\`, copied from
\`github.com/PopKult/schema\` (\`graphql/${service}.graphqls\`). Refresh it
with \`npm run schema:sync\` when that repo changes. Codegen and CI never
need the schema repo checked out.

## Local development

\`\`\`
npm install
npm run codegen        # regenerate typed hooks from the vendored schema
npm run dev            # http://localhost:5173
\`\`\`

The dev server talks to the endpoint in \`VITE_GRAPHQL_ENDPOINT\` (see
\`.env.example\`); copy it to \`.env.local\` to point at your running
\`${service}\`.

## Runtime config

The built image reads its GraphQL endpoint from the \`GRAPHQL_ENDPOINT\`
env var at container start (\`deployments/docker/40-render-config.sh\`
renders it into \`config.js\`), so one image works across every
environment. \`prod-setup/services/${service}-frontend/\` sets it via
ConfigMap; \`local-setup\` sets it in the compose block.

## Deployment

- k8s manifests: \`github.com/PopKult/prod-setup\` ::
  \`services/${service}-frontend/\`
- local dev stack: \`github.com/PopKult/local-setup\` :: the
  \`${service}-frontend\` compose block
EOF

echo "Scaffolded ${service}-frontend into ${target_dir}"
