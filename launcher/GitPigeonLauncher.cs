// GitPigeon launcher
// The file users double-click. It carries the GitPigeon icon and version details,
// and quietly runs "Start GitPigeon.bat" from the same folder (no console window).
//
// Developed by : EMR Industries
// Build with   : tools\build-launcher.ps1  (version details come from GitPigeon.ps1)

using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

static class GitPigeonLauncher
{
    [STAThread]
    static void Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string bat = Path.Combine(dir, "Start GitPigeon.bat");

        if (!File.Exists(bat))
        {
            MessageBox.Show(
                "\"Start GitPigeon.bat\" was not found next to GitPigeon.exe.\n\n" +
                "Keep GitPigeon.exe in the GitPigeon folder with the other files.",
                "GitPigeon", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        try
        {
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = Path.Combine(Environment.SystemDirectory, "cmd.exe");
            psi.Arguments = "/c \"\"" + bat + "\"\"";   // quotes handle spaces in the path
            psi.WorkingDirectory = dir;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;                 // no black console window
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            MessageBox.Show("GitPigeon could not start:\n\n" + ex.Message,
                "GitPigeon", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
