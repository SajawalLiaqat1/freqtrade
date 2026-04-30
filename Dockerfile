FROM python:3.14.3-slim-trixie AS base

# Setup env
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONFAULTHANDLER=1
ENV PATH=/home/ftuser/.local/bin:$PATH
ENV FT_APP_ENV="docker"

# Prepare environment
RUN mkdir /freqtrade \
  && apt-get update \
  && apt-get -y install sudo libatlas3-base curl sqlite3 libgomp1 \
  && apt-get clean \
  && useradd -u 1000 -G sudo -U -m -s /bin/bash ftuser \
  && chown ftuser:ftuser /freqtrade \
  # Allow sudoers
  && echo "ftuser ALL=(ALL) NOPASSWD: /bin/chown" >> /etc/sudoers

WORKDIR /freqtrade

# Install dependencies
FROM base AS python-deps
RUN  apt-get update \
  && apt-get -y install build-essential libssl-dev git libffi-dev libgfortran5 pkg-config cmake gcc \
  && apt-get clean \
  && pip install --upgrade pip wheel

# Install dependencies
COPY --chown=ftuser:ftuser requirements.txt requirements-hyperopt.txt /freqtrade/
USER ftuser
RUN  pip install --user --no-cache-dir "numpy<3.0" \
  && pip install --user --no-cache-dir -r requirements-hyperopt.txt

# Copy dependencies to runtime-image
FROM base AS runtime-image
COPY --from=python-deps /usr/local/lib /usr/local/lib
ENV LD_LIBRARY_PATH=/usr/local/lib

COPY --from=python-deps --chown=ftuser:ftuser /home/ftuser/.local /home/ftuser/.local

USER ftuser
# Install and execute
COPY --chown=ftuser:ftuser . /freqtrade/

RUN pip install -e . --user --no-cache-dir \
  && mkdir /freqtrade/user_data/ \
  && freqtrade install-ui

# Create directories
RUN mkdir -p /freqtrade/user_data/strategies
RUN mkdir -p /freqtrade/user_data/logs

# Create config.json directly
RUN echo '{"trading_mode":"spot","max_open_trades":3,"stake_currency":"USDT","stake_amount":10,"dry_run":true,"dry_run_wallet":1000,"cancel_open_orders_on_exit":true,"exchange":{"name":"binance","key":"","secret":"","pair_whitelist":["BTC/USDT","ETH/USDT","BNB/USDT"]},"telegram":{"enabled":false,"token":"","chat_id":""},"api_server":{"enabled":true,"listen_ip_address":"0.0.0.0","listen_port":8080,"jwt_secret_key":"mytradingbot","username":"admin","password":"admin123"},"bot_name":"MyTradingBot","initial_state":"running","internals":{"process_throttle_secs":5}}' > /freqtrade/user_data/config.json

# Verify file created
RUN cat /freqtrade/user_data/config.json

CMD ["freqtrade", "trade", "--config", "/freqtrade/user_data/config.json", "--strategy", "SampleStrategy", "--userdir", "/freqtrade/user_data"]
