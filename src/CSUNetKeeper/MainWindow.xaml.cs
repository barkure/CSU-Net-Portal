using CSUNetKeeper.Models;
using CSUNetKeeper.Services;
using Microsoft.UI.Text;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using Windows.ApplicationModel;
using Windows.System;
using Windows.UI;
using WinRT.Interop;

namespace CSUNetKeeper;

public sealed partial class MainWindow : Window
{
    private const int MinWindowWidth = 600;
    private const int MinWindowHeight = 850;
    private const int GwlWndProc = -4;
    private const int WmGetMinMaxInfo = 0x0024;
    private const int WmApp = 0x8000;
    private const int WmLButtonUp = 0x0202;
    private const int WmLButtonDoubleClick = 0x0203;
    private const int WmRButtonUp = 0x0205;
    private const int TrayCallbackMessage = WmApp + 1;
    private const uint NimAdd = 0x00000000;
    private const uint NimDelete = 0x00000002;
    private const uint NifMessage = 0x00000001;
    private const uint NifIcon = 0x00000002;
    private const uint NifTip = 0x00000004;
    private const uint TpmLeftAlign = 0x0000;
    private const uint TpmRightButton = 0x0002;
    private const uint TpmReturnCmd = 0x0100;
    private const uint MfString = 0x0000;
    private const uint ImageIcon = 1;
    private const uint LrLoadFromFile = 0x00000010;
    private const uint LrDefaultSize = 0x00000040;
    private const int TrayCommandOpen = 1001;
    private const int TrayCommandExit = 1002;
    private static readonly TimeSpan SessionResetDelay = TimeSpan.FromSeconds(2);
    private static readonly TimeSpan RetryDelay = TimeSpan.FromSeconds(1);

    private readonly ConfigService _configService = new();
    private readonly LogService _logService = new();
    private readonly PortalClient _portalClient = new();
    private readonly MonitorService _monitorService;

    private readonly TextBox _usernameTextBox = new() { PlaceholderText = "输入校园网账号" };
    private readonly PasswordBox _passwordBox = new() { PasswordRevealMode = PasswordRevealMode.Peek, IsPasswordRevealButtonEnabled = true };
    private readonly ComboBox _networkTypeComboBox = new() { SelectedIndex = 0 };
    private readonly NumberBox _intervalNumberBox = new() { Minimum = 1, SmallChange = 1, SpinButtonPlacementMode = NumberBoxSpinButtonPlacementMode.Inline, Value = 10 };
    private readonly ToggleSwitch _monitorToggleSwitch = new() { Header = "自动认证", OffContent = "关闭", OnContent = "开启" };
    private readonly StackPanel _loadingPanel = new() { Orientation = Orientation.Horizontal, Spacing = 8, Visibility = Visibility.Collapsed };
    private readonly ProgressRing _loadingRing = new() { Width = 16, Height = 16, IsActive = false };
    private readonly TextBlock _loadingTextBlock = new();
    private readonly TextBlock _outputTextBlock = new() { TextWrapping = TextWrapping.Wrap, Visibility = Visibility.Collapsed };
    private readonly Button _settingsButton = new() { Width = 32, Height = 32 };
    private readonly Button _backButton = new() { Width = 32, Height = 32, Visibility = Visibility.Collapsed };
    private readonly ToggleSwitch _startupToggleSwitch = new() { Header = "开机自启动", OffContent = "关闭", OnContent = "开启", IsOn = true };
    private readonly Grid _rootGrid = new();
    private readonly Grid _homeView = new();
    private readonly ScrollViewer _settingsView = new() { Visibility = Visibility.Collapsed };

    private CancellationTokenSource? _monitorCancellationTokenSource;
    private bool _isUpdatingStartupToggle;
    private readonly bool _startedFromStartupTask;
    private bool _launchToTray;
    private bool _isExitRequested;
    private IntPtr _trayMenuHandle;
    private IntPtr _trayIconHandle;
    private IntPtr _windowHandle;
    private IntPtr _originalWndProc;
    private WndProcDelegate? _wndProcDelegate;

