# Backend API

The Kraxler API is built with Node.js, Express, and TypeScript.

## Requirements

- Node.js 22 or later
- npm 11 or later

## Local development

```sh
npm install
cp .env.example .env
npm run dev
```

The service listens on port `3000` by default.

## Available commands

- `npm run dev` — start the API and reload after source changes
- `npm run build` — compile the TypeScript application
- `npm test` — run the automated tests once
- `npm run test:watch` — rerun tests while files change
- `npm run lint` — check the source and tests for code-quality issues

## Service status

- `GET /health` confirms that the API process is running.
- `GET /ready` confirms that the API can serve requests. Database readiness
  will be included here once MongoDB is connected.

