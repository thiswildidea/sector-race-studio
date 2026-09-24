// 行业板块竞速动画工作室 —— EXE 启动器
//
// 应用本体是一个嵌入到本 exe 里的 HTML。运行时把它释放到 LocalAppData，
// 再用 Edge/Chrome 的 --app 模式打开：无地址栏、无标签页，就是一个独立应用窗口。
// 之所以借用系统浏览器内核，是因为 MP4 的 H.264 编码能力由它提供（MediaRecorder），
// 这样程序本身不需要携带任何编解码器，也不依赖 ffmpeg。

using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("行业板块竞速动画工作室")]
[assembly: AssemblyDescription("A股行业与主题板块竖屏竞速动画生成器，导出抖音规格 MP4")]
[assembly: AssemblyProduct("行业板块竞速动画工作室")]
[assembly: AssemblyCompany("Personal Tools")]
[assembly: AssemblyCopyright("Personal use")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class Program
{
    private const string AppName = "行业板块竞速动画工作室";
    private const string ResourceName = "APPHTML";

    [STAThread]
    private static void Main()
    {
        try
        {
            Launch();
        }
        catch (Exception ex)
        {
            MessageBox.Show("启动失败：\n\n" + ex.Message, AppName,
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static void Launch()
    {
        string root = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "SectorRaceStudio");
        Directory.CreateDirectory(root);

        // 每次启动都重新释放，保证内置应用是最新版本
        string htmlPath = Path.Combine(root, "studio.html");
        using (Stream src = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourceName))
        {
            if (src == null) throw new Exception("内置应用资源缺失，请重新编译。");
            using (FileStream dst = File.Create(htmlPath)) src.CopyTo(dst);
        }

        string videoDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
            "板块竞速视频");
        Directory.CreateDirectory(videoDir);

        string profile = Path.Combine(root, "profile");
        WriteFirstRunPrefs(profile, videoDir);

        string browser = FindBrowser();
        if (browser == null)
        {
            MessageBox.Show(
                "未找到 Microsoft Edge 或 Google Chrome。\n\n" +
                "本程序依赖其中之一提供 H.264 视频编码能力。\n" +
                "Windows 10/11 默认自带 Edge，请确认它没有被卸载。",
                AppName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        // Chromium 不接受含原始非 ASCII 字符的 file:// URL，必须百分号编码
        string url = new Uri(htmlPath).AbsoluteUri;

        string args =
            "--app=" + url +
            " --user-data-dir=\"" + profile + "\"" +
            " --window-size=1420,950" +
            " --no-first-run --no-default-browser-check --disable-sync" +
            // 新建 profile 默认开着自动翻译，会把中文界面改成英文
            " --disable-features=Translate,TranslateUI";

        Process.Start(new ProcessStartInfo(browser, args) { UseShellExecute = false });
    }

    /// 首次运行时预置下载目录，让导出的 MP4 直接落到桌面文件夹且不再弹"另存为"
    private static void WriteFirstRunPrefs(string profile, string videoDir)
    {
        string defaultDir = Path.Combine(profile, "Default");
        string prefs = Path.Combine(defaultDir, "Preferences");
        if (File.Exists(prefs)) return;            // 已有配置就不覆盖用户后续的修改

        Directory.CreateDirectory(defaultDir);
        string esc = videoDir.Replace("\\", "\\\\");
        string json =
            "{\"download\":{\"default_directory\":\"" + esc + "\",\"prompt_for_download\":false}," +
            "\"savefile\":{\"default_directory\":\"" + esc + "\"}," +
            "\"profile\":{\"exit_type\":\"Normal\",\"exited_cleanly\":true}}";
        File.WriteAllText(prefs, json, new UTF8Encoding(false));
    }

    private static string FindBrowser()
    {
        string pf = Environment.GetEnvironmentVariable("ProgramFiles") ?? "";
        string pf86 = Environment.GetEnvironmentVariable("ProgramFiles(x86)") ?? "";
        string local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

        string[] candidates =
        {
            Path.Combine(pf86, @"Microsoft\Edge\Application\msedge.exe"),
            Path.Combine(pf,   @"Microsoft\Edge\Application\msedge.exe"),
            Path.Combine(pf,   @"Google\Chrome\Application\chrome.exe"),
            Path.Combine(pf86, @"Google\Chrome\Application\chrome.exe"),
            Path.Combine(local, @"Google\Chrome\Application\chrome.exe"),
        };

        foreach (string c in candidates)
            if (!string.IsNullOrEmpty(c) && File.Exists(c)) return c;

        return null;
    }
}
