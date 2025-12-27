using UnityEngine;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.iOS.Xcode;
using System.IO;
using System.Diagnostics;
using System.Text.RegularExpressions;
using TMPro;
using Debug = UnityEngine.Debug;

/// <summary>
/// iOS自動ビルド＆Xcodeビルドスクリプト
/// 失敗時のみダイアログを表示、成功時はログのみ
/// </summary>
public class BuildAutomation : EditorWindow
{
    private static string buildPath = "Builds/iOS";

    // Apple Developer設定
    private static string developmentTeam = "NSB57DVW9V";
    private static string signingIdentity = "Apple Development: Shungo Iwasaki (MWK9SS7VVP)";

    /// <summary>
    /// 接続されているiOSデバイスのIDを取得（USB/Wi-Fi両対応）
    /// </summary>
    private static string GetConnectedIPhoneId()
    {
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "/usr/bin/xcrun",
                Arguments = "xctrace list devices",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            Process process = Process.Start(psi);
            string output = process.StandardOutput.ReadToEnd();
            process.WaitForExit();

            bool inDevicesSection = false;
            foreach (string line in output.Split('\n'))
            {
                // == Devices == セクションを探す
                if (line.Contains("== Devices =="))
                {
                    inDevicesSection = true;
                    continue;
                }
                // 別のセクションに入ったら終了
                if (line.Contains("== ") && !line.Contains("== Devices =="))
                {
                    inDevicesSection = false;
                    continue;
                }

                // Devicesセクション内で、Simulator/MacBook以外のデバイスを探す
                if (inDevicesSection &&
                    !line.Contains("Simulator") &&
                    !line.Contains("MacBook") &&
                    !line.Contains("Mac Pro") &&
                    !line.Contains("iMac"))
                {
                    // iOSバージョン番号があるデバイス（例: "(18.5)"）を探す
                    Match versionMatch = Regex.Match(line, @"\((\d+\.\d+)\)");
                    if (versionMatch.Success)
                    {
                        // UUIDを抽出
                        Match uuidMatch = Regex.Match(line, @"\(([0-9A-Fa-f-]{20,})\)");
                        if (uuidMatch.Success)
                        {
                            Debug.Log($"iOSデバイス検出: {line.Trim()}");
                            return uuidMatch.Groups[1].Value;
                        }
                    }
                }
            }
        }
        catch (System.Exception e)
        {
            Debug.LogWarning($"デバイス検出エラー: {e.Message}");
        }

