import nodemailer from 'nodemailer';
import { env } from '../config/env';

let transporter: nodemailer.Transporter | null = null;

function getTransporter(): nodemailer.Transporter | null {
  if (!env.smtp.host) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: env.smtp.host,
      port: env.smtp.port,
      secure: env.smtp.port === 465,
      auth: env.smtp.user
        ? { user: env.smtp.user, pass: env.smtp.pass }
        : undefined,
    });
  }
  return transporter;
}

export async function sendPasswordResetEmail(email: string, resetToken: string): Promise<void> {
  const resetLink = `${env.mobileAppScheme}://reset-password?token=${resetToken}`;
  const webLink = `${env.frontendUrl}/reset-password?token=${resetToken}`;

  if (env.isDev || !env.smtp.host) {
    console.log('\n========== PASSWORD RESET (DEV) ==========');
    console.log(`To: ${email}`);
    console.log(`Token: ${resetToken}`);
    console.log(`Deep link: ${resetLink}`);
    console.log(`Web link:  ${webLink}`);
    console.log('Expires in 15 minutes');
    console.log('==========================================\n');
    return;
  }

  const t = getTransporter();
  if (!t) return;
  await t.sendMail({
    from: env.smtp.from,
    to: email,
    subject: 'AccessPlan UB - Нууц үг сэргээх',
    html: `
      <p>Сайн байна уу,</p>
      <p>Нууц үг сэргээх хүсэлт ирлээ. Доорх холбоосоор шинэчлэнэ үү:</p>
      <p><a href="${webLink}">${webLink}</a></p>
      <p>Энэ холбоос 15 минутын дараа хүчингүй болно.</p>
    `,
  });
}
