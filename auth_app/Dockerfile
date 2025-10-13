FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

EXPOSE 8000

# Печать номера варианта и дефолтная команда (может быть переопределена в docker-compose)
CMD /bin/sh -c "python -c \"from hashlib import sha3_256; study_group='211-331'; fullname='Скрыпник Василий Александрович'; suffix='Высоконагруженные системы. Лабораторная работа 2'; msg=f'{study_group} {fullname} {suffix}'; var_total=6; variant=int(sha3_256(msg.encode('utf-8')).hexdigest(),16)%var_total+1; print(f'Variant for LR2: {variant}')\" && gunicorn auth_project.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers ${GUNICORN_WORKERS:-3} --timeout ${GUNICORN_TIMEOUT:-60}"