        return null;
    }

    /// <summary>
    /// TMPフォントを静かに修正（ダイアログなし）
    /// </summary>
    private static bool FixTMPFontsSilent()
    {
        // TMPフォントを探す
        string[] guids = AssetDatabase.FindAssets("LiberationSans SDF t:TMP_FontAsset");
        if (guids.Length == 0)
        {
            guids = AssetDatabase.FindAssets("t:TMP_FontAsset");
        }

        if (guids.Length == 0)
        {
            Debug.LogError("TMPフォントが見つかりません。Window → TextMeshPro → Import TMP Essential Resources を実行してください。");
            return false;
        }

        string path = AssetDatabase.GUIDToAssetPath(guids[0]);
        TMP_FontAsset font = AssetDatabase.LoadAssetAtPath<TMP_FontAsset>(path);

        if (font == null)
        {
            Debug.LogError("TMPフォントの読み込みに失敗しました。");
            return false;
        }

        // 現在のシーンのすべてのTMPテキストにフォントを設定
        TextMeshProUGUI[] tmpTexts = FindObjectsByType<TextMeshProUGUI>(FindObjectsSortMode.None);
        int fixedCount = 0;

        foreach (TextMeshProUGUI tmp in tmpTexts)
        {
            if (tmp.font == null)
            {
                tmp.font = font;
                EditorUtility.SetDirty(tmp);
                fixedCount++;
            }
        }

        if (fixedCount > 0)
        {
            UnityEditor.SceneManagement.EditorSceneManager.SaveOpenScenes();
            Debug.Log($"TMPフォント修正: {fixedCount}個");
        }

        return true;
    }

    [MenuItem("Tools/高市総理ゲーム/6. iOS自動ビルド（Unity + Xcode）")]
    public static void BuildiOS()
    {
        Debug.Log("=== iOS 自動ビルド開始 ===");

        // TMPフォント修正（静かに）
        if (!FixTMPFontsSilent())
        {
            EditorUtility.DisplayDialog("ビルド失敗",
                "TMPフォントが見つかりません。\n\nWindow → TextMeshPro → Import TMP Essential Resources\nを実行してから再試行してください。",
                "OK");
            return;
        }

        // iOS Player Settings で自動署名を設定
        PlayerSettings.iOS.appleEnableAutomaticSigning = true;
        PlayerSettings.iOS.appleDeveloperTeamID = developmentTeam;

        // ビルドパスを取得
        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        string fullBuildPath = Path.Combine(projectRoot, buildPath);

        // ビルドフォルダが存在しない場合は作成
        if (!Directory.Exists(fullBuildPath))
        {
            Directory.CreateDirectory(fullBuildPath);
        }

        // ビルド設定
        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = new[]
            {
                "Assets/Scenes/TitleScene.unity",
                "Assets/Scenes/GameScene.unity"
            },
            locationPathName = fullBuildPath,
            target = BuildTarget.iOS,
            options = BuildOptions.None
        };

        Debug.Log($"出力先: {fullBuildPath}");

        // Unityビルド実行
        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        BuildSummary summary = report.summary;

        if (summary.result == BuildResult.Succeeded)
        {
            Debug.Log($"Unity ビルド成功: {summary.totalSize / 1024 / 1024} MB, {summary.totalTime.TotalSeconds:F1}秒");

            // Xcodeビルドを実行
            BuildWithXcode(fullBuildPath);
        }
        else
        {
            Debug.LogError($"Unity ビルド失敗: エラー数 {summary.totalErrors}");
            EditorUtility.DisplayDialog("ビルド失敗",
                $"Unityビルドに失敗しました。\nエラー数: {summary.totalErrors}\n\nConsoleログを確認してください。",
                "OK");
        }
    }

    private static void BuildWithXcode(string xcodeProjectPath)
    {
        Debug.Log("=== Xcode ビルド開始 ===");

        // 接続されているiPhoneを検出
        string deviceId = GetConnectedIPhoneId();

        // シェルスクリプトを生成して実行
        string scriptPath = Path.Combine(xcodeProjectPath, "build_and_run.sh");
        string scriptContent;

        if (!string.IsNullOrEmpty(deviceId))
        {
            Debug.Log($"iPhone へビルド＆デプロイ: {deviceId}");
            // 実機へのビルド＆デプロイ（自動署名を使用）
            scriptContent = $@"#!/bin/bash
set -e

cd ""{xcodeProjectPath}""

# 実機向けビルド＆インストール（自動署名）
xcodebuild -project Unity-iPhone.xcodeproj \
    -scheme Unity-iPhone \
    -configuration Debug \
    -destination 'id={deviceId}' \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM={developmentTeam} \
    CODE_SIGN_STYLE=Automatic \
    build 2>&1 | tail -80

echo ""完了""
";
        }
        else
        {
            Debug.Log("iPhoneが見つかりません。Xcodeプロジェクトを開きます。");
            scriptContent = $@"#!/bin/bash
open ""{xcodeProjectPath}/Unity-iPhone.xcodeproj""
";
        }

        File.WriteAllText(scriptPath, scriptContent);

        // 実行権限を付与
        ProcessStartInfo chmod = new ProcessStartInfo
        {
            FileName = "/bin/chmod",
            Arguments = $"+x \"{scriptPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true
        };
        Process.Start(chmod)?.WaitForExit();

        // ビルドスクリプトを実行
        ProcessStartInfo buildProcess = new ProcessStartInfo
        {
            FileName = "/bin/bash",
            Arguments = $"\"{scriptPath}\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        Process process = new Process { StartInfo = buildProcess };
        process.OutputDataReceived += (sender, e) => { if (e.Data != null) Debug.Log(e.Data); };
        process.ErrorDataReceived += (sender, e) => { if (e.Data != null) Debug.LogWarning(e.Data); };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        process.WaitForExit();

        if (process.ExitCode == 0)
        {
            if (!string.IsNullOrEmpty(deviceId))
            {
                Debug.Log("=== iPhone へのデプロイ完了 ===");
            }
            else
            {
                Debug.Log("=== Xcodeプロジェクトを開きました ===");
            }
        }
        else
        {
            Debug.LogError($"Xcode ビルド失敗 (Exit Code: {process.ExitCode})");

            // 失敗時はXcodeを開いてダイアログ表示
            string xcodeProject = Path.Combine(xcodeProjectPath, "Unity-iPhone.xcodeproj");
            Process.Start("open", $"\"{xcodeProject}\"");

            EditorUtility.DisplayDialog("Xcodeビルド失敗",
                "Xcodeビルドに失敗しました。\n\nXcodeプロジェクトを開きました。\n手動でビルド・実行してください。",
                "OK");
        }
    }

    /// <summary>
    /// コマンドラインからビルドを実行する（バッチモード用）
    /// </summary>
    public static void BuildiOSCommandLine()
    {
        Debug.Log("=== コマンドラインビルド開始 ===");

        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        string fullBuildPath = Path.Combine(projectRoot, buildPath);

        if (!Directory.Exists(fullBuildPath))
        {
            Directory.CreateDirectory(fullBuildPath);
        }

        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = new[]
            {
                "Assets/Scenes/TitleScene.unity",
                "Assets/Scenes/GameScene.unity"
            },
            locationPathName = fullBuildPath,
            target = BuildTarget.iOS,
            options = BuildOptions.None
        };

        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        BuildSummary summary = report.summary;

        if (summary.result == BuildResult.Succeeded)
        {
            Debug.Log($"ビルド成功: {summary.totalSize / 1024 / 1024} MB, {summary.totalTime.TotalSeconds:F1}秒");
            EditorApplication.Exit(0);
        }
        else
        {
            Debug.LogError($"ビルド失敗: エラー数 {summary.totalErrors}");
            EditorApplication.Exit(1);
        }
    }

    [MenuItem("Tools/高市総理ゲーム/7. Xcodeプロジェクトを開く")]
    public static void OpenXcodeProject()
    {
        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        string xcodeProject = Path.Combine(projectRoot, buildPath, "Unity-iPhone.xcodeproj");

        if (Directory.Exists(xcodeProject))
        {
            Process.Start("open", $"\"{xcodeProject}\"");
            Debug.Log($"Xcodeプロジェクトを開きました: {xcodeProject}");
        }
        else
        {
            EditorUtility.DisplayDialog("エラー",
                "Xcodeプロジェクトが見つかりません。\n\n先に「6. iOS自動ビルド」を実行してください。",
                "OK");
        }
    }

    [MenuItem("Tools/高市総理ゲーム/8. Xcodeビルドのみ実行")]
    public static void RunXcodeBuildOnly()
    {
        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        string fullBuildPath = Path.Combine(projectRoot, buildPath);

        if (!Directory.Exists(Path.Combine(fullBuildPath, "Unity-iPhone.xcodeproj")))
        {
            EditorUtility.DisplayDialog("エラー",
                "Xcodeプロジェクトが見つかりません。\n\n先に「6. iOS自動ビルド」を実行してください。",
                "OK");
            return;
        }

        BuildWithXcode(fullBuildPath);
    }

    [MenuItem("Tools/高市総理ゲーム/12. iOSシミュレーター用ビルド＆実行")]
    public static void BuildAndRunSimulator()
    {
        Debug.Log("=== iOS シミュレーター用ビルド開始 ===");

        // TMPフォント修正（静かに）
        if (!FixTMPFontsSilent())
        {
            EditorUtility.DisplayDialog("ビルド失敗",
                "TMPフォントが見つかりません。\n\nWindow → TextMeshPro → Import TMP Essential Resources\nを実行してから再試行してください。",
                "OK");
            return;
        }

        // シミュレーター用の設定
        PlayerSettings.iOS.sdkVersion = iOSSdkVersion.SimulatorSDK;

        // ビルドパスを取得
        string projectRoot = Path.GetDirectoryName(Application.dataPath);
        string fullBuildPath = Path.Combine(projectRoot, "Builds/iOS-Simulator");

        // ビルドフォルダが存在しない場合は作成
        if (!Directory.Exists(fullBuildPath))
        {
            Directory.CreateDirectory(fullBuildPath);
        }

        // ビルド設定
        BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
        {
            scenes = new[]
            {
                "Assets/Scenes/TitleScene.unity",
                "Assets/Scenes/GameScene.unity"
            },
            locationPathName = fullBuildPath,
            target = BuildTarget.iOS,
            options = BuildOptions.None
        };

        Debug.Log($"出力先: {fullBuildPath}");

        // Unityビルド実行
        BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
        BuildSummary summary = report.summary;

        // 設定を元に戻す（実機用）
        PlayerSettings.iOS.sdkVersion = iOSSdkVersion.DeviceSDK;

        if (summary.result == BuildResult.Succeeded)
        {
            Debug.Log($"Unity ビルド成功: {summary.totalSize / 1024 / 1024} MB, {summary.totalTime.TotalSeconds:F1}秒");

            // シミュレーターでビルド＆実行
            BuildAndLaunchSimulator(fullBuildPath);
        }
        else
        {
            Debug.LogError($"Unity ビルド失敗: エラー数 {summary.totalErrors}");
            EditorUtility.DisplayDialog("ビルド失敗",
                $"Unityビルドに失敗しました。\nエラー数: {summary.totalErrors}\n\nConsoleログを確認してください。",
                "OK");
        }
    }

    private static void BuildAndLaunchSimulator(string xcodeProjectPath)
    {
        Debug.Log("=== シミュレーター用Xcodeビルド開始 ===");

        string simulatorName = "iPhone 16 Pro";

        // シェルスクリプトを生成して実行
        string scriptPath = Path.Combine(xcodeProjectPath, "build_simulator.sh");
        string scriptContent = $@"#!/bin/bash
set -e

cd ""{xcodeProjectPath}""

echo ""シミュレーター用にビルド中...""

# シミュレーター用にビルド
xcodebuild -project Unity-iPhone.xcodeproj \
    -scheme Unity-iPhone \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name={simulatorName}' \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="""" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tail -100

# シミュレーターを起動
echo ""シミュレーターを起動中...""
xcrun simctl boot ""{simulatorName}"" 2>/dev/null || true

# アプリをインストール
APP_PATH=$(find build -name ""*.app"" -type d | head -1)
if [ -n ""$APP_PATH"" ]; then
    echo ""アプリをインストール: $APP_PATH""
    xcrun simctl install booted ""$APP_PATH""

    # Bundle IDを取得してアプリを起動
    BUNDLE_ID=$(/usr/libexec/PlistBuddy -c ""Print:CFBundleIdentifier"" ""$APP_PATH/Info.plist"")
    echo ""アプリを起動: $BUNDLE_ID""
    xcrun simctl launch booted ""$BUNDLE_ID""

    # Simulatorアプリを前面に
    open -a Simulator
else
    echo ""エラー: ビルドされたアプリが見つかりません""
    exit 1
fi

echo ""完了""
";

        File.WriteAllText(scriptPath, scriptContent);

        // 実行権限を付与
        ProcessStartInfo chmod = new ProcessStartInfo
        {
            FileName = "/bin/chmod",
            Arguments = $"+x \"{scriptPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true
        };
        Process.Start(chmod)?.WaitForExit();

        // ビルドスクリプトを実行
        ProcessStartInfo buildProcess = new ProcessStartInfo
        {
            FileName = "/bin/bash",
            Arguments = $"\"{scriptPath}\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        Process process = new Process { StartInfo = buildProcess };
        process.OutputDataReceived += (sender, e) => { if (e.Data != null) Debug.Log(e.Data); };
        process.ErrorDataReceived += (sender, e) => { if (e.Data != null) Debug.LogWarning(e.Data); };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        process.WaitForExit();

        if (process.ExitCode == 0)
        {
            Debug.Log("=== シミュレーターでアプリを起動しました ===");
        }
        else
        {
            Debug.LogError($"シミュレータービルド失敗 (Exit Code: {process.ExitCode})");
            EditorUtility.DisplayDialog("ビルド失敗",
                "シミュレーター用ビルドに失敗しました。\n\nConsoleログを確認してください。",
                "OK");
        }
    }
}

