import time

print("Hello! I am a long-running service now.")

# This loop keeps the app alive forever
while True:
    time.sleep(60)
    print("Still running...")