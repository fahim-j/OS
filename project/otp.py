import smtplib
import random
import sys

receiver_email = sys.argv[1]
otp = str(random.randint(100000, 999999))

sender_email = "foysalmahamudfahim07@gmail.com"
app_password = "dktd wrjx qqkd fvmo"

subject = "Your OTP Code"
message = f"Subject: {subject}\n\nYour OTP is: {otp}"

try:
    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login(sender_email, app_password)
    server.sendmail(sender_email, receiver_email, message)
    server.quit()
    print(otp)
except Exception as e:
    print("ERROR")
