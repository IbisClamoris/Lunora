using System.Diagnostics;
using System.Drawing.Drawing2D;
using System.Reflection;

namespace Lunora.Installer;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new InstallerForm());
    }
}

internal sealed class InstallerForm : Form
{
    private readonly Color ink = Color.FromArgb(25, 22, 48);
    private readonly Color panel = Color.FromArgb(34, 30, 62);
    private readonly Color muted = Color.FromArgb(183, 176, 205);
    private readonly TextBox folder = new();
    private readonly ComboBox language = new();
    private readonly CheckBox desktop = new();
    private readonly Button install = new();
    private readonly Button browse = new();
    private readonly Label status = new();
    private readonly ProgressBar progress = new();
    private bool installing;
    private bool completed;

    public InstallerForm()
    {
        Text = "Lunora Setup";
        ClientSize = new Size(900, 570);
        MinimumSize = new Size(900, 570);
        MaximumSize = new Size(900, 570);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = ink;
        Font = new Font("Segoe UI", 10);
        try { Icon = new Icon(Path.Combine(AppContext.BaseDirectory, "app_icon.ico")); } catch { }

        var hero = new Panel { Dock = DockStyle.Left, Width = 330 };
        hero.Paint += PaintHero;

        var content = new Panel { Dock = DockStyle.Fill, BackColor = panel, Padding = new Padding(38, 34, 38, 26) };
        Controls.Add(content);
        Controls.Add(hero);

        var close = new Button { Text = "×", ForeColor = muted, BackColor = Color.Transparent, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI Light", 20), Size = new Size(42, 38), Location = new Point(510, 8), Anchor = AnchorStyles.Top | AnchorStyles.Right };
        close.FlatAppearance.BorderSize = 0;
        close.Click += (_, _) => Close();
        content.Controls.Add(close);

        var eyebrow = MakeLabel("YOUR PERSONAL WORLD", 9, muted, true);
        eyebrow.Location = new Point(38, 44); eyebrow.AutoSize = true; content.Controls.Add(eyebrow);
        var title = MakeLabel("Добро пожаловать домой", 23, Color.FromArgb(250, 241, 222), true);
        title.Location = new Point(38, 76); title.AutoSize = true; content.Controls.Add(title);
        var description = MakeLabel("Установите Lunora и создайте своё личное пространство.", 10, muted, false);
        description.Location = new Point(40, 120); description.Size = new Size(470, 42); content.Controls.Add(description);

        AddFieldLabel(content, "Папка установки", 40, 190);
        folder.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Lunora");
        folder.Location = new Point(40, 220); folder.Size = new Size(380, 38);
        StyleTextBox(folder); content.Controls.Add(folder);
        browse.Text = "Обзор"; browse.Location = new Point(430, 219); browse.Size = new Size(82, 39); StyleButton(browse, false);
        browse.Click += (_, _) => { using var d = new FolderBrowserDialog { SelectedPath = folder.Text, Description = "Выберите папку для установки Lunora" }; if (d.ShowDialog(this) == DialogResult.OK) folder.Text = d.SelectedPath; };
        content.Controls.Add(browse);

        AddFieldLabel(content, "Язык установщика", 40, 286);
        language.Location = new Point(40, 316); language.Size = new Size(190, 36);
        language.DropDownStyle = ComboBoxStyle.DropDownList;
        language.Items.AddRange(new object[] { "Русский", "English" }); language.SelectedIndex = 0;
        language.BackColor = Color.FromArgb(48, 43, 78); language.ForeColor = Color.White; language.FlatStyle = FlatStyle.Flat;
        content.Controls.Add(language);

        desktop.Text = "Создать ярлык на рабочем столе";
        desktop.Checked = true; desktop.AutoSize = true; desktop.Location = new Point(40, 378);
        desktop.ForeColor = Color.FromArgb(229, 222, 240); desktop.BackColor = panel;
        content.Controls.Add(desktop);

        progress.Location = new Point(40, 430); progress.Size = new Size(472, 7); progress.Style = ProgressBarStyle.Continuous;
        progress.Visible = false; content.Controls.Add(progress);
        status.Text = "Установка без лишних окон и сложных настроек.";
        status.ForeColor = muted; status.Location = new Point(40, 440); status.Size = new Size(470, 28); status.Font = new Font("Segoe UI", 8.5f);
        content.Controls.Add(status);

        install.Text = "УСТАНОВИТЬ LUNORA"; install.Location = new Point(300, 470); install.Size = new Size(212, 48); install.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
        StyleButton(install, true); install.Click += async (_, _) => { if (completed) LaunchApp(); else await InstallAsync(); }; content.Controls.Add(install);
    }

    private static Label MakeLabel(string text, float size, Color color, bool bold) => new() { Text = text, Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular), ForeColor = color, BackColor = Color.Transparent };
    private static void AddFieldLabel(Control parent, string text, int x, int y) { var l = MakeLabel(text, 9.5f, Color.FromArgb(222, 214, 234), true); l.Location = new Point(x, y); l.AutoSize = true; parent.Controls.Add(l); }
    private void StyleTextBox(TextBox box) { box.BorderStyle = BorderStyle.FixedSingle; box.BackColor = Color.FromArgb(48, 43, 78); box.ForeColor = Color.White; box.Font = new Font("Segoe UI", 9.5f); }
    private void StyleButton(Button button, bool primary) { button.FlatStyle = FlatStyle.Flat; button.FlatAppearance.BorderSize = primary ? 0 : 1; button.FlatAppearance.BorderColor = Color.FromArgb(120, 104, 155); button.BackColor = primary ? Color.FromArgb(196, 161, 112) : Color.FromArgb(48, 43, 78); button.ForeColor = primary ? Color.FromArgb(31, 26, 49) : Color.White; button.Font = new Font("Segoe UI", 9, FontStyle.Bold); button.Cursor = Cursors.Hand; }

    private void PaintHero(object? sender, PaintEventArgs e)
    {
        var g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias;
        using var bg = new LinearGradientBrush(((Control)sender!).ClientRectangle, Color.FromArgb(57, 39, 88), Color.FromArgb(17, 24, 51), 45);
        g.FillRectangle(bg, ((Control)sender!).ClientRectangle);
        using var glow = new SolidBrush(Color.FromArgb(25, 227, 198, 158)); g.FillEllipse(glow, -75, 110, 430, 430);
        using var orbit = new Pen(Color.FromArgb(80, 229, 207, 178), 1.2f); g.DrawEllipse(orbit, -42, 150, 390, 390); g.DrawEllipse(orbit, -18, 174, 342, 342);
        var rnd = new Random(21); using var stars = new SolidBrush(Color.FromArgb(190, 249, 231, 199));
        for (int i = 0; i < 70; i++) { int x = rnd.Next(12, 318), y = rnd.Next(12, 550), r = i % 9 == 0 ? 3 : 1; g.FillEllipse(stars, x, y, r, r); }
        using var moon = new SolidBrush(Color.FromArgb(255, 246, 226, 193)); using var cut = new SolidBrush(Color.FromArgb(255, 38, 30, 67));
        g.FillEllipse(moon, 91, 120, 150, 165); g.FillEllipse(cut, 137, 91, 150, 165);
        using var star = new SolidBrush(Color.FromArgb(255, 255, 239, 204)); g.FillPolygon(star, StarPoints(237, 139, 15, 6));
        using var nameFont = new Font("Segoe UI Semibold", 27, FontStyle.Bold); using var tagFont = new Font("Segoe UI", 9);
        using var white = new SolidBrush(Color.FromArgb(250, 244, 230)); using var soft = new SolidBrush(Color.FromArgb(210, 214, 202, 220));
        var sf = new StringFormat { Alignment = StringAlignment.Center };
        g.DrawString("LUNORA", nameFont, white, new RectangleF(0, 330, 330, 48), sf);
        g.DrawString("YOUR PERSONAL WORLD", tagFont, soft, new RectangleF(0, 379, 330, 25), sf);
        using var line = new Pen(Color.FromArgb(130, 220, 190, 151)); g.DrawLine(line, 95, 425, 235, 425);
        g.DrawString("A little universe, just for you", tagFont, soft, new RectangleF(0, 440, 330, 25), sf);
    }
    private static PointF[] StarPoints(float x, float y, float outer, float inner) { var p = new PointF[10]; for (int i = 0; i < 10; i++) { double a = (-90 + i * 36) * Math.PI / 180; float r = i % 2 == 0 ? outer : inner; p[i] = new PointF(x + r * (float)Math.Cos(a), y + r * (float)Math.Sin(a)); } return p; }

    private void LaunchApp()
    {
        var exe = Path.Combine(folder.Text, "lunora.exe");
        if (File.Exists(exe)) Process.Start(new ProcessStartInfo(exe) { UseShellExecute = true });
        Close();
    }

    private async Task InstallAsync()
    {
        if (installing) return;
        if (string.IsNullOrWhiteSpace(folder.Text)) { MessageBox.Show(this, "Выберите папку установки.", "Lunora", MessageBoxButtons.OK, MessageBoxIcon.Information); return; }
        installing = true; install.Enabled = browse.Enabled = folder.Enabled = language.Enabled = desktop.Enabled = false;
        install.Text = "УСТАНОВКА…"; progress.Visible = true; progress.Style = ProgressBarStyle.Marquee; progress.MarqueeAnimationSpeed = 24;
        status.Text = "Подготавливаем ваше пространство…";
        try
        {
            var payload = Path.Combine(Path.GetTempPath(), "Lunora-Setup-" + Guid.NewGuid().ToString("N") + ".exe");
            await using (var input = Assembly.GetExecutingAssembly().GetManifestResourceStream("Lunora.Installer.Lunora-Payload.exe") ?? throw new InvalidOperationException("Не найден пакет установки."))
            await using (var output = File.Create(payload)) await input.CopyToAsync(output);
            var lang = language.SelectedIndex == 0 ? "russian" : "english";
            var args = $"/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LANG={lang} /DIR=\"{folder.Text}\"" + (desktop.Checked ? " /TASKS=desktopicon" : " /TASKS=");
            using var process = Process.Start(new ProcessStartInfo(payload, args) { UseShellExecute = false, CreateNoWindow = true }) ?? throw new InvalidOperationException("Не удалось запустить установщик.");
            await process.WaitForExitAsync();
            try { File.Delete(payload); } catch { }
            if (process.ExitCode != 0) throw new InvalidOperationException($"Установщик завершился с кодом {process.ExitCode}.");
            progress.Style = ProgressBarStyle.Continuous; progress.Value = 100;
            status.Text = "Lunora установлена. Ваше личное пространство готово.";
            completed = true; install.Text = "ЗАПУСТИТЬ LUNORA"; install.Enabled = true;
        }
        catch (Exception ex)
        {
            progress.Visible = false; status.Text = "Не удалось завершить установку.";
            MessageBox.Show(this, ex.Message, "Ошибка установки Lunora", MessageBoxButtons.OK, MessageBoxIcon.Error);
            install.Text = "ПОВТОРИТЬ"; install.Enabled = true; installing = false;
        }
    }
}
