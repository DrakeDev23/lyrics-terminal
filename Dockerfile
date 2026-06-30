FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    playerctl \
    dbus \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

ENTRYPOINT ["bash", "src/yt_karaoke.sh"]