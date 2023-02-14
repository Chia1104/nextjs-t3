FROM node:18-alpine AS deps
RUN apk add --no-cache libc6-compat

WORKDIR /app
COPY package.json pnpm-lock.yaml ./

RUN yarn global add pnpm && \
    pnpm i

FROM node:18-alpine AS builder

WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG \
    DATABASE_URL
ENV \
    DATABASE_URL=${DATABASE_URL}

RUN yarn build

FROM node:18-alpine AS runner

WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.js ./next.config.js

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

ARG \
    DATABASE_URL \
    NEXTAUTH_URL \
    DISCORD_CLIENT_ID \
    DISCORD_CLIENT_SECRET
ENV \
    DATABASE_URL=${DATABASE_URL} \
    NEXTAUTH_URL=${NEXTAUTH_URL} \
    DISCORD_CLIENT_ID=${DISCORD_CLIENT_ID} \
    DISCORD_CLIENT_SECRET=${DISCORD_CLIENT_SECRET}

USER nextjs

EXPOSE 8080

ENV PORT 8080

CMD ["node", "server.js"]
