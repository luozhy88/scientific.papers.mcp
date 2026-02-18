#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
QQ 邮箱 SMTP 发送测试（Python smtplib）
用法: python3 test_smtp.py <subject> <body_file> <to_email>
"""

import smtplib
import sys
import os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

FROM_EMAIL = "479321347@qq.com"
PASSWD     = os.environ.get("QQ_AUTH_CODE", "utdwpcjamkewcbbd")
TO_EMAIL   = os.environ.get("RECIPIENT_EMAIL", "479321347@qq.com")

def send_email(subject, body, to_email=TO_EMAIL, content_type='plain'):
    """
    发送邮件

    Args:
        subject: 邮件主题
        body: 邮件正文
        to_email: 收件人邮箱
        content_type: 'plain' 或 'html'
    """
    msg = MIMEMultipart()
    msg['From']    = FROM_EMAIL
    msg['To']      = to_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, content_type, 'utf-8'))

    try:
        server = smtplib.SMTP_SSL('smtp.qq.com', 465)
        server.login(FROM_EMAIL, PASSWD)
        server.sendmail(FROM_EMAIL, to_email, msg.as_string())
        server.quit()
        print("SUCCESS")
        return True
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    subject      = sys.argv[1] if len(sys.argv) > 1 else "测试"
    body_file    = sys.argv[2] if len(sys.argv) > 2 else None
    to_email     = sys.argv[3] if len(sys.argv) > 3 else TO_EMAIL
    content_type = sys.argv[4] if len(sys.argv) > 4 else 'plain'  # 支持 'plain' 或 'html'

    if body_file and os.path.exists(body_file):
        with open(body_file, 'r', encoding='utf-8') as f:
            body = f.read()
    else:
        body = sys.argv[2] if len(sys.argv) > 2 else "这是一封测试邮件"

    ok = send_email(subject, body, to_email, content_type)
    sys.exit(0 if ok else 1)