/// <summary>
/// iOSビルド後にXcodeプロジェクトの署名設定を自動修正
/// </summary>
public class iOSPostProcessBuild
{
    [UnityEditor.Callbacks.PostProcessBuild(100)]
    public static void OnPostProcessBuild(BuildTarget target, string pathToBuiltProject)
    {
        if (target != BuildTarget.iOS)
            return;

        Debug.Log("PostProcessBuild: Xcodeプロジェクトの署名設定を修正中...");

        string pbxprojPath = Path.Combine(pathToBuiltProject, "Unity-iPhone.xcodeproj", "project.pbxproj");

        if (!File.Exists(pbxprojPath))
        {
            Debug.LogWarning("project.pbxproj が見つかりません");
            return;
        }

        // PBXProjectを使って署名設定を修正
        PBXProject project = new PBXProject();
        project.ReadFromFile(pbxprojPath);

        // ターゲットGUIDを取得
        string mainTargetGuid = project.GetUnityMainTargetGuid();
        string frameworkTargetGuid = project.GetUnityFrameworkTargetGuid();

        // 両方のターゲットに自動署名を設定
        project.SetBuildProperty(mainTargetGuid, "CODE_SIGN_STYLE", "Automatic");
        project.SetBuildProperty(mainTargetGuid, "CODE_SIGN_IDENTITY", "Apple Development");
        project.SetBuildProperty(mainTargetGuid, "CODE_SIGN_IDENTITY[sdk=iphoneos*]", "Apple Development");
        project.SetBuildProperty(mainTargetGuid, "DEVELOPMENT_TEAM", "NSB57DVW9V");

        project.SetBuildProperty(frameworkTargetGuid, "CODE_SIGN_STYLE", "Automatic");
        project.SetBuildProperty(frameworkTargetGuid, "CODE_SIGN_IDENTITY", "Apple Development");
        project.SetBuildProperty(frameworkTargetGuid, "CODE_SIGN_IDENTITY[sdk=iphoneos*]", "Apple Development");
        project.SetBuildProperty(frameworkTargetGuid, "DEVELOPMENT_TEAM", "NSB57DVW9V");

        project.WriteToFile(pbxprojPath);

        Debug.Log("Xcodeプロジェクトの署名設定を自動修正しました");
    }
}
