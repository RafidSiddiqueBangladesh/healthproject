# Deploy Order: Backend First, Frontend Second

This project should be deployed in this order:
1. Backend on Render
2. Supabase Auth URL setup
3. Web frontend on Netlify
4. Mobile frontend build (Android/iOS)

## 1) Backend on Render

Deploy folder: `backend/`

Set these Render environment variables (from `backend/.env.example`):

- `NODE_ENV=production`
- `PORT=5000`
- `RENDER_EXTERNAL_URL=https://your-backend.onrender.com`
- `FRONTEND_URL=https://your-frontend.netlify.app`
- `FRONTEND_URLS=https://your-frontend.netlify.app,http://localhost:64616,http://127.0.0.1:64616`
- `SUPABASE_URL=https://your-project-ref.supabase.co`
- `SUPABASE_ANON_KEY=...`
- `SUPABASE_SERVICE_ROLE_KEY=...`
- `OPENROUTER_API_KEY=...` (if AI routes used)
- `YOUTUBE_API_KEY=...` (if YouTube search used)

After deploy, check health endpoint:
- `https://your-backend.onrender.com/api/health`

## 2) Supabase Auth URL Setup (Google OAuth)

In Supabase dashboard:
1. Go to Authentication -> URL Configuration.
2. Set Site URL to your Netlify domain:
   - `https://your-frontend.netlify.app`
3. Add Redirect URLs:
   - `https://your-frontend.netlify.app`
   - `https://your-frontend.netlify.app/`
   - `nutricare://login-callback/`
   - `http://localhost:64616` (for local web testing)

Important:
- Mobile deep link scheme used by app is `nutricare://login-callback/`.
- This is configured in Android and iOS app files.

## 3) Web Frontend on Netlify

File used: `netlify.toml`

Set Netlify environment variables:
- `API_BASE_URL=https://your-backend.onrender.com`
- `WEB_REDIRECT_URL=https://your-frontend.netlify.app`
- `SUPABASE_URL=https://your-project-ref.supabase.co`
- `SUPABASE_ANON_KEY=...`

Netlify build command already passes these values to Flutter using `--dart-define`.

## 4) Mobile Frontend Build

Build with dart-defines so mobile app talks to Render backend and Supabase:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-backend.onrender.com \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=MOBILE_REDIRECT_URL=nutricare://login-callback/
```

For iOS, use the same defines with `flutter build ios`.

## Notes

- Backend routes are protected with Supabase access token verification.
- CORS allows domains listed in `FRONTEND_URLS`.
- Mobile requests do not rely on browser CORS origin headers.
