function mailTome(subject,content)
MailAddress = 'lushuai1004@outlook.com';
password = 'slovey1992100419';
setpref('Internet','E_mail',MailAddress);
setpref('Internet','SMTP_Server','smtp.office365.com');
setpref('Internet','SMTP_Username',MailAddress);
setpref('Internet','SMTP_Password',password);
props = java.lang.System.getProperties;
props.remove('mail.smtp.socketFactory.class');
props.setProperty('mail.smtp.auth','true');
props.setProperty('mail.smtp.starttls.enable', 'true' );
props.setProperty('mail.smtp.socketFactory.port','587');
sendmail('lushuai1004@outlook.com',subject,content);
end