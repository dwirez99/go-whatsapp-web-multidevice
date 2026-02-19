############################
# STEP 1 build executable binary
############################
FROM golang:1.25-alpine3.23 AS builder
RUN apk update && apk add --no-cache gcc musl-dev gcompat
WORKDIR /whatsapp
COPY ./src .

# Fetch dependencies.
RUN go mod download
# Build the binary with optimizations
RUN go build -a -ldflags="-w -s" -o /app/whatsapp

#############################
## STEP 2 build a smaller image
#############################
FROM alpine:3.23
RUN apk add --no-cache ffmpeg libwebp-tools tzdata ca-certificates curl bash
ENV TZ=UTC
WORKDIR /app

# Copy compiled from builder.
COPY --from=builder /app/whatsapp /app/whatsapp

# Copy entrypoint script
COPY ./docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create ALL required directories with proper permissions BEFORE running the app
RUN mkdir -p \
    /app/storages \
    /app/statics \
    /app/statics/qrcode \
    /app/statics/senditems \
    /app/statics/media && \
    chmod 777 /app/storages /app/statics /app/statics/qrcode /app/statics/senditems /app/statics/media

# Health check to detect crashes
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Run via entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]