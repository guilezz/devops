FROM python:latest

WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 80
CMD [ "python", "-u manage.py runserver 0.0.0.0:80" ]
