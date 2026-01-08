# 1. Start with a pre-built "Base Image" that has Python installed
FROM python:3.9-slim

# 2. Create a folder named /app inside the container and go there
WORKDIR /app

# 3. Copy our local "app.py" into the container's /app folder
COPY app.py .

# 4. The command to run when the container starts
CMD ["python", "app.py"]