    public MainWindow(bool launchToTray = false)
    {
        _startedFromStartupTask = launchToTray;
        _launchToTray = launchToTray;
        _monitorService = new MonitorService(_portalClient);
        InitializeComponent();

        AppWindow.Resize(new Windows.Graphics.SizeInt32(MinWindowWidth, MinWindowHeight));
        Closed += MainWindow_Closed;
        InitializeWindowConstraints();
        SetWindowIcon();
        InitializeTrayIcon();
        AppWindow.Closing += AppWindow_Closing;

        Title = "CSU Net Keeper";
        Content = BuildContent();

        _ = LoadConfigAsync();
        _ = InitializeStartupToggleAsync();
    }

    public void HideToTrayAfterLaunch()
    {
        _launchToTray = false;
        HideToTray();
    }

    private UIElement BuildContent()
    {
        _usernameTextBox.Header = "学号";
        _passwordBox.Header = "密码";
        _networkTypeComboBox.Header = "运营商";
        _intervalNumberBox.Header = "检测间隔（秒）";

        _networkTypeComboBox.Items.Add(new ComboBoxItem { Content = "中国移动", Tag = "1" });
        _networkTypeComboBox.Items.Add(new ComboBoxItem { Content = "中国联通", Tag = "2" });
        _networkTypeComboBox.Items.Add(new ComboBoxItem { Content = "中国电信", Tag = "3" });
        _networkTypeComboBox.Items.Add(new ComboBoxItem { Content = "校园网", Tag = "4" });

        _settingsButton.Content = new SymbolIcon(Symbol.Setting);
        _backButton.Content = new SymbolIcon(Symbol.Back);
        _loadingPanel.Children.Add(_loadingRing);
        _loadingPanel.Children.Add(_loadingTextBlock);
        _monitorToggleSwitch.Toggled += MonitorToggleSwitch_Toggled;
        _settingsButton.Click += SettingsButton_Click;
        _backButton.Click += BackButton_Click;
        _settingsButton.Style = (Style)Application.Current.Resources["ButtonRevealStyle"];
        _settingsButton.Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
        _settingsButton.BorderThickness = new Thickness(0);
        _settingsButton.Padding = new Thickness(0);
        _backButton.Style = (Style)Application.Current.Resources["ButtonRevealStyle"];
        _backButton.Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
        _backButton.BorderThickness = new Thickness(0);
        _backButton.Padding = new Thickness(0);
        ApplySoftIconButtonStyle(_settingsButton);
        ApplySoftIconButtonStyle(_backButton);

        _rootGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        _rootGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var headerGrid = new Grid
        {
            Margin = new Thickness(24, 12, 24, 8)
        };
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var headerPanel = new StackPanel { Spacing = 6 };
        headerPanel.Children.Add(new TextBlock
        {
            Text = "CSU Net Keeper",
            FontSize = 28,
            FontWeight = FontWeights.SemiBold
        });
        headerPanel.Children.Add(new TextBlock
        {
            Text = "中南大学校园网自动认证工具",
            Foreground = new SolidColorBrush(Color.FromArgb(255, 96, 96, 96))
        });

        headerGrid.Children.Add(headerPanel);

        _backButton.HorizontalAlignment = HorizontalAlignment.Right;
        _backButton.VerticalAlignment = VerticalAlignment.Top;
        Grid.SetColumn(_backButton, 1);
        headerGrid.Children.Add(_backButton);

        _settingsButton.HorizontalAlignment = HorizontalAlignment.Right;
        _settingsButton.VerticalAlignment = VerticalAlignment.Top;
        Grid.SetColumn(_settingsButton, 2);
        headerGrid.Children.Add(_settingsButton);
        _rootGrid.Children.Add(headerGrid);

        _homeView.Margin = new Thickness(24, 10, 24, 24);
        _homeView.ColumnSpacing = 16;
        _homeView.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        Grid.SetRow(_homeView, 1);

        var bodyGrid = new Grid
        {
            ColumnSpacing = 16
        };
        bodyGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        var configPanel = new StackPanel { Spacing = 12 };
        configPanel.Children.Add(new TextBlock
        {
            Text = "账号",
            FontSize = 18,
            FontWeight = FontWeights.SemiBold
        });
        configPanel.Children.Add(_usernameTextBox);
        configPanel.Children.Add(_passwordBox);
        configPanel.Children.Add(_networkTypeComboBox);
        configPanel.Children.Add(_intervalNumberBox);
        configPanel.Children.Add(_monitorToggleSwitch);
        configPanel.Children.Add(_loadingPanel);
        configPanel.Children.Add(_outputTextBlock);
        bodyGrid.Children.Add(configPanel);

        _homeView.Children.Add(bodyGrid);
        _rootGrid.Children.Add(_homeView);

        _settingsView.Margin = new Thickness(24, 10, 24, 24);
        _settingsView.Content = BuildSettingsView();
        Grid.SetRow(_settingsView, 1);
        _rootGrid.Children.Add(_settingsView);

        return _rootGrid;
    }

    private UIElement BuildSettingsView()
    {
        var contentPanel = new StackPanel
        {
            Spacing = 16,
            Width = 440
        };

        contentPanel.Children.Add(new TextBlock
        {
            Text = "设置",
            FontSize = 18,
            FontWeight = FontWeights.SemiBold
        });

        contentPanel.Children.Add(_startupToggleSwitch);

        contentPanel.Children.Add(new TextBlock
        {
            Text = "日志",
            FontWeight = FontWeights.SemiBold
        });

        var actionsPanel = new StackPanel
        {
            Spacing = 10
        };

        var openLogFolderButton = new Button
        {
            Content = BuildButtonContent(
                new SymbolIcon(Symbol.Library),
                "日志目录")
        };
        openLogFolderButton.Click += OpenLogFolderButton_Click;
        actionsPanel.Children.Add(openLogFolderButton);
        contentPanel.Children.Add(actionsPanel);

        contentPanel.Children.Add(new TextBlock
        {
            Text = "关于",
            FontWeight = FontWeights.SemiBold
        });

        var githubLinkButton = new HyperlinkButton
        {
            Content = BuildGitHubLinkContent(),
            NavigateUri = new Uri("https://github.com/barkure/CSU-Net-Portal")
        };
        contentPanel.Children.Add(githubLinkButton);
        return contentPanel;
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        _homeView.Visibility = Visibility.Collapsed;
        _settingsView.Visibility = Visibility.Visible;
        _settingsButton.Visibility = Visibility.Collapsed;
        _backButton.Visibility = Visibility.Visible;
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        _settingsView.Visibility = Visibility.Collapsed;
        _homeView.Visibility = Visibility.Visible;
        _backButton.Visibility = Visibility.Collapsed;
        _settingsButton.Visibility = Visibility.Visible;
    }

    private static UIElement BuildGitHubLinkContent()
    {
        var panel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8
        };

        panel.Children.Add(CreateSvgIcon("ms-appx:///Assets/Icons/CodiconGithubInverted.svg"));
        panel.Children.Add(new TextBlock
        {
            Text = "barkure/CSU-Net-Portal"
        });

        return panel;
    }

    private static ImageIcon CreateSvgIcon(string uri)
    {
        return new ImageIcon
        {
            Width = 20,
            Height = 20,
            Source = new SvgImageSource(new Uri(uri))
        };
    }

    private static UIElement BuildButtonContent(IconElement icon, string text)
    {
        var panel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8
        };
        panel.Children.Add(icon);
        panel.Children.Add(new TextBlock { Text = text });
        return panel;
    }

    private static void ApplySoftIconButtonStyle(Button button)
    {
        button.Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
        button.BorderBrush = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
        button.BorderThickness = new Thickness(0);

        button.PointerEntered += (_, _) =>
        {
            button.Background = new SolidColorBrush(Color.FromArgb(255, 243, 243, 243));
        };
        button.PointerExited += (_, _) =>
        {
            button.Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0));
        };
        button.PointerPressed += (_, _) =>
        {
            button.Background = new SolidColorBrush(Color.FromArgb(255, 234, 234, 234));
        };
        button.PointerReleased += (_, _) =>
        {
            button.Background = new SolidColorBrush(Color.FromArgb(255, 243, 243, 243));
        };
    }

    private async Task LoadConfigAsync()
    {
        try
        {
            var config = await _configService.LoadAsync();
            ApplyConfigToUi(config);
            AppendLog("Configuration loaded.");

            if (config.AutoAuthEnabled && !_monitorToggleSwitch.IsOn)
            {
                _monitorToggleSwitch.IsOn = true;
            }
        }
        catch (Exception ex)
        {
            AppendLog($"Failed to load configuration: {ex.Message}");
        }
    }

    private AppConfig ReadConfigFromUi()
    {
        if (string.IsNullOrWhiteSpace(_usernameTextBox.Text))
        {
            throw new InvalidOperationException("学号不能为空。");
        }

        if (string.IsNullOrWhiteSpace(_passwordBox.Password))
        {
            throw new InvalidOperationException("密码不能为空。");
        }

        if (_networkTypeComboBox.SelectedItem is not ComboBoxItem selectedItem ||
            selectedItem.Tag is not string type)
        {
            throw new InvalidOperationException("请选择运营商类型。");
        }

        var interval = (int)Math.Round(_intervalNumberBox.Value);
        if (interval < 1)
        {
            throw new InvalidOperationException("检测间隔必须大于 0 秒。");
        }

        return new AppConfig
        {
            Username = _usernameTextBox.Text.Trim(),
            Password = _passwordBox.Password,
            Type = type,
            IntervalSeconds = interval,
            AutoAuthEnabled = _monitorToggleSwitch.IsOn
        };
    }

    private void ApplyConfigToUi(AppConfig config)
    {
        _usernameTextBox.Text = config.Username;
        _passwordBox.Password = config.Password;
        _intervalNumberBox.Value = config.IntervalSeconds;

        foreach (var item in _networkTypeComboBox.Items.OfType<ComboBoxItem>())
        {
            if (Equals(item.Tag, config.Type))
            {
                _networkTypeComboBox.SelectedItem = item;
                return;
            }
        }

        _networkTypeComboBox.SelectedIndex = 0;
    }

    private async void MonitorToggleSwitch_Toggled(object sender, RoutedEventArgs e)
    {
        if (_monitorToggleSwitch.IsOn)
        {
            await StartMonitoringFromToggleAsync();
        }
        else
        {
            await DisableMonitoringFromToggleAsync();
        }
    }

    private async void StartupToggleSwitch_Toggled(object sender, RoutedEventArgs e)
    {
        if (_isUpdatingStartupToggle)
        {
            return;
        }

        await UpdateStartupTaskAsync(_startupToggleSwitch.IsOn);
    }

    private async Task StartMonitoringFromToggleAsync()
    {
        if (IsMonitoring)
        {
            return;
        }

        AppConfig? config = null;
        try
        {
            _monitorToggleSwitch.IsEnabled = false;
            config = ReadConfigFromUi();
            config.AutoAuthEnabled = true;
            ShowOutput(null);
            ShowLoading("测试中");
            await _configService.SaveAsync(config);

            try
            {
                var isAlreadyOnline = await _portalClient.TestOnlineAsync(CancellationToken.None);
                if (isAlreadyOnline)
                {
                    if (_startedFromStartupTask)
                    {
                        AppendLog("Startup launch detected and network is already online. Skipping session reset.");
                        BeginMonitoring(config);
                        return;
                    }

                    AppendLog("Network is already online. Resetting session before validation.");
                    await ResetCurrentSessionAsync(config);
                    await Task.Delay(SessionResetDelay, CancellationToken.None);
                }

                var loginResult = await VerifyAccountAsync(config);
                if (loginResult.FailureKind is LoginFailureKind.InvalidCredentials or LoginFailureKind.InvalidOperator)
                {
                    HideLoading();
                    ShowOutput("配置错误，请检查配置");
                    await PersistAutoAuthStateAsync(false);
                    _monitorToggleSwitch.Toggled -= MonitorToggleSwitch_Toggled;
                    _monitorToggleSwitch.IsOn = false;
                    _monitorToggleSwitch.Toggled += MonitorToggleSwitch_Toggled;
                    return;
                }

                if (!loginResult.IsSuccess)
                {
                    AppendLog($"Pre-check inconclusive: {loginResult.Message}");
                }
            }
            catch (Exception ex)
            {
                AppendLog($"Pre-check skipped due to transient startup error: {ex.Message}");
            }

            BeginMonitoring(config);
        }
        catch (Exception ex)
        {
            HideLoading();
            ShowOutput("配置错误，请检查配置");
            AppendLog($"Unable to start monitoring: {ex.Message}");
            await PersistAutoAuthStateAsync(false);
            SetBusy(false);
            _monitorToggleSwitch.Toggled -= MonitorToggleSwitch_Toggled;
            _monitorToggleSwitch.IsOn = false;
            _monitorToggleSwitch.Toggled += MonitorToggleSwitch_Toggled;
        }
        finally
        {
            _monitorToggleSwitch.IsEnabled = true;
        }
    }

    private void BeginMonitoring(AppConfig config)
    {
        _monitorCancellationTokenSource = new CancellationTokenSource();
        SetBusy(true);
        HideLoading();
        ShowOutput("服务运行中，断网后会自动认证", true);
        AppendLog("Monitoring enabled.");
        _ = RunMonitorAsync(config, _monitorCancellationTokenSource.Token);
    }

    private async Task RunMonitorAsync(AppConfig config, CancellationToken cancellationToken)
    {
        try
        {
            await _monitorService.RunAsync(
                config,
                AppendLog,
                cancellationToken);
        }
        catch (OperationCanceledException)
        {
            AppendLog("Monitoring stopped.");
        }
        catch (MonitorAuthenticationException ex)
        {
            ShowOutput("配置错误，请检查配置");
            AppendLog($"Monitoring stopped due to invalid configuration: {ex.Evaluation.Message}");
        }
        catch (Exception ex)
        {
            AppendLog($"Monitoring failed: {ex.Message}");
        }
        finally
        {
            _monitorCancellationTokenSource?.Dispose();
            _monitorCancellationTokenSource = null;
            SetBusy(false);
            if (_monitorToggleSwitch.IsOn)
            {
                _monitorToggleSwitch.Toggled -= MonitorToggleSwitch_Toggled;
                _monitorToggleSwitch.IsOn = false;
                _monitorToggleSwitch.Toggled += MonitorToggleSwitch_Toggled;
            }
        }
    }

    private void StopMonitoring()
    {
        HideLoading();
        _monitorToggleSwitch.IsEnabled = true;

        if (!IsMonitoring)
        {
            ShowOutput(null);
            return;
        }

        AppendLog("Monitoring disabled.");
        ShowOutput(null);
        _monitorCancellationTokenSource?.Cancel();
    }

    private async Task DisableMonitoringFromToggleAsync()
    {
        await PersistAutoAuthStateAsync(false);
        StopMonitoring();
    }

    private bool IsMonitoring => _monitorCancellationTokenSource is not null;

    private void SetBusy(bool isBusy)
    {
    }

    private void AppendLog(string message)
    {
        if (!DispatcherQueue.HasThreadAccess)
        {
            _ = DispatcherQueue.TryEnqueue(() => AppendLog(message));
            return;
        }

        var line = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}";
        _logService.AppendLine(line);
    }

    private async Task<LoginEvaluation> VerifyAccountAsync(AppConfig config)
    {
        var loginResponse = await _portalClient.LoginAsync(config, CancellationToken.None);
        var loginResult = _portalClient.EvaluateLoginResponse(loginResponse);

        if (loginResult.IsSuccess || loginResult.FailureKind is LoginFailureKind.InvalidCredentials or LoginFailureKind.InvalidOperator)
        {
            if (!loginResult.IsSuccess)
            {
                AppendLog($"Pre-check login failed: {loginResponse}");
            }

            return loginResult;
        }

        AppendLog($"Pre-check login uncertain, retrying once: {loginResponse}");
        await Task.Delay(RetryDelay, CancellationToken.None);

        var retryResponse = await _portalClient.LoginAsync(config, CancellationToken.None);
        var retryResult = _portalClient.EvaluateLoginResponse(retryResponse);
        if (!retryResult.IsSuccess)
        {
            AppendLog($"Pre-check login failed after retry: {retryResponse}");
        }

        return retryResult;
    }

    private async Task ResetCurrentSessionAsync(AppConfig config)
    {
        var unbindResponse = await _portalClient.UnbindMacAsync(config, CancellationToken.None);
        AppendLog($"Unbind response: {unbindResponse}");

        var logoutResponse = await _portalClient.LogoutAsync(CancellationToken.None);
        AppendLog($"Logout response: {logoutResponse}");
    }

    private async Task PersistAutoAuthStateAsync(bool isEnabled)
    {
        try
        {
            var config = ReadConfigFromUi();
            config.AutoAuthEnabled = isEnabled;
            await _configService.SaveAsync(config);
        }
        catch (Exception ex)
        {
            AppendLog($"Failed to persist auto-auth state: {ex.Message}");
        }
    }

    private async Task InitializeStartupToggleAsync()
    {
        try
        {
            var startupTask = await StartupTask.GetAsync("CSUNetKeeperStartup");
            SetStartupToggleState(startupTask.State is StartupTaskState.Enabled or StartupTaskState.EnabledByPolicy);
            AppendLog($"Startup task state: {startupTask.State}.");
        }
        catch (Exception ex)
        {
            AppendLog($"Failed to load startup task state: {ex.Message}");
        }
    }

    private async Task UpdateStartupTaskAsync(bool shouldEnable)
    {
        try
        {
            var startupTask = await StartupTask.GetAsync("CSUNetKeeperStartup");

            if (shouldEnable)
            {
                var state = startupTask.State;
                if (state is StartupTaskState.Disabled or StartupTaskState.DisabledByUser)
                {
                    state = await startupTask.RequestEnableAsync();
                }

                SetStartupToggleState(state is StartupTaskState.Enabled or StartupTaskState.EnabledByPolicy);
                AppendLog($"Startup task enable result: {state}.");
                return;
            }

            startupTask.Disable();
            SetStartupToggleState(false);
            AppendLog("Startup task disabled.");
        }
        catch (Exception ex)
        {
            AppendLog($"Failed to update startup task: {ex.Message}");
            await InitializeStartupToggleAsync();
        }
    }

    private void SetStartupToggleState(bool isOn)
    {
        if (!DispatcherQueue.HasThreadAccess)
        {
            _ = DispatcherQueue.TryEnqueue(() => SetStartupToggleState(isOn));
            return;
        }

        _isUpdatingStartupToggle = true;
        _startupToggleSwitch.IsOn = isOn;
        _isUpdatingStartupToggle = false;
    }

    private void ShowOutput(string? message, bool isSuccess = false)
    {
        if (!DispatcherQueue.HasThreadAccess)
        {
            _ = DispatcherQueue.TryEnqueue(() => ShowOutput(message, isSuccess));
            return;
        }

        if (string.IsNullOrWhiteSpace(message))
        {
            _outputTextBlock.Text = string.Empty;
            _outputTextBlock.Visibility = Visibility.Collapsed;
            return;
        }

        _outputTextBlock.Text = message;
        _outputTextBlock.Foreground = isSuccess
            ? new SolidColorBrush(Color.FromArgb(255, 32, 136, 62))
            : new SolidColorBrush(Color.FromArgb(255, 180, 48, 48));
        _outputTextBlock.Visibility = Visibility.Visible;
    }

    private void ShowLoading(string message)
    {
        if (!DispatcherQueue.HasThreadAccess)
        {
            _ = DispatcherQueue.TryEnqueue(() => ShowLoading(message));
            return;
        }

        _loadingTextBlock.Text = message;
        _loadingPanel.Visibility = Visibility.Visible;
        _loadingRing.IsActive = true;
    }

    private void HideLoading()
    {
        if (!DispatcherQueue.HasThreadAccess)
        {
            _ = DispatcherQueue.TryEnqueue(HideLoading);
            return;
        }

        _loadingRing.IsActive = false;
        _loadingTextBlock.Text = string.Empty;
        _loadingPanel.Visibility = Visibility.Collapsed;
    }

    private void OpenLogFolderButton_Click(object sender, RoutedEventArgs e)
    {
        Directory.CreateDirectory(_logService.LogDirectory);
        Process.Start(new ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = $"\"{_logService.LogDirectory}\"",
            UseShellExecute = true
        });
    }

    private void ClearLogButton_Click(object sender, RoutedEventArgs e)
    {
        _logService.Clear();
        AppendLog("Log cleared.");
    }

    private void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        RemoveTrayIcon();
        if (_trayMenuHandle != IntPtr.Zero)
        {
            DestroyMenu(_trayMenuHandle);
            _trayMenuHandle = IntPtr.Zero;
        }
        if (_trayIconHandle != IntPtr.Zero)
        {
            DestroyIcon(_trayIconHandle);
            _trayIconHandle = IntPtr.Zero;
        }
        StopMonitoring();
        RestoreWindowProc();
        _portalClient.Dispose();
    }

    private void AppWindow_Closing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_isExitRequested)
        {
            return;
        }

        args.Cancel = true;
        HideToTray();
    }

    private void InitializeWindowConstraints()
    {
        _windowHandle = WindowNative.GetWindowHandle(this);
        _wndProcDelegate = WindowProc;
        _originalWndProc = SetWindowLongPtr(
            _windowHandle,
            GwlWndProc,
            Marshal.GetFunctionPointerForDelegate(_wndProcDelegate));
    }

    private void InitializeTrayIcon()
    {
        _trayMenuHandle = CreatePopupMenu();
        AppendMenu(_trayMenuHandle, MfString, TrayCommandOpen, "打开");
        AppendMenu(_trayMenuHandle, MfString, TrayCommandExit, "退出");

        _trayIconHandle = LoadTrayIconHandle();

        var data = new NOTIFYICONDATA
        {
            cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
            hWnd = _windowHandle,
            uID = 1,
            uFlags = NifMessage | NifIcon | NifTip,
            uCallbackMessage = TrayCallbackMessage,
            hIcon = _trayIconHandle,
            szTip = "CSU Net Keeper"
        };

        Shell_NotifyIcon(NimAdd, ref data);
    }

    private IntPtr LoadTrayIconHandle()
    {
        var iconPath = GetAppIconPath();
        if (File.Exists(iconPath))
        {
            var iconHandle = LoadImage(IntPtr.Zero, iconPath, ImageIcon, 16, 16, LrLoadFromFile | LrDefaultSize);
            if (iconHandle != IntPtr.Zero)
            {
                return iconHandle;
            }
        }

        return LoadIcon(IntPtr.Zero, (IntPtr)0x7F00);
    }

    private void SetWindowIcon()
    {
        var iconPath = GetAppIconPath();
        if (File.Exists(iconPath))
        {
            AppWindow.SetIcon(iconPath);
        }
    }

    private static string GetAppIconPath()
    {
        return Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
    }

    private void HideToTray()
    {
        AppWindow.Hide();
    }

    private void ShowFromTray()
    {
        if (!DispatcherQueue.HasThreadAccess)
        {
            _ = DispatcherQueue.TryEnqueue(ShowFromTray);
            return;
        }

        AppWindow.Show();
        Activate();
    }

    private void ExitFromTray()
    {
        if (!DispatcherQueue.HasThreadAccess)
        {
            _ = DispatcherQueue.TryEnqueue(ExitFromTray);
            return;
        }

        _isExitRequested = true;
        Close();
    }

    private void ShowTrayMenu()
    {
        SetForegroundWindow(_windowHandle);
        GetCursorPos(out var point);
        var command = TrackPopupMenuEx(
            _trayMenuHandle,
            TpmLeftAlign | TpmRightButton | TpmReturnCmd,
            point.x,
            point.y,
            _windowHandle,
            IntPtr.Zero);

        if (command == TrayCommandOpen)
        {
            ShowFromTray();
        }
        else if (command == TrayCommandExit)
        {
            ExitFromTray();
        }
    }

    private void RemoveTrayIcon()
    {
        if (_windowHandle == IntPtr.Zero)
        {
            return;
        }

        var data = new NOTIFYICONDATA
        {
            cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
            hWnd = _windowHandle,
            uID = 1
        };

        Shell_NotifyIcon(NimDelete, ref data);
    }

    private void RestoreWindowProc()
    {
        if (_windowHandle == IntPtr.Zero || _originalWndProc == IntPtr.Zero)
        {
            return;
        }

        SetWindowLongPtr(_windowHandle, GwlWndProc, _originalWndProc);
        _originalWndProc = IntPtr.Zero;
    }

    private IntPtr WindowProc(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam)
    {
        if (msg == WmGetMinMaxInfo)
        {
            var minMaxInfo = Marshal.PtrToStructure<MINMAXINFO>(lParam);
            minMaxInfo.ptMinTrackSize.x = MinWindowWidth;
            minMaxInfo.ptMinTrackSize.y = MinWindowHeight;
            Marshal.StructureToPtr(minMaxInfo, lParam, true);
        }
        else if (msg == TrayCallbackMessage)
        {
            switch ((uint)lParam.ToInt64())
            {
                case WmLButtonUp:
                case WmLButtonDoubleClick:
                    ShowFromTray();
                    return IntPtr.Zero;
                case WmRButtonUp:
                    ShowTrayMenu();
                    return IntPtr.Zero;
            }
        }

        return CallWindowProc(_originalWndProc, hWnd, msg, wParam, lParam);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MINMAXINFO
    {
        public POINT ptReserved;
        public POINT ptMaxSize;
        public POINT ptMaxPosition;
        public POINT ptMinTrackSize;
        public POINT ptMaxTrackSize;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NOTIFYICONDATA
    {
        public uint cbSize;
        public IntPtr hWnd;
        public uint uID;
        public uint uFlags;
        public uint uCallbackMessage;
        public IntPtr hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string szTip;
    }

    private delegate IntPtr WndProcDelegate(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW", SetLastError = true)]
    private static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr CallWindowProc(
        IntPtr lpPrevWndFunc,
        IntPtr hWnd,
        uint msg,
        IntPtr wParam,
        IntPtr lParam);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern bool Shell_NotifyIcon(uint dwMessage, ref NOTIFYICONDATA lpData);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr CreatePopupMenu();

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool AppendMenu(IntPtr hMenu, uint uFlags, int uIDNewItem, string lpNewItem);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int TrackPopupMenuEx(
        IntPtr hmenu,
        uint fuFlags,
        int x,
        int y,
        IntPtr hwnd,
        IntPtr lptpm);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetCursorPos(out POINT lpPoint);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool DestroyMenu(IntPtr hMenu);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr LoadIcon(IntPtr hInstance, IntPtr lpIconName);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr LoadImage(
        IntPtr hInst,
        string lpszName,
        uint uType,
        int cxDesired,
        int cyDesired,
        uint fuLoad);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr hIcon);
}
