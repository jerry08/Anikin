#if ANDROID
global using Snackbar = Anikin.Controls.Snackbar;
#elif WINDOWS
global using Snackbar = CommunityToolkit.Maui.Alerts.Toast;
#endif